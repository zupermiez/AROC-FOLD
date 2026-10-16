# Reference solution notes (Larchenko, LeHome 2026)

Distilled from the repo, blog, and tech report (arXiv 2606.27163) on 2026-10-13.

## Results
- **Sim round:** 79.63% overall, 6.1 points ahead of 2nd place. Per garment: long top 74.5, short top 70.0, long pant 80.5, short pant 93.5. Evaluation covered 80 garments (10 seen + 10 unseen per type) × 10 episodes.
- **Real final:** 865/1080, 2nd place (1st was sZs with 895). The jury scored partial success, and unseen garments earned a 50% bonus. The final used 5 garments per type (3 seen, 2 unseen).
- Generalization to unseen garments was "barely an issue".

## Model
- Pi0.5 built on openpi (JAX). The SigLIP vision encoder is frozen. Flash attention and XSA (exclusive self-attention) are used.
- **Action chunks** are 30 steps of 12-D joint actions. Re-planning happens every 3–5 steps, with inpainting from the tail of the previous chunk.
- **Auxiliary heads** sit on a query token: success, checkpoint, time-to-completion, completion, garment type (4 classes), keypoint distances, Q residual, and "world-model" heads that predict quantities 30 steps ahead.
- Garment-type input token. AdaRMS multi-signal conditioning feeds the action expert.

## Sim RL loop
- BC warm-up of 20k steps, then iterations of about 1000 steps. Checkpoints go to HF every ~500 steps, roughly every 40 minutes.
- Advantage: GAE (λ 0.99, γ 0.999) combining a success-probability baseline, a completion signal, and dense keypoint progress. Two uses:
  - AWR sampling weights, `exp(clip(A, -2, 2))`
  - RECAP advantage conditioning, which enables CFG (final scale 7–9)
- Rollout datasets decay by ×0.98 per iteration, floored at 0.1.
- Scale: about 12.5k rollout episodes (≈4.3M frames) in the retained window and about 300k training steps on one H200. The author calls this not sample-efficient.
- Inference knobs were tuned by a Thompson-sampling bandit. Final values per garment are in `configs/rl_pipeline_sim.yaml`. Best-of-N with N=2–3 helped, and a noise temperature of 0.7–0.9 helped.
- DAgger in sim didn't help much: teleop in sim is hard.

## Real round (about 1 week)
- Started from a late-but-not-latest sim checkpoint. All RL machinery was stripped; only the action objective plus garment-type and completion heads were kept.
- Data mix:

| Source | Episodes | Frames | Batch share | Speed factor |
|---|---|---|---|---|
| Organizer BC | 500 | 187k | 60% | ×1.0 |
| Home teleop | 321 | 162k | 30% (shared) | ×1.5 |
| Home DAgger | 471 | 288k | (shared) | ×2.0 |
| Sim success-replays | 1723 | 625k | 10% | ×0.65 |

- DAgger weighting: human-correction frames get the highest weight. Autonomous frames in the 5 s before a takeover ramp down to weight 0.
- Heavy per-camera augmentation: color, gain, gamma, blur, noise, crop/rotate/zoom, cutout, camera dropout, and state noise/dropout.
- Rig randomization: cameras moved, arms recalibrated, and lighting changed during the week.
- Hardware: RealSense D435 top camera (1280×720), 640×480 MJPG wrist cameras, 20 Hz control, a three-pedal foot controller, and an RTX PRO 6000 workstation.
- Failures to watch for:
  - Zero-shot sim → real failed.
  - The LeRobot 0.4.x units bug (about 10% joint skew).
  - Task conventions differ from sim.

## His own "next steps" (§10)
- One pipeline: a real-side reward/value function, value-weighted DAgger, and more clean completions from easy starts.
- Automatic exploration and recovery is unsolved. Exploration noise pushed flow-matching chunks off the action manifold.
- Pi0.5 is probably oversized, and a smaller model could match it. He guesses 90%+ is achievable.

## Divergences from reference (AROC-FOLD)
_Log every change we make to the reference stack here: date, what changed, why._
- 2026-10-13: sim venv uses torch 2.7.0+cu128 instead of the locked cu126 (RTX 5090 / sm_120). See docs/setup_sim.md.
- 2026-10-13: main venv torch index cu126 → cu128 (RTX 5090). `pyarrow<24`, because there is no uv.lock and pyarrow 24+ needs numpy 2. Patch file: `patches/lehome_solution.patch`.
- 2026-10-13: `eval_worker.py` honours `AROC_GUI=1` to start Isaac Sim with a window instead of `--headless`.
- Note: run_eval.py **does** auto-load the checkpoint's `assets/inference_config.json` (tuned per-garment settings), and serve.py takes `use_xsa` from the train config, so the defaults reproduce his setup.
- Note: `--num_garments N` without `--randomize_garments` takes the first N garments in list order, which may all be one type. Use `--randomize_garments --rl_seed S` for stratified sampling.
- Note: without `--no_save_pkl`, each episode writes a raw pkl of about 0.65–1.3 GB to `temp_episodes/`.
- 2026-10-16: `training/config.py` honours `AROC_FREEZE_LLM=1`, which freezes the PaliGemma LLM and trains only the action expert and heads, so training fits in 32 GB. Opt-in only; the default behaviour is unchanged.
