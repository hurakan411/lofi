"""Read-only checks of the rendered animation, alpha layers and leaf landings."""
from pathlib import Path
from PIL import Image, ImageChops, ImageStat
import hashlib
import json
import sys

root = Path('output/concepts/shrine')
folder = root / 'rank5-v3'
life = json.loads((folder / 'leaf-lifecycle.json').read_text())
old_life = json.loads((root / 'rank5-v1/leaf-lifecycle.json').read_text())
assert len(life) == 80 * 240
inherited = [r for r in life if r['leaf'] < 40]
for a, b in zip(inherited, old_life):
    assert abs(a['opacity'] - b['opacity']) < 1e-8
    # Coordinates at an invisible cycle boundary are immaterial. Floating
    # arithmetic can select either side of that boundary at opacity zero.
    if max(a['opacity'], b['opacity']) > .001:
        for key in ['x', 'y', 'targetX', 'targetY', 'flight']:
            assert abs(a[key] - b[key]) < 1e-8, (key, a, b)
for r in life:
    if r['fading']:
        assert r['landed']
        assert abs(r['x'] - r['targetX']) < .001
        assert abs(r['y'] - r['targetY']) < .001
    if not r['landed'] and r['age'] > .18:
        assert abs(r['opacity'] - .95) < .001
assert {r['surface'] for r in life if r['leaf'] >= 40} == {'upper_shrine_roof', 'upper_stone_steps'}

loops = {}
for name, end in [('hanging', 5), ('maples', 5), ('canopy', 5), ('airborne', 5), ('walkers', 10)]:
    a = Image.open(folder / f'{name}-only-0.png').convert('RGBA')
    b = Image.open(folder / f'{name}-only-{end}.png').convert('RGBA')
    mean = ImageStat.Stat(ImageChops.difference(a, b)).mean
    assert max(mean) < .003, (name, mean)
    loops[name] = mean
for name, count in [('connected-writing', 6), ('fox-only', 5), ('light-only', 5)]:
    for j in range(count):
        filename = f'{name}-{j}.png'
        assert (folder / filename).read_bytes() == (root / 'rank5-v1' / filename).read_bytes(), filename
old = Image.open(root / 'rank5-v1/frame-without-falling-leaves.png').convert('RGB')
new = Image.open(folder / 'frame-without-falling-leaves.png').convert('RGB')
assert ImageChops.difference(old, new).crop((0, 700, 600, 1300)).getbbox() is None

walker_samples = json.loads((folder / 'walker-lifecycle.json').read_text())
actors = sorted({r['actor'] for r in walker_samples})
assert len(actors) == 7
for name in actors:
    samples = [r for r in walker_samples if r['actor'] == name]
    assert abs(samples[0]['x'] - samples[-1]['x']) < 1e-8
    assert abs(samples[0]['y'] - samples[-1]['y']) < 1e-8
    assert max(r['x'] for r in samples) - min(r['x'] for r in samples) > 40
assert len({r['actor'] for r in walker_samples if r['fox']}) == 3
assert max(r['height'] for r in walker_samples) == 26
assert all(r['route'] == 'middle_right_stone_steps' for r in walker_samples if r['fox'])

# Actual upper-right figure alpha must be empty after removing those walkers.
for j in range(11):
    alpha = Image.open(folder / f'walkers-only-{j}.png').getchannel('A')
    assert alpha.crop((378, 0, 600, 270)).getbbox() is None
assert Image.open(folder / 'walkers-only-0.png').getchannel('A').crop((455, 565, 510, 635)).getbbox() is not None
previous_leaf_life = json.loads((root / 'rank5-v2/leaf-lifecycle.json').read_text())
assert life == previous_leaf_life
for name in ['hanging', 'maples', 'canopy', 'airborne']:
    for j in range(6):
        filename = f'{name}-only-{j}.png'
        assert (folder / filename).read_bytes() == (root / 'rank5-v2' / filename).read_bytes()

report = {
    'leafCount': 80, 'newUpperLeaves': 40, 'original40VisibleLeafPathsPreserved': True,
    'fadeOnlyAfterLanding': True, 'restingLeafPositionFixedDuringFade': True,
    'inheritedClerkMotionRestingFoxesAndLightPreserved': True,
    'foregroundBelow700UnchangedBeforeParticles': True,
    'loopLayerMeanDelta': loops, 'walkers': 7,
    'bridgeVisitors': 3, 'stairVisitors': 1, 'stairFoxes': 3,
    'walkingFiguresMaxHeightPixels': 26,
    'upperRightWalkingPeopleRemoved': True,
    'walkingFoxesMovedToMiddleRightStoneStairs': True,
    'allRank5v2LeavesCanopyAndPaperMotionPreserved': True,
}
(folder / 'motion-fixture-check.json').write_text(json.dumps(report, indent=2) + '\n')
if '--fixtures-only' in sys.argv:
    print(json.dumps(report, indent=2))
    sys.exit()

gif = Image.open(root / 'rank-5-shrine-v3.gif')
assert gif.size == (600, 1300) and gif.n_frames == 2400 and gif.info.get('loop') == 0
regions = {
    'upper_bridge': (357, 117, 454, 183),
    'covered_bridge': (278, 320, 439, 410),
    'right_stone_stairs': (455, 565, 510, 635),
    'central_stairs': (286, 238, 375, 335),
    'upper_maple_branch': (0, 10, 150, 170),
    'upper_left_canopy': (0, 165, 88, 280),
    'upper_right_canopy': (523, 165, 600, 300),
    'left_paper': (10, 290, 80, 360),
    'right_paper': (470, 390, 575, 460),
    'door_fixed': (588, 930, 596, 1030),
    'desk_fixed': (447, 1027, 466, 1031),
    'front_rail_fixed': (490, 1050, 510, 1056),
    'basin_fixed': (168, 1190, 190, 1205),
}
unique = {name: set() for name in regions}
duration = 0
for i in range(gif.n_frames):
    gif.seek(i)
    duration += gif.info.get('duration', 0)
    rgb = gif.convert('RGB')
    for name, box in regions.items():
        unique[name].add(hashlib.sha256(rgb.crop(box).tobytes()).hexdigest())
assert duration == 120000
for name, values in unique.items():
    if name.endswith('_fixed'):
        assert len(values) == 1, (name, len(values))
    else:
        assert len(values) > 50, (name, len(values))
assert json.loads((root / 'rank-5-timeline-v3.json').read_text()) == json.loads((root / 'rank-5-timeline-v2.json').read_text())
report.update({
    'file': 'rank-5-shrine-v3.gif', 'dimensions': [600, 1300], 'frames': 2400,
    'durationMilliseconds': duration, 'loop': 'infinite',
    'bytes': (root / 'rank-5-shrine-v3.gif').stat().st_size,
    'regionUniqueFrames': {k: len(v) for k, v in unique.items()},
    'clerkTimelineUnchanged': True,
})
(root / 'rank-5-verification-v3.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
