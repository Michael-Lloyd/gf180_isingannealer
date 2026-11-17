# gf180 Ising annealer

A simple 8 spin fully connected ising annealing machine. 

## Build

Requires LibreLane, OpenROAD, Magic, KLayout, Netgen. (Currently via nix)

```sh
nix develop    # tools: LibreLane, OpenROAD, Magic, KLayout, Netgen
make clone-pdk # PDK, once
make librelane # test chip
make sim       # RTL simulation (cocotb)
make sim-gl    # gate-level simulation of final/
```

Based on the [wafer.space gf180mcu project template](https://github.com/wafer-space/gf180mcu-project-template)
at commit `d99f6e1`.
