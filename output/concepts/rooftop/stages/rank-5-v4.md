# Rank 5 v4 — moving distant billboard videos

Full scene: `rank-5-billboards-v4.gif`.
Billboard detail: `rank-5-billboards-detail-v4.gif`.
Builder: `scripts/animate_rooftop_rank5_billboards_v4.py`.

Uses the approved `rank-5-complete-v3.gif` as its exact source. Three screen interiors are projected into their existing perspective quadrilaterals; frames, building faces, the horizontal panel's vertical divider and foreground occlusion remain stationary.

- Purple vertical screen: three coarse pixel-art fashion-ad keyframes, short eased transitions and a traveling luminous ribbon. Six-second cycle.
- Cyan portrait screen: neighboring portrait keyframes and a traveling cyan scan highlight. Five-second cycle. Only the visible screen above the occluding roof is edited.
- Horizontal magenta screen: scrolling coarse source imagery with a traveling neon waveform. Ten-second cycle.

Full GIF remains 438 × 900, 1,200 frames at 20 fps, exactly 60 seconds, looping indefinitely. All screen motions repeat exactly at 60 seconds. The 800 × 344 detail GIF covers the three signs and repeats after 30 seconds; the included rooftop warning light periods also divide 30 seconds.

New neighboring billboard keyframes were created with built-in imagegen from rectified screen references, then composited and animated in Python/Pillow. Exact prompts are in `rank-5-billboard-prompts.md`. Earlier images and GIFs are retained. No app integration performed.

Validation: compare every decoded output frame against its source frame outside the three screen interior masks; every exterior pixel must be exactly identical. Check decoded duration, frame count, infinite looping, visible color variation on each screen and mathematical phase continuity. Inspect a contact sheet from the encoded output for perspective, screen boundaries, panel dividers and occlusion.
