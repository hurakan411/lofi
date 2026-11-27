Rank 5 v3: inherit latest Rank 4 and add rooftop warning beacons

Output: rank-5-complete-v3.gif
City/train detail: rank-5-city-detail-v3.gif
Builder: scripts/animate_rooftop_rank5_v3.py

Full scene: 438×900, 1200 frames, 20 fps, exact 60-second infinite loop. Uses three complete Rank 4 v5 loops with no time remapping. Preserves eight road cars, staggered gestures by three residents, four spinning AC rotors, extinguished second room, independent plant wind, girl typing/stretching, hair, lamp and display pages. Stretch stays every 20 seconds and display switches every 10 seconds. Coffee remains removed.

Far skyline and railway are revealed using existing artwork. Roadway, the darkened room and rotating rooftop fans are explicitly protected during compositing. The accepted five-car train moves at 85 native px/s, continuing entirely off-frame with scene-based occlusion. Visible continuously at 0.95–6.35s and 30.95–36.35s; no mid-pass gaps.

24 existing red rooftop/mast lights blink. Emissive cores and local glow pulse while architecture stays fixed; only light emission is reduced during the off phase. Towers have different phases and periods of 2, 2.5 or 3 seconds. Every light shows a decoded red intensity variation above 20; pulse phases match at 60 seconds. No new image generation was required.

Validation: full decoded GIF duration/loop, two continuous train passes exactly 30 seconds apart, all 24 beacons, constant dark second room and seamless periodic light phases. Encoded foreground at 0, 20 and 40 seconds matches exactly. All four fans and both resident rooms retain clear encoded movement. Indexed final frame inspected. City-detail GIF is 876×580, exact 30-second loop; covers beacons/train and the top rotor, whose period also divides 30 seconds. Earlier files retained; no app integration performed.
