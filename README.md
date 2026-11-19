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
