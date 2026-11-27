Rank 4 v4: apartment resident gestures

Output: rank-4-near-traffic-residents-v4.gif
Detail preview: rank-4-residents-detail-v4.gif
Builder: scripts/animate_rooftop_rank4_residents_v4.py

Adds drawn local poses to three existing residents in the right apartment: blue-room desk work, and two people gesturing/responding in the lower warm room. Original pose plus two locally generated keyframes; no body warping. Blue-room gestures start at 1.8, 8.5 and 15.4 seconds. Lower-left gestures start at 4.5 and 12.3 seconds; lower-right responses start at 5.4 and 13.4 seconds. All return to the original pose before the loop boundary. Window bars, balcony railing and lampshade are protected.

Built-in image_gen produced two pose edits from rank-4-residents-reference.png. Prompts saved in rank-4-residents-prompts.md. Only three small silhouette neighborhoods are used (979 native pixels); all other generated pixels are discarded. Exact original palette indices are restored outside active gesture masks, avoiding re-quantization changes to the approved scene.

438×900, 400 frames at 20 fps, 20-second infinite GIF. Validation compares all decoded frames with v3: every pixel outside resident masks is identical; first/last frames contain no resident edit; actual gesture changes confirmed. Prior eight cars, independent plants, girl typing/stretching, hair, lamp and 10-second display changes retained. Zoom GIF duration also verified. Contact sheet checked all three gestures. No app integration performed; earlier versions retained.
