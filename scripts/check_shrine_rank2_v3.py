"""Read-only checks of decoded GIF motion, fixed scenery, and tool order."""
from pathlib import Path
import hashlib
import json
from PIL import Image

folder = Path(__file__).resolve().parents[1] / "output/concepts/shrine"
gif = Image.open(folder / "rank-2-office-v3.gif")
boxes = {
    "water": (34, 1107, 207, 1207),
    "hand": (483, 975, 539, 1027),
    "noren": (530, 879, 600, 927),
    "noren_mount": (532, 873, 600, 878),
    "wall_below_noren": (535, 934, 580, 940),
    "paper_edge": (475, 1021, 510, 1025),
    "desk_edge": (450, 1028, 535, 1032),
}
hashes = {name: set() for name in boxes}
full = set()
elapsed = 0
for i in range(gif.n_frames):
    gif.seek(i)
    frame = gif.convert("RGB")
    full.add(hashlib.sha256(frame.tobytes()).hexdigest())
    elapsed += gif.info.get("duration", 0)
    for name, box in boxes.items():
        hashes[name].add(hashlib.sha256(frame.crop(box).tobytes()).hexdigest())
counts = {name: len(values) for name, values in hashes.items()}
assert gif.size == (600, 1300)
assert gif.n_frames == 240 and len(full) == 240
assert elapsed == 12000 and gif.info.get("loop") == 0
assert counts["water"] == 240 and counts["hand"] > 100 and counts["noren"] > 100
assert all(counts[name] == 1 for name in ["noren_mount", "wall_below_noren", "paper_edge", "desk_edge"]), counts
timeline = json.loads((folder / "rank-2-tool-timeline-v3.json").read_text())
phases = []
for entry in timeline:
    if not phases or phases[-1]["action"] != entry["action"]:
        phases.append({"time": entry["time"], "action": entry["action"]})
order = [phase["action"] for phase in phases]
expected = ["put_brush_down", "release_brush", "reach_and_grasp_seal", "lift_seal", "press_seal", "put_seal_back", "grasp_brush", "lift_brush"]
indices = [order.index(name) for name in expected]
assert indices == sorted(indices)
assert all(not (entry["brushHeld"] and entry["sealHeld"]) for entry in timeline)
assert all(not entry["brushHeld"] for entry in timeline if 6.0 <= entry["time"] < 9.9)
assert all(not entry["sealHeld"] for entry in timeline if entry["time"] < 6.8 or entry["time"] >= 9.0)
result = {"frames": gif.n_frames, "unique_frames": len(full), "duration_ms": elapsed, "region_unique_frames": counts, "sequence": phases}
(folder / "rank-2-verification-v3.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(result, ensure_ascii=False))
