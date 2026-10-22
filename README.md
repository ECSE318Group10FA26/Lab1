# ECSE 318 Labs

This repo contains group 6's problem solutions for the ECSE 318 Labs.

## Entering the dev environment

### With Nix

Run `nix develop` from the repository root to enter the environment.

This provides all necessary programs for this project to run

### Without Nix

Install the following programs for the simulation pipeline:

- `podman` [optional - if vsim is available on PATH]
- `gtkwave` [optional - for wave.sh]
- `vcd2fst` [optional]

Install the following programs for the gate analysis pipeline \[optional\]:

- `sv2v`
- `yosys`

Install the following programs for the layout pipeline \[optional\]:

- `librelane`
- `klayout` [viewing]
- `magic-vlsi` [viewing]

Install the following programs for gate-level graphs/schematics \[optional\]:

- `graphviz` (`yosys show` renders through `dot`)
- `netlistsvg` [prettier schematics]
- `xdot` [interactive viewer]

The PDK (sky130) is fetched by `ciel` into the repo-local, gitignored `.ciel/` directory
(`PDK_ROOT` is set by the devshell).

Install the following programs for the rest of the development environment \[optional\]:

- `verible` (LSP, lint, format)
- `mdformat` (format)
- `spellcheck` (lint, format)

## To run

- Enter the provided devshell with `nix` manually or through direnv
  - To use the nix devshell, ensure `nix` is installed and run `nix develop` from the
    repo root
  - Alternatively, without a devshell, ensure `podman` is installed
- To compile and simulate a problem, run `./sim.sh problemN` where `problemN` is
  replaced with the name of the directory to simulate
  - This sets up the work environment and all necessary libs defined in each problem's
    `problem.env` config file
  - Add `--local` (e.g. `./sim.sh --local problemN`) to use a locally installed
    ModelSim (`vsim` on `PATH`) instead of the podman container
- To view the waves, be in the provided devshell or ensure `gtkwave` and optionally
  `vcd2fst` is installed
  - Then run `./wave.sh problemN [--no-sim] [--no-gui]` like the sim script
  - Running wave without the `--no-sim` option WILL resimulate even if `sim.sh` was run
    prior
- For some problems, a `gates.sh` file may be provided
  - This shows a gate total for the design produced for that project
  - Each `gates.sh` has its own arguments, see its comments to see how to run
  - All gates scripts require `sv2v` and `yosys` to run, the devshell provides these

### Notes

- For problem 2, modify the `problem.env` to run the separate testbenches
  - One testbench is called `lookahead_adder_tb` and the other is called
    `lookahead_adder_cp_tb`
