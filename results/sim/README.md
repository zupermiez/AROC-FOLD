# Sim benchmark results

## 2026-10-13 · `lehome_sim` (Larchenko's released sim-round checkpoint), unmodified
48 public Release garments (10 seen + 2 unseen per type) × 10 episodes = 480 episodes. 2 workers on an RTX 5090, 3 h 6 min, `--metrics_only`.

| Garment type | Ours (95% CI) | His leaderboard* |
|---|---|---|
| top_long   | **88.3%** (83.5–93.2) | 74.5% |
| top_short  | **77.5%** (71.2–83.8) | 70.0% |
| pant_long  | **72.5%** (65.8–79.2) | 80.5% |
| pant_short | **95.8%** (92.8–98.8) | 93.5% |
| **Overall** | **83.5%** (80.8–86.3) | 79.63% |

Seen: 339/400 = 84.8%. Unseen: 62/80 = 77.5%.

\*The leaderboard used 80 garments: 10 seen plus 10 *hidden* unseen per type. Our set is mostly seen garments, so the two columns aren't directly comparable. The README predicts "80%+ on seen, slightly lower on unseen", and our results match that.

Weakest garments (≤50%), where improvement work should start:
- Pant_Long_Seen_0, _3, _8: 40% each
- Pant_Long_Seen_9: 50%
- Top_Short_Unseen_0: 20%

Raw output: `bench_lehome_sim_20261013_1742.{txt,json}`.
