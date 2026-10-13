# AROC-FOLD Roadmap

**North star:** a policy that folds children's clothes reliably on **our real SO-101 rig**. Reliability means a high success rate over many trials, not one good demo. Sim is a tool, not the target.

**Strategy:** copy first, then improve. Start from Larchenko's released `lehome_real` checkpoint and his real-round recipe. Get it working on our rig and measure it honestly. Then add what he lacked time for, as listed in report §10:
- a real-side value function
- value-weighted DAgger
- more DAgger iterations
- inference-time tuning on the real robot

---

## M0: Workstation and reference stack runs (≈ 3–5 days)
Goal: every reference entry point runs on this machine.
- [ ] Create the public GitHub repo `AROC-FOLD` and vendor `lehome_solution` as a submodule. **Fork it first** so our patches have a home.
- [ ] Run `setup.sh` step by step, not blindly. It edits `~/.bashrc`, installs apt packages, and creates `/usr/local/bin/zenity`.
- [ ] **Blackwell compatibility:** switch torch/torchcodec to cu128 wheels and check that JAX works on sm_120 (`jax.devices()`, a matmul, and a Pi0.5 forward pass). Record the pins we changed.
- [x] Isaac Sim 5.1 opens on the 5090 under Ubuntu 24.04 (GUI verified 2026-10-13; headless not yet tested). Garment assets downloaded. See `docs/setup_sim.md`.
- [ ] HF login. Download the `lehome_sim` and `lehome_real` checkpoints and the sim and real BC datasets, then run `enrich_garment_type.py`.
- [ ] **Sim sanity check:** `run_eval.py --metrics_only` with `lehome_sim` on the seen garments. Expect about 80%. This proves the stack is wired correctly.
- [ ] **Measure VRAM:** inference latency for `lehome_real` on the 5090. Find the largest batch that fits for (a) LoRA and (b) frozen VLM + trainable action expert.

**Exit criterion:** sim eval reproduces roughly 80% on a subset, and we know what can and cannot be trained locally.

## M1: Real rig bring-up and alignment (≈ 1 week, can overlap M0)
Goal: our rig looks like the organizers' rig to the policy.
- [ ] Mechanical geometry: followers 46 cm apart and the top camera at about 65 cm. Match the official setup (see photos and frames in `lehome/dataset_challenge_real`).
- [ ] Calibrate all 4 arms with LeRobot. Fill in `configs/real_robot.yaml` (serial ports by id, camera devices). Decide on a top camera: Larchenko used a RealSense D435 at 1280×720. Our camera needs to produce a matching image.
- [ ] **Units check:** replay organizer trajectories (degree mode). Joint angles must match the dataset, with no ~10% skew.
- [ ] Use `scripts/real_camera_align.py` to overlay our live views on dataset frames and adjust the cameras until they match.
- [ ] Teleop check: record 5 manual episodes with `record_real_dagger.py --manual_only` and confirm they load as a LeRobot dataset.
- [ ] Buy a **fixed garment set**: about 5 per type (top_long, top_short, pant_long, pant_short), kids' sizes, with some held out as "unseen".

**Exit criterion:** live camera overlays match the dataset, joint units are verified, and teleop recording works end to end.

## M2: Baseline, the "copy" result (≈ 3–4 days)
Goal: an honest number for Larchenko's policy on our rig.
- [ ] Write `docs/eval_protocol.md`. It must define:
  - fixed start states (photos or tape marks)
  - trials per type (≥10)
  - a time limit
  - a success definition, binary plus partial credit similar to the jury's
  - a seen/unseen split
- [ ] Run `serve.py` + `record_real_dagger.py` with `lehome_real` zero-shot on our rig and log the results in `results/real_eval.csv`.
- [ ] Tune the inference knobs (actions_to_execute, actions_to_keep, num_steps) by hand at a small scale.
- [ ] Catalogue the failure modes in a short table: grasp misses, wrong garment-type behavior, stuck states, speed.

**Exit criterion:** a baseline success rate per garment type with a failure taxonomy. **This is the number everything else must beat.**

## M3: Reproduce the real-round recipe on our data (≈ 2–3 weeks)
Goal: the DAgger flywheel runs on our rig.
- [ ] Collect home teleop and DAgger data, starting with about 50 episodes per type. Use a foot pedal for SPACE, → and ← (strongly recommended).
- [ ] Set up the cloud training loop on a rented H100/H200, with a reproducible bootstrap script (setup, data from HF, train, push the checkpoint to HF):
  - start from `lehome_real`
  - use the 60/30/10 mix from `configs/train_real_bc.yaml`
  - upload checkpoints to a private HF repo
- [ ] Iterate at least 3 times: deploy, DAgger-correct, retrain, then evaluate with the protocol. Larchenko managed only 2–3 iterations and saw gains every time.
- [ ] Randomize the rig between sessions (light, small camera nudges, recalibration) so the policy doesn't depend on exact geometry.

**Exit criterion:** clear improvement over the M2 baseline on our protocol, and one iteration takes ≤ 2 days.

## M4: Improve beyond the reference (open-ended)
Rough priority order, based on Larchenko's own §10 analysis:
1. **Real-side value function.** Re-enable the success and completion heads on real data, using episode outcomes and DAgger takeover points as labels.
2. **Advantage-weighted BC (AWR) on real data**, with the advantage computed from that value function. Also weight DAgger corrections by value.
3. **Best-of-N on real**, scoring 2–3 candidate chunks with the value or Q head. This helped in sim.
4. **Real-side inference tuning** with the Thompson-sampling bandit from `inference_optimization.py`.
5. **Recovery behavior:** deliberately collect recoveries from messy states, his main unsolved failure mode.
6. **Clean completions from easy starts.** More short, high-quality data near the end of the fold.
7. **Efficiency:** distil to a smaller or faster model. He says Pi0.5 is likely oversized, and a smaller model would let us train locally on the 5090.
8. **Sim as a helper:** a little augmented sim data (≤10%), or sim RL on new garment conventions only if it shows a measurable real-world gain.

## Compute plan
| Workload | Where |
|---|---|
| Isaac Sim rollouts and eval, policy serving, real-robot runs | Local RTX 5090 |
| LoRA or partial fine-tunes, quick experiments | Local, if M0 says it fits |
| Full Pi0.5 fine-tunes (reference: batch 192, about 50k steps for the real round) | Rented 80–141 GB GPU |

## Open questions / decisions log
- ✅ 2026-10-13: full fine-tunes run on a **rented cloud GPU** (H100/H200 class). Still open: which provider, and the budget per training run (decide after M0 measures step time).
- Top camera model: the RealSense D435 that Larchenko used, or what we have?
- Do we enter a future LeHome edition, or target home use only?
