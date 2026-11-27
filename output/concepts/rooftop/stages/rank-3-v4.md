Rank 3 v4: natural leaf motion

Output: rank-3-rooftop-v4.gif
Builder: scripts/animate_rooftop_rank3_v4.py

Replaces v3 broad horizontal displacement fields with small branch rotations and individual leaf rotations about their petioles. Branch motion is restrained; tips respond after slight delays to a shared slowly varying wind. Large foreground blades trace small two-dimensional arcs. Fractional sampling smooths slow movement instead of snapping one native pixel at a time.

29 local leaf regions plus four anchored branch regions. Pots, lantern and table leg remain fixed. Maximum leaf-tip displacement 5.53 native pixels, preserving visible wind without the previous whole-clump sliding impression.

All Rank 2 v8 effects retained: typing, stretch once per 20 seconds, small hair-tip motion, lamp breathing and display page changes every 10 seconds. Coffee remains removed. No newly generated image assets in this revision.

Validation: 400 decoded frames, exact 20-second infinite loop. Pixels outside plant regions match v3 exactly across all frames. Visually checked typing, stretching and both display pages. Previous outputs retained; no app integration performed.
