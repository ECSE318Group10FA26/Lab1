{
  description = "ECSE 318 Lab 1 - non-restoring divider (ModelSim via podman, GTKWave for viewing)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              gtkwave # waveform viewer for sim/divider_tb.vcd
              nil
              nixd
            ];

            # NOTE: podman is intentionally NOT included here. Rootless
            # podman needs host subuid/subgid setup, so use the system
            # podman that modelsim.sh / sim.sh already rely on.

            shellHook = ''
              echo "Lab1 dev shell: gtkwave available."
              echo "  ./sim.sh  problemN   - compile + simulate problem N in the ModelSim container"
              echo "  ./wave.sh problemN   - simulate problem N, then open waveforms in gtkwave"
            '';
          };
        });
    };
}
