# What trains on the RTX 5090 (32 GB), measured 2026-10-16

Setup: `scripts/train.py --yaml` using his `train_real_bc.yaml` recipe. Initialized from `lehome_sim/params`, trained on the organizer's real data (500 episodes). `XLA_PYTHON_CLIENT_MEM_FRACTION=0.95`. About 2.4 GB of VRAM was already used by the desktop and other processes. Test YAMLs are in `configs/fit_test/`.

| Variant | Batch | Result |
|---|---|---|
| Full fine-tune (his recipe, EMA on) | 8 | **OOM in `init_train_state`**: the train state alone needs 39.1 GiB, before any batch |
| Full fine-tune, `ema_decay: null` | 8 | **OOM**: the train state needs 28.6 GiB |
| LLM frozen (`AROC_FREEZE_LLM=1`), EMA on | 8 | OOM: step program 29.4 GiB |
| **LLM frozen, EMA off** | 8 | ✅ step program about 18.8 GiB |
| **LLM frozen, EMA off** | **32** | ✅ **about 2.0 s/step**, about 16 samples/s |
| LLM frozen, EMA off | 64 | OOM |

Conclusions:
- **Full fine-tuning (his method) cannot run on this card at any batch size.** It needs a rented 80+ GB GPU. Larchenko used an H200 at batch 192.
- **Locally:** we can train the action expert, heads, and vision projection with the PaliGemma LLM frozen, at batch ≤32. 50k steps at b32 takes about 28 h, which is the data equivalent of only about 8k steps of his b192 run. That's fine for small experiments and quick ablations, not for reproducing his recipe.
- **Possible savings not tried yet:** cast the frozen LLM to bf16 (`train.py` currently only casts `freeze_filter` params, so ours stay fp32, which wastes about 4 GB). Also gradient accumulation.
- `AROC_FREEZE_LLM` is our patch to `training/config.py::trainable_filter`. It changes the method compared to his, so results from it aren't comparable to full fine-tuning.
