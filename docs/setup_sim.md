# Sim environment setup (verified 2026-10-13, RTX 5090 / driver 580.178.04 / Ubuntu 24.04)

**System packages and NVIDIA drivers were not modified.** Do not run the reference `setup.sh` as-is: its step 1 reinstalls and downgrades `libnvidia-gl-*` packages, and the drivers on this shared machine are pinned on purpose. Every system library Isaac Sim needs was already present, including `/usr/share/vulkan/icd.d/nvidia_icd.json`.

## Environment
A uv venv at `external/lehome_solution/lehome-challenge/.venv` (Python 3.11.15). It is deliberately not conda: the reference scripts hardcode this venv path.
- isaacsim 5.1.0, IsaacLab fork `lehome-official/IsaacLab` @ 69f6fa54 (isaaclab 0.53.1), lerobot 0.4.3, numpy 1.26.0
- `warp-lang==1.12.1`, pinned because newer releases break Isaac Sim 5.1
- **torch 2.7.0+cu128 / torchvision 0.22.0+cu128.** The lockfile resolves to cu126, which has no sm_120 kernels and fails on the 5090 with "no kernel image is available".
- `OMNI_KIT_ACCEPT_EULA=YES` is exported in `.venv/bin/activate`. The user accepted the NVIDIA Omniverse EULA on 2026-10-13.

## Steps
```bash
cd external/lehome_solution && GIT_LFS_SKIP_SMUDGE=1 git submodule update --init lehome-challenge
cd lehome-challenge
env -u CONDA_PREFIX uv sync
git clone https://github.com/lehome-official/IsaacLab.git third_party/IsaacLab
echo 'export OMNI_KIT_ACCEPT_EULA=YES' >> .venv/bin/activate
source .venv/bin/activate && ./third_party/IsaacLab/isaaclab.sh -i none   # the final vscode step fails: harmless
P=.venv/bin/python
uv pip install "setuptools<70" wheel --python $P
uv pip install flatdict==4.0.1 --no-build-isolation --python $P
uv pip install -e third_party/IsaacLab/source/isaaclab -e source/lehome --python $P
uv pip install "warp-lang==1.12.1" --python $P
uv pip install --index-strategy unsafe-best-match --reinstall-package torch --reinstall-package torchvision \
  "torch==2.7.0+cu128" "torchvision==0.22.0+cu128" \
  --index-url https://download.pytorch.org/whl/cu128 --extra-index-url https://pypi.org/simple --python $P
uvx --from "huggingface_hub[cli]" hf download lehome/asset_challenge --repo-type dataset --local-dir Assets
```
Re-running `uv sync` will revert torch to cu126. Re-apply the last torch step afterwards.

## Smoke test (GUI)
```bash
cd external/lehome_solution/lehome-challenge && source .venv/bin/activate
export __GLX_VENDOR_LIBRARY_NAME=nvidia
python -m scripts.eval --policy_type custom --garment_type top_long --num_episodes 1 --max_steps 300 --enable_cameras --device cpu
```
Results:
- App ready in about 18 s and the scene loads.
- The first episode took about 68 s, most of it warm-up (shader and cloth cooking). The next 11 episodes took **about 16 s per 300 steps, roughly 19 sim steps/s** (cloth physics on CPU, GUI open).
- Garment switching works. All 12 top_long garments ran, with success at 0% as expected for the dummy policy, and the app exited cleanly.
- Known noise: a "No visual materials specified" warning, and a PhysX `attachShape: non-SDF triangle mesh` error at startup. Neither is fatal.

## Main venv (openpi / JAX policy server), verified 2026-10-13
```bash
cd external/lehome_solution && git apply ../../patches/lehome_solution.patch   # if not applied
GIT_LFS_SKIP_SMUDGE=1 git submodule update --init openpi
env -u CONDA_PREFIX GIT_LFS_SKIP_SMUDGE=1 uv sync
uv pip install toml && uv pip install --no-deps -e lehome-challenge/source/lehome
uvx --from "huggingface_hub[cli]" hf download IliaLarchenko/lehome_sim --local-dir outputs/checkpoints/lehome_sim   # 9.8 GB
```
- Results: torch 2.7.1+cu128, jax 0.5.3, lerobot 0.4.4. JAX works on sm_120 **as long as** the venv's ptxas (CUDA 12.9, `.venv/lib/python3.11/site-packages/nvidia/cuda_nvcc/bin`) comes first on PATH. `scripts/sim_eval.sh` handles that.
- serve.py preallocates 80% of VRAM by default. With Isaac Sim on the same 32 GB card, `XLA_PYTHON_CLIENT_MEM_FRACTION=0.55` works.

## Policy eval
```bash
scripts/sim_eval.sh --gui --all --randomize_garments --rl_seed 1 --num_garments 4 --num_episodes 1 --no_save_pkl
scripts/sim_eval.sh --metrics_only --all --randomize_garments --num_garments 40 --num_episodes 1   # headless benchmark
```
First runs of `lehome_sim`, 1 worker:
- Top_Long_Unseen_0/1: 2/2 success
- Pant_Long_Seen_0–3: 3/4 success

About 30–40 s of wall time per episode, including best-of-N inference.
