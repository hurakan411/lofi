Rank 5 revised train behavior

Output: rank-5-complete-v2.gif
Builder: scripts/animate_rooftop_rank5_long_train.py

Five-car consist (180 pixels wide rather than 112 at 438x900), train travel speed 85px/s rather than approximately 51px/s. Removed the artificial left cutoff at x=165; train continues across the visible viaduct and exits the frame with scene-based ladder/roof/pole occlusion. Verified one continuous visible pass at 0.95–6.35 seconds with no missing interval. Train appears once per exact 30-second looping GIF (600 frames at 20fps). Background completes four complete established eight-second cycles in thirty seconds to avoid a loop discontinuity. Verified coherent lamp/desk light and retained typing, monitor, leaf and road-car motions. Prior versions retained.
