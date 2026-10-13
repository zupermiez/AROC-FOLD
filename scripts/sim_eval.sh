#!/usr/bin/env bash
# Evaluate a checkpoint in Isaac Sim using Larchenko's run_eval.py, with this machine's fixes applied.
#   scripts/sim_eval.sh [--gui] [run_eval.py args...]
# Example: scripts/sim_eval.sh --gui --garment_types top_long pant_short --num_garments 1 --num_episodes 1
set -euo pipefail
REF="$(cd "$(dirname "${BASH_SOURCE[0]}")/../external/lehome_solution" && pwd)"
if [[ "${1:-}" == "--gui" ]]; then export AROC_GUI=1; shift; fi
# The venv's CUDA 12.9 ptxas: the system one (12.0) is too old for sm_120.
export PATH="$REF/.venv/lib/python3.11/site-packages/nvidia/cuda_nvcc/bin:$PATH"
# Leave GPU memory for Isaac Sim on the 32 GB card (serve.py defaults to 0.8).
export XLA_PYTHON_CLIENT_MEM_FRACTION="${XLA_PYTHON_CLIENT_MEM_FRACTION:-0.55}"
export __GLX_VENDOR_LIBRARY_NAME=nvidia
cd "$REF"
exec env -u CONDA_PREFIX uv run python scripts/run_eval.py \
  --checkpoint_dir "${CKPT:-outputs/checkpoints/lehome_sim}" --config_name "${CONFIG:-pi_modified_bc_rl}" \
  --num_workers 1 --no_wandb --no_save_dataset "$@"
