# Rank 5 v5 — animated left cube billboard

Output: `rank-5-billboards-cubes-v5.gif`.
Builder: `scripts/animate_rooftop_rank5_cubes_v5.py`.
Source: approved `rank-5-billboards-v4.gif`.

The left large cyan display now shows two rotating cubes. The upper cube is a luminous wireframe rotating once per 12 seconds; the lower cube has shaded cyan faces and rotates the opposite way once per 15 seconds. Small highlights run along their edges. Geometry is rendered at fourfold native resolution, then reduced to the scene's pixel scale, with local glow confined to the screen interior. The frame, facade and overlapping small signs remain fixed.

The empty display plate was made with built-in imagegen from `rank-5-cubes-reference.png`; the exact prompt is stored in `rank-5-cubes-prompt-v5.md`. The generated plate is saved in the project as `rank-5-cubes-clean-plate-v5.png`. Cube animation uses deterministic projected geometry.

Full scene remains 438 × 900, 1,200 frames at 20 fps, a 60-second infinite loop. Both rotations and edge highlights repeat exactly at 60 seconds. All other accepted animations are inherited frame-for-frame from v4, including billboard videos, rooftop red lights, trains, traffic, residents, AC fans, plants, girl, lamp and holographic display. Previous assets are retained. No app integration performed.

Verification: compare all 1,200 decoded output frames with v4 outside the left display edit mask; exterior pixels must be exactly identical. Confirm decoded duration, frame count and infinite loop. Confirm visible variation above 20 intensity units on more than 200 pixels in each cube region. Inspect geometry contact sheet and final decoded full-scene frame.
