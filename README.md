# gf180 Ising annealer

A simple 8 spin fully connected ising annealing machine.

## Build

Requires LibreLane, OpenROAD, Magic, KLayout, Netgen. (Currently via nix)

```sh
nix develop
make clone-pdk
make librelane
make sim
make sim-gl
```

`SLOT` selects the slot size (default `1x1`); use the same value for all three.

Based on the [wafer.space gf180mcu project template](https://github.com/wafer-space/gf180mcu-project-template)
at commit `d99f6e1`.
