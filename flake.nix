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
                " 4"
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
              # one problem (lib + sources + testbench) from its problem.env.
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
                    shopt -s nullglob
                    sources=()
                    for f in ''${SOURCES:-}; do sources+=("$f"); done
                    for d in ''${LIB_DIRS:-}; do
                      for g in "$d"/*.v; do sources+=("$g"); done
                    done
                    echo "==> slang: $dir"
                    # --timescale mirrors the -timescale flag in common/run.do:
                    # default time base for library modules (tbs set their own)
                    ${pkgs.sv-lang}/bin/slang --lint-only --timescale 1ns/1ps -Wunused \
                      "''${sources[@]}" "$TB_SOURCE" --top "$TB_TOP"
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
            ];

            shellHook = ''
              echo "Lab1 dev shell."
              echo "  ./sim.sh  problemN   - compile + simulate problem N in the ModelSim container"
              echo "  ./wave.sh problemN   - simulate problem N, then open waveforms in gtkwave"
            '';
          };
        };
      }
    );
}
