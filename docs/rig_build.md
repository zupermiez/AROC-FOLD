# Physical rig build (M1)

Goal: our rig should look to the policy like the organizer's rig in `lehome/dataset_challenge_real`. Larchenko's `lehome_real` policy was trained on that data plus his home data. Every difference costs success rate. He also showed the policy tolerates moderate differences if we add augmentation and randomize the rig.

Reference frames from the organizer data are in `reference_frames/` (git-ignored; regenerate with ffmpeg from `data/lehome_real/.../videos/`).

## Target spec (from the dataset and his report)
| Item | Spec |
|---|---|
| Arms | 2 SO-101 followers and 2 SO-101 leaders. Bimanual `bi_so_follower` in LeRobot, `use_degrees=True` (joints in degrees, gripper 0–100) |
| Follower spacing | **46 cm** apart |
| Top camera | `right_front` stream, **1280×720 @ 30 fps**, about **65 cm** above the table. Mounted behind the arms looking down and forward: both follower bases appear at the **bottom edge** of the frame, with the garment centred above them. Larchenko used a RealSense D435 (RGB stream) |
| Wrist cameras | `left_wrist` / `right_wrist`, **640×480 MJPG @ 30 fps**, on the standard SO-101 wrist mount. The fixed jaw is visible at the bottom centre |
| Control rate | 20 Hz |
| Table | Plain, matte, **light/white** surface with no texture and even, diffuse light (no hard shadows) |
| Garments | Kids' clothes, about **size 100 (EU 98/104, age 3–4)**. The organizer's long top is label "100/52". Four types: long-sleeve top, short-sleeve top, long pants, shorts |
| Laying out | Garment flat and spread out in front of the arms, roughly centred (see `right_front_start.jpg`) |

## Build steps
1. **Arms:** assemble and test all 4. Check servo IDs and power: followers on their own supply, leaders on theirs.
   - **Follower voltage:** the 12V STS3215 followers are fine and preferred here, since they give more torque, less sag at long reach, and less heat. The organizers' voltage is unknown. The policy outputs joint position targets, so the voltage only affects tracking under load. Rules: all 6 servos per follower are the same 12V variant, both followers are identical, use a 12V supply of ≥5A per follower, and never put 12V on a 7.4V arm. Leaders stay 7.4V servos on 5V.
2. **Table and bases:** clamp the follower bases firmly 46 cm apart on the light work surface. Put the leaders beside it where you can teleop comfortably, ideally facing the same direction as the followers.
3. **Top camera:** build a rigid overhead mount about 65 cm up (an arm or gantry behind the robots), with no wobble. Match the reference framing roughly by eye first; fine alignment comes later with the overlay tool.
4. **Wrist cameras:** fit them to the SO-101 wrist mounts. Route cables so they don't snag during full joint motion.
5. **Lighting:** diffuse and even. Avoid windows with direct sun. The policy is sensitive to colour and brightness shifts. Augmentation helps, but don't depend on it.
6. **USB:** use a powered hub if needed. **Serial permission:** your user isn't in `dialout`. A one-off `sudo usermod -aG dialout $USER`, then re-login, is better than `chmod 666` on every boot. On this shared machine, confirm that's OK first.
7. **Foot pedal (recommended):** a 3-pedal USB pedal that emulates keyboard keys (`SPACE`, `→`, `←`) for DAgger takeovers.
8. **Garments:** about 5 per type, size about 100. Keep 1–2 per type aside as "unseen" and never use them in training.

## Software bring-up (after the build)
1. LeRobot calibration of all 4 arms in the challenge venv (lerobot 0.4.3).
2. Fill in `configs/real_robot.yaml` with ports from `/dev/serial/by-id/` and cameras from `/dev/v4l/by-path/` (and the RealSense serial, if used).
3. **Units check:** drive the followers to joint states from the dataset and confirm the poses match. A LeRobot 0.4.x default change caused about a 10% joint skew for Larchenko.
4. **Camera alignment:** `scripts/real_camera_align.py` overlays live views on dataset frames. Adjust the mounts until static features (table edge, robot bases) line up.
5. Record 5 manual teleop episodes, `record_real_dagger.py --manual_only`, and check they load as a LeRobot dataset.
