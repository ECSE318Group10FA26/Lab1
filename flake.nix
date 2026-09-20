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
              options = [ "--inplace" ];
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
