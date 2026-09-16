#!/usr/bin/env bash
# Interactive shell inside the ModelSim container, with the repo mounted at
# /work. Useful for GUI/debug sessions; for batch runs use ./sim.sh instead.
podman run -it --rm -v "$PWD:/work:Z" -w /work docker.io/goldensniper/modelsim-docker
