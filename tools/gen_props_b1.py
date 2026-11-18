# 지하 1층(기계실·발전기실) 소품: 비상발전기, 차단기, 보일러, 물탱크, 세탁기
# 실행: python3 tools/gen_props_b1.py  →  amhwa2/scenes/props/*.tscn, amhwa2/scenes/generator.tscn, breaker.tscn
import os, math
from props_common import Scene, T, prop, D
S = os.path.dirname(D)

# ---------- 비상발전기 (2칸 × 2칸을 차지하는 디젤 발전기. 서쪽(-x) 면에 수동 크랭크) ----------
# 원점 = 바닥 가운데. generator.gd가 Crank 노드를 돌린다
s = Scene("StaticBody3D", "Generator", "collision_layer = 5\ncollision_mask = 0\n")
scr = s.ext_res("Script", "res://scripts/objects/generator.gd")
s.root += f'script = ExtResource("{scr}")\n'
body = s.mat("body", (0.28, 0.36, 0.3), 0.7, 0.3)
dark = s.mat("dark", (0.1, 0.1, 0.1), 0.8, 0.2)
metal = s.mat("metal", (0.5, 0.5, 0.48), 0.4, 0.7)
warn = s.mat("warn", (0.8, 0.65, 0.1), 0.7)
s.box("Skid", dark, (3.3, 0.2, 2.2), (0, 0.1, 0))
s.box("Engine", body, (1.7, 1.3, 1.5), (-0.6, 0.85, 0))
s.box("Alternator", body, (1.2, 1.1, 1.3), (0.95, 0.75, 0))
s.box("Tank", dark, (0.9, 0.5, 2.0), (0.9, 1.6, 0))
s.box("Panel", metal, (0.5, 0.6, 0.06), (0.95, 1.0, 0.68))
s.box("Stripe", warn, (3.3, 0.08, 0.04), (0, 0.24, 1.1))
s.cyl("Exhaust", metal, 0.09, 0.09, 1.9, (-0.6, 2.4, -0.4), seg=8)
s.cyl("Muffler", dark, 0.2, 0.2, 0.8, (-0.6, 1.75, -0.4), seg=8, rot=("x", 90))
s.cyl("Flywheel", metal, 0.5, 0.5, 0.14, (-1.52, 0.85, 0), seg=14, rot=("z", 90))
# 크랭크: 플라이휠 축에 꽂는 긴 손잡이. 여럿이 잡게 양쪽으로 길다
s.node("Crank", "Node3D", ".", transform=T(-1.62, 0.85, 0))
s.box("Arm", metal, (0.05, 0.05, 1.5), (0, 0, 0), parent="Crank")
s.box("GripA", dark, (0.5, 0.06, 0.06), (-0.25, 0, 0.72), parent="Crank")
s.box("GripB", dark, (0.5, 0.06, 0.06), (-0.25, 0, -0.72), parent="Crank")
s.collider((3.3, 1.9, 2.2), (0, 0.95, 0))
s.save(f"{S}/generator.tscn")

# ---------- 층별 차단기 (벽에 붙는 상자, 앞면 +z). breaker.gd가 Lever와 Led를 움직인다 ----------
s = Scene("StaticBody3D", "Breaker", "collision_layer = 4\ncollision_mask = 0\n")
scr = s.ext_res("Script", "res://scripts/objects/breaker.gd")
s.root += f'script = ExtResource("{scr}")\n'
case = s.mat("case", (0.55, 0.57, 0.55), 0.6, 0.3)
lev = s.mat("lever", (0.08, 0.08, 0.08), 0.6)
s.box("Case", case, (0.36, 0.5, 0.12), (0, 1.35, 0.06))
s.node("Lever", "Node3D", ".", transform=T(0, 1.32, 0.13))
s.box("Handle", lev, (0.06, 0.2, 0.05), (0, -0.08, 0.02), parent="Lever")
s.node("Led", "MeshInstance3D", ".", transform=T(0, 1.52, 0.125), mesh=f'SubResource("{s.mesh("BoxMesh", case, size=(0.05, 0.04, 0.01))}")')
s.node("Label", "Label3D", ".", transform=T(0, 1.72, 0.07), text='"1F"', font_size="64", pixel_size="0.002",
       modulate="Color(0.9, 0.9, 0.85, 1)", outline_size="0", double_sided="false",
       font='ExtResource("' + s.ext_res("FontFile", "res://fonts/Pretendard-Regular.otf") + '")')
s.collider((0.44, 0.6, 0.2), (0, 1.35, 0.08))
s.save(f"{S}/breaker.tscn")

# ---------- 보일러 (세로 원통 + 배관). 길을 막음 ----------
s = prop("Boiler", True)
rust = s.mat("rust", (0.4, 0.27, 0.2), 0.9, 0.2)
pipe = s.mat("pipe", (0.45, 0.46, 0.45), 0.5, 0.6)
s.cyl("Body", rust, 0.75, 0.75, 2.1, (0, 1.15, 0), seg=12)
s.cyl("Cap", pipe, 0.5, 0.75, 0.25, (0, 2.3, 0), seg=12)
s.box("Door", s.mat("door", (0.12, 0.12, 0.12), 0.8), (0.5, 0.4, 0.06), (0, 0.6, 0.76))
s.cyl("PipeA", pipe, 0.07, 0.07, 1.0, (0.5, 2.5, 0), seg=6)
s.cyl("PipeB", pipe, 0.07, 0.07, 1.6, (-0.3, 2.0, -0.6), seg=6, rot=("x", 90))
s.collider((1.5, 2.4, 1.5), (0, 1.2, 0))
s.save(f"{D}/boiler.tscn")

# ---------- 물탱크 (누운 큰 원통, 받침대). 길을 막음 ----------
s = prop("WaterTank", True)
tank = s.mat("tank", (0.3, 0.38, 0.45), 0.6, 0.4)
leg = s.mat("leg", (0.2, 0.2, 0.2), 0.8)
s.cyl("Tank", tank, 0.8, 0.8, 1.8, (0, 1.15, 0), seg=12, rot=("x", 90))
for i, z in enumerate((-0.6, 0.6)):
    s.box(f"Saddle{i}", leg, (1.4, 0.4, 0.15), (0, 0.2, z))
s.cyl("Valve", s.mat("valve", (0.7, 0.15, 0.1), 0.6), 0.12, 0.12, 0.04, (0, 1.15, 0.93), seg=8, rot=("x", 90))
s.collider((1.6, 2.0, 1.8), (0, 1.0, 0))
s.save(f"{D}/water_tank.tscn")

# ---------- 업소용 세탁기 (앞면 +z에 둥근 문). 길을 막음 ----------
s = prop("Washer", True)
white = s.mat("white", (0.72, 0.73, 0.7), 0.5, 0.2)
glass = s.mat("glass", (0.05, 0.07, 0.08), 0.2, 0.3)
s.box("Body", white, (1.1, 1.4, 1.0), (0, 0.7, 0))
s.cyl("Door", glass, 0.36, 0.36, 0.05, (0, 0.75, 0.51), seg=14, rot=("x", 90))
s.box("Top", s.mat("top", (0.3, 0.3, 0.3), 0.6), (1.0, 0.12, 0.05), (0, 1.3, 0.5))
s.collider((1.1, 1.4, 1.0), (0, 0.7, 0))
s.save(f"{D}/washer.tscn")
print("B1 props written")
