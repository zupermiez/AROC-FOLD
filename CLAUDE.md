# AROC-FOLD — CLAUDE.md

## Mission
Reproduce, then improve on, Ilia Larchenko's LeHome Challenge 2026 solution for
**bimanual folding of children's clothes with LeRobot SO-101 arms**. Larchenko
placed 1st of 62 teams in sim (79.63%) and 2nd in the real-world final (865/1080).
**The end goal is real-world folding on our own rig.** Simulation matters only
when it helps the real policy.

Plan and milestones: `docs/ROADMAP.md`. Keep it current. When a milestone moves,
update it in the same change.

## Reference material (read before major design decisions)
- Code: https://github.com/IliaLarchenko/lehome_solution (vendored at `external/lehome_solution`, with its own submodules `openpi` and `lehome-challenge`)
- Blog: https://ilialarchenko.com/projects/lehome2026/
- Tech report: https://arxiv.org/abs/2606.27163 (HTML: arxiv.org/html/2606.27163v3). Read §9 for sim-to-real and §10 for future work.
- Checkpoints on Hugging Face: `IliaLarchenko/lehome_sim` (sim round), `IliaLarchenko/lehome_real` (real round)
- Official challenge: https://github.com/lehome-official/lehome-challenge
  - Sim assets: `lehome/asset_challenge`
  - Sim BC data: `lehome/dataset_challenge_merged`
  - Real BC data: `lehome/dataset_challenge_real` (500 episodes, about 187k frames)
- Notes on the reference solution: `docs/reference_notes.md`

## Hardware (this machine)
- GPU: RTX 5090, 32 GB, Blackwell sm_120, driver 580. Ubuntu 24.04, 32 cores, 60 GB RAM, about 1.1 TB free.
- Real rig: 2 SO-101 leaders and 2 SO-101 followers. Followers sit **46 cm apart**. Three cameras: top at about 65 cm, plus left and right wrist. The official setup and the camera-alignment tool assume this geometry.

## Architecture in one paragraph
The policy is a **Pi0.5 VLA (openpi, JAX)** with extra pieces:
- Linear auxiliary heads on a query token: success, completion, garment type, time-to-completion, keypoint distances, and Q.
- A garment-type input token.
- Advantage conditioning (RECAP) plus AWR sampling, with CFG at inference.
- AdaRMS conditioning and XSA attention.

Actions are 12-D joint positions (2 × 6), predicted in **30-step chunks** with re-planning every 3–5 steps. Control rate is 30 Hz in sim and 20 Hz on the real robot.

Sim RL loop: trainer ⇄ HF Hub ⇄ rollout workers. For the real round he stripped the RL machinery and trained BC on this mix:
- 60% organizer data
- 30% home teleop + DAgger
- 10% augmented sim success-replays

## Environments (two separate venvs, managed with uv)
1. **Main venv** (`external/lehome_solution/.venv`): Python 3.11, openpi, JAX, torch, lerobot. Used for training, `serve.py` (policy server), and data tools. Run things with `uv run python ...`.
2. **Challenge venv** (`external/lehome_solution/lehome-challenge/.venv`): Isaac Sim 5.1.0, Isaac Lab 2.3.1 (lehome fork), lerobot 0.4.x. Used for sim rollouts **and the real-robot runner** (`record_real_dagger.py`).

The policy runs as a websocket server (`ws://localhost:8000`), and sim or robot clients connect to it.

## Key commands (run from `external/lehome_solution`)
```bash
# Sim eval, fast benchmark
uv run python scripts/run_eval.py --checkpoint_dir outputs/checkpoints/lehome_sim \
  --config_name pi_modified_bc_rl --num_workers 2 --all --num_episodes 2 --metrics_only --no_wandb

# Real robot: policy server (terminal 1)
uv run python scripts/serve.py --actions_to_execute 5 --actions_to_keep 1 --execute_in_n_steps 5 --num_steps 10 \
  policy:checkpoint --policy.config pi_modified_real_bc --policy.dir outputs/checkpoints/lehome_real
# Real robot: runner (terminal 2, challenge venv). SPACE = teleop takeover, → = save, ← = redo, Esc = stop
python scripts/record_real_dagger.py --config configs/real_robot.yaml --garment top_long --server ws://localhost:8000

# Real BC fine-tune
uv run python scripts/train.py --yaml configs/train_real_bc.yaml --resume
```

## Known gotchas (verified from reference code or report; add new ones here)
- **VRAM:** Pi0.5 full fine-tuning needs more than 70 GB (openpi README), so it **does not fit on the 5090**. LoRA needs more than 22.5 GB and inference more than 8 GB. Run full fine-tunes on rented H100/H200 machines, and use the 5090 for inference, rollouts, LoRA, and frozen-backbone experiments. Set `XLA_PYTHON_CLIENT_MEM_FRACTION=0.9`.
- **Blackwell:** the reference pins `torch==2.7.1` from the **cu126** index, which has no sm_120 kernels. A 5090 needs cu128 wheels. Also check that `jax[cuda12]==0.5.3` runs on sm_120, and upgrade if it doesn't. Write down any deviation from the reference pins.
- **Units:** the real robot runs in LeRobot `use_degrees=True` mode (joints in degrees, gripper 0–100). A LeRobot 0.4.x default change skewed joints by about 10% and Larchenko found it two days before the deadline. Check units and calibration whenever the LeRobot version changes.
- **Garment labels:** BC datasets ship with only the task string "Fold the Garment". Run `scripts/enrich_garment_type.py --domain {sim,real}` after downloading. At eval time the garment type is hidden, and the policy infers it.
- **Image pipeline sensitivity:** the policy overfits to tiny image-pipeline details. In sim, an intermediate 640×480 → 320×240 resize hurt success. Keep camera resolution, crops, and resizes identical between training data and inference.
- **Isaac Sim quirks:** `warp-lang` must be pinned to `1.12.1`. A dummy `zenity` is needed for headless runs. Physics runs on CPU (`--device cpu`), and rendering uses the GPU.
- **Real-task conventions differ from sim:** short tops are folded from the other sleeve, long pants are grabbed from a different side, and shorts are rotated 180° in half the real episodes.
- **Zero-shot sim → real fails.** Real data and DAgger are required.

## Repo conventions
- Our own code goes in `aroc/` (Python package) and `scripts/`. Patches to the reference code go in a fork or submodule branch, never as silent edits. Log every divergence in `docs/reference_notes.md`.
- **Never commit** datasets, checkpoints, videos, or `outputs/`. They belong on HF Hub (use private repos for our data and checkpoints).
- Every real-robot evaluation follows `docs/eval_protocol.md` and is logged as a row in `results/real_eval.csv`. Without a fixed protocol, real-world numbers are noise.
- Each experiment gets a short entry in `docs/experiments.md`: date, hypothesis, config or commit, result, conclusion.
- Prefer small, verifiable steps. Before claiming an improvement, compare against the current baseline on the same protocol with enough trials (≥10 per garment type).
