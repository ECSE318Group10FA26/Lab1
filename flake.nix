{
  description = "ECSE 318 Lab 1";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    { self, ... }@inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        treefmtconfig = inputs.treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs = {
            mdformat = {
              enable = true;
              plugins = ps: [
                ps.mdformat-gfm
                ps.mdformat-frontmatter
              ];
              settings = {
                wrap = 88;
                end-of-line = "lf";
              };
            };
            shellcheck.enable = true;
            shfmt.enable = true;
            nixfmt.enable = true;
          };
          settings.formatter = {
            verible-verilog-format = {
              command = "${pkgs.verible}/bin/verible-verilog-format";
              options = [
                "--inplace"
                "--indentation_spaces"
                "4"
              ];
              includes = [
                "*.v"
                "*.sv"
                "*.vh"
                "*.svh"
              ];
            };
            verible-verilog-lint = {
              command = "${pkgs.verible}/bin/verible-verilog-lint";
              # Use --autofix=inplace to let treefmt apply fixable lint rules automatically
              options = [ "--autofix=inplace" ];
              includes = [
                "*.v"
                "*.sv"
                "*.vh"
                "*.svh"
              ];
            };
            slang-lint = {
              # slang lints whole designs, not single files: the lint unit is
              # one problem (lib + sources) plus EACH testbench in tb/ as its
              # own top (top module name = file name, repo convention).
              # The changed-file list treefmt passes as arguments is ignored;
              # treefmt runs this from the project root.
              command = pkgs.writeShellScriptBin "slang-lint" ''
                rc=0
                for env in */problem.env; do
                  dir="''${env%/problem.env}"
                  (
                    set -eu
                    cd "$dir"
                    source ./problem.env
                    shopt -s nullglob globstar
                    sources=()
                    for f in ''${SOURCES:-}; do sources+=("$f"); done
                    for d in ''${LIB_DIRS:-}; do
                      for g in "$d"/**/*.v; do sources+=("$g"); done
                    done
                    # --timescale mirrors the -timescale flag in common/run.do:
                    # default time base for library modules (tbs set their own)
                    for tb in tb/*.v; do
                      echo "==> slang: ''${dir}''${tb}"
                      ${pkgs.sv-lang}/bin/slang --lint-only --timescale 1ns/1ps -Weverything -Werror \
                        "''${sources[@]}" "$tb" --top "$(basename "$tb" .v)"
                    done
                  ) || rc=1
                done
                exit "$rc"
              '';
              includes = [
                "*.v"
                "*.sv"
                "*/problem.env"
              ];
            };
            shellcheck.excludes = [
              ".envrc"
            ];
          };
        };
      in
      {
        formatter = treefmtconfig.config.build.wrapper;
        devShells = {
          default = pkgs.mkShell {
            packages = with pkgs; [
              gtkwave
              nil
              nixd
              verible
              haskellPackages.sv2v
              yosys
              sv-lang
              # physical layout: RTL -> GDSII flow and layout viewers
              librelane
              pdk-ciel
              klayout
              magic-vlsi
              # gate-level graphs/schematics (yosys show renders via dot)
              graphviz
              netlistsvg
              xdot
            ];

            shellHook = ''
              # keep the sky130 PDK inside the repo (gitignored), not ~/.ciel;
              # both librelane and ciel resolve their PDK home from PDK_ROOT
              export PDK_ROOT="$(git rev-parse --show-toplevel)/.ciel"

              echo "Lab1 dev shell."
              echo "  ./sim.sh  problemN   - compile + simulate problem N in the ModelSim container"
              echo "  ./wave.sh problemN   - simulate problem N, then open waveforms in gtkwave"
              echo "  librelane <cfg.yaml> - RTL -> GDSII layout (one-time PDK: ciel enable --pdk-family sky130)"
            '';
          };
        };
      }
    );
}
