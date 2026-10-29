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

- `verible` (SystemVerilog LSP, lint, format)
- `vhdl_ls` (VHDL LSP - see "VHDL libraries" below for library mapping)
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
  - Add `--local` (e.g. `./sim.sh --local problemN`) to use a locally installed ModelSim
    (`vsim` on `PATH`) instead of the podman container
  - VHDL problems (e.g. l3\*) set `HDL="vhdl"` in `problem.env`; sources are then
    compiled with `vcom` and the VCD is dumped by `common/run.do` instead of the
    testbench (see `problem_template.env`)

### VHDL libraries

Shared VHDL code lives in `common/lib/vhdl`. Every directory containing `*.vhd` files
maps to a logical library named by its path relative to `common/lib/vhdl` with `/`
joined as `_` — e.g. `common/lib/vhdl/util/tb/` is compiled into library `util_tb`.
Current libraries:

| Library  | Directory                   | Contents                                                    |
| -------- | --------------------------- | ----------------------------------------------------------- |
| `util`   | `common/lib/vhdl/util/`     | general helpers (`util_pkg`: `clog2`, `is_pow2`, `to_sl`, ...) |
| `util_tb`| `common/lib/vhdl/util/tb/`  | testbench helpers (`tb_pkg`: `check`, `check_eq`)           |
| `cells`  | `common/lib/vhdl/cells/`    | structural cells (`full_adder`, `cas`, `cas_row`, `dff_sc`) |
| `arith`  | `common/lib/vhdl/arith/`    | arithmetic units (`conditional_sum_adder`)                  |

`sim.sh` compiles all of them before the problem sources, ordered by the
`library X;` cross-references between them (or the subset/order listed in a
problem's `VHDL_LIBS`), so problem code can simply write:

```vhdl
library util;
use util.util_pkg.all;
...
u0 : entity cells.full_adder port map (...);
```

Within a library, files compile alphabetically; when that order would violate
dependencies, a `files.order` (one filename per line, `#` comments) pins the
compile order.

Editor support: `vhdl_ls` (provided by the dev shell; `std`/`ieee` are bundled)
reads `vhdl_ls.toml` at the repo root, which maps each library directory and each
problem directory to a logical library with the same naming rule — one entry per
problem (`work.` resolves within a problem's own library, mirroring ModelSim).
When adding a library or problem directory, add its line to `vhdl_ls.toml`. Keep
the editor workspace rooted at the repo root so the file is found.

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
