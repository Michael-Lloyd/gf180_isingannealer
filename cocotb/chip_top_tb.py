# SPDX-FileCopyrightText: © 2025 Project Template Contributors
# SPDX-License-Identifier: Apache-2.0

import os
import random
import itertools
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, Edge, RisingEdge, FallingEdge, ClockCycles
from cocotb_tools.runner import get_runner

sim = os.getenv("SIM", "icarus")
gl = os.getenv("GL", False)
pdk_root = os.getenv("PDK_ROOT", Path(__file__).resolve().parent / "../gf180mcu")
pdk = os.getenv("PDK", "gf180mcuD")
scl = os.getenv("SCL", "gf180mcu_fd_sc_mcu7t5v0")
pad = os.getenv("PAD", "gf180mcu_fd_io")
slot = os.getenv("SLOT", "1x1")

hdl_toplevel = "chip_top"

N = 8
LEVELS = 16
REG = {"ID": 0x00, "CTRL": 0x01, "SPINS": 0x03, "T_START": 0x05, "T_END": 0x06,
       "LEVEL_SWEEPS": 0x07, "SEED": 0x0A, "WCHAIN": 0x10, "H": 0x18}

async def set_defaults(dut):
    set_pins(dut)

async def enable_power(dut):
    dut.VDD.value = 1
    dut.VSS.value = 0

async def start_clock(clock, freq=10):
    """Start the clock @ freq MHz"""
    c = Clock(clock, 1 / freq * 1000, "ns")
    cocotb.start_soon(c.start())


async def reset(reset, active_low=True, time_ns=1000):
    """Reset dut"""
    cocotb.log.info("Reset asserted...")

    reset.value = not active_low
    await Timer(time_ns, "ns")
    reset.value = active_low

    cocotb.log.info("Reset deasserted.")


async def start_up(dut):
    """Startup sequence"""
    await set_defaults(dut)
    if gl:
        await enable_power(dut)
    await start_clock(dut.clk_PAD)
    await reset(dut.rst_n_PAD)


def set_pins(dut, sclk=0, cs_n=1, sdi=0):
    dut.input_PAD.value = sclk | cs_n << 1 | sdi << 2


async def spi_transfer(dut, word):
    """Send a 16 bit SPI frame and return the byte read back"""
    data = 0
    for bit in range(15, -1, -1):
        sdi = (word >> bit) & 1
        set_pins(dut, sclk=0, cs_n=0, sdi=sdi)
        await ClockCycles(dut.clk_PAD, 4)
        data = data << 1 | int(dut.bidir_PAD.value[0])
        set_pins(dut, sclk=1, cs_n=0, sdi=sdi)
        await ClockCycles(dut.clk_PAD, 4)
    set_pins(dut, cs_n=0)
    await ClockCycles(dut.clk_PAD, 4)
    set_pins(dut)
    await ClockCycles(dut.clk_PAD, 4)
    return data & 0xFF


async def spi_write(dut, addr, data):
    await spi_transfer(dut, addr << 8 | data & 0xFF)


async def spi_read(dut, addr):
    return await spi_transfer(dut, (0x80 | addr) << 8)


def energy(J, h, spins):
    s = [1 if spins >> i & 1 else -1 for i in range(N)]
    pairs = itertools.combinations(range(N), 2)
    return -sum(J[i][j] * s[i] * s[j] for i, j in pairs) - sum(h[i] * s[i] for i in range(N))


@cocotb.test()
async def test_registers(dut):
    """Read the ID and write a register back"""

    await start_up(dut)

    assert await spi_read(dut, REG["ID"]) == 0x15

    await spi_write(dut, REG["T_START"], 2)
    assert await spi_read(dut, REG["T_START"]) == 2


@cocotb.test()
async def test_anneal(dut):
    """Anneal random problems and compare with the ground state"""

    rng = random.Random(0)

    await start_up(dut)

    hits = 0
    for problem in range(4):
        J = [[rng.randint(-4, 3) for j in range(N)] for i in range(N)]
        h = [rng.randint(-4, 3) for i in range(N)]

        for i, j in reversed(list(itertools.combinations(range(N), 2))):
            await spi_write(dut, REG["WCHAIN"], J[i][j])
        for i in range(N):
            await spi_write(dut, REG["H"] + i, h[i])
        await spi_write(dut, REG["SPINS"], rng.randrange(256))
        await spi_write(dut, REG["T_START"], 0)
        await spi_write(dut, REG["T_END"], LEVELS - 1)
        await spi_write(dut, REG["LEVEL_SWEEPS"], 32)
        await spi_write(dut, REG["SEED"], rng.randint(1, 255))
        await spi_write(dut, REG["CTRL"], 0x01)

        for _ in range(100):
            await ClockCycles(dut.clk_PAD, 100)
            if int(dut.bidir_PAD.value[1]):
                break
        assert int(dut.bidir_PAD.value[1])

        e = energy(J, h, await spi_read(dut, REG["SPINS"]))
        ground = min(energy(J, h, s) for s in range(1 << N))
        cocotb.log.info(f"Problem {problem}: energy {e}, ground state {ground}")

        assert e >= ground
        hits += e == ground

    assert hits >= 3


def chip_top_runner():

    proj_path = Path(__file__).resolve().parent

    sources = []
    defines = {f"SLOT_{slot.upper()}": True}
    includes = [proj_path / "../src/"]

    # Set the LibreLane PDK/SCL/PAD defines
    defines[f"PDK_{pdk.replace('-','_')}"] = True
    defines[f"SCL_{scl}"] = True
    defines[f"PAD_{pad}"] = True

    if gl:
        # SCL models
        sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / f"{scl}.v")
        if scl != "gf180mcu_as_sc_mcu7t3v3":
            sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / "primitives.v")

        # We use the powered netlist
        sources.append(proj_path / f"../final/pnl/{hdl_toplevel}.pnl.v")

        defines.update({"FUNCTIONAL": True, "USE_POWER_PINS": True})
    else:
        rtl = proj_path / "../src/ising"
        sources.append(rtl / "ising_params.sv")
        sources += sorted(f for f in rtl.glob("*.sv") if f.name != "ising_params.sv")
        sources.append(proj_path / "../src/ising_macro.sv")
        sources.append(proj_path / "../src/chip_top.sv")
        sources.append(proj_path / "../src/chip_core.sv")
        defines["SIMULATION"] = True

    sources += [
        # IO pad models
        Path(pdk_root) / pdk / f"libs.ref/{pad}/verilog/{pad}.v",
        
        # Custom IP
        proj_path / "../ip/gf180mcu_ws_ip__logo/vh/gf180mcu_ws_ip__logo.v",
        proj_path / "../ip/gf180mcu_ws_ip__marker/vh/gf180mcu_ws_ip__marker.v",
        proj_path / "../ip/gf180mcu_ws_ip__qrcode_id/vh/gf180mcu_ws_ip__qrcode_id.v",
        proj_path / "../ip/gf180mcu_ws_ip__shuttle_id/vh/gf180mcu_ws_ip__shuttle_id.v",
        proj_path / "../ip/gf180mcu_ws_ip__project_id/vh/gf180mcu_ws_ip__project_id.v",
        
    ]

    build_args = []

    if sim == "icarus":
        # For debugging
        # build_args = ["-Winfloop", "-pfileline=1"]
        build_args = ["-g2012"]

    if sim == "verilator":
        build_args = ["--timing", "--trace", "--trace-fst", "--trace-structs"]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        defines=defines,
        always=True,
        includes=includes,
        build_args=build_args,
        timescale=("1ns", "1ps"),
        waves=True,
    )

    plusargs = []

    runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module="chip_top_tb,",
        plusargs=plusargs,
        waves=True,
    )


if __name__ == "__main__":
    chip_top_runner()
