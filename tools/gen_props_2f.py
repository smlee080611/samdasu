# 2층(수술·중환자동) 소품: 수술대, 환자 감시 모니터, 마취기, 내려가는 계단, 수술등 배터리함
# 실행: python3 tools/gen_props_2f.py  →  amhwa2/scenes/props/*.tscn
import os
from props_common import Scene, T, prop, D

# 수술대 (길이 방향 = z, 가운데 기둥 하나로 받침). 길을 막음
s = prop("OpTable", True)
metal = s.mat("metal", (0.5, 0.52, 0.53), 0.35, 0.6)
pad = s.mat("pad", (0.18, 0.3, 0.28), 0.8)
sheet = s.mat("sheet", (0.42, 0.55, 0.5), 0.95)
s.box("Base", metal, (0.5, 0.06, 0.8), (0, 0.03, 0))
s.cyl("Column", metal, 0.12, 0.14, 0.78, (0, 0.45, 0), seg=10)
s.box("Frame", metal, (0.56, 0.05, 1.95), (0, 0.86, 0))
s.box("Pad", pad, (0.52, 0.08, 1.9), (0, 0.925, 0))
s.box("Drape", sheet, (0.7, 0.02, 1.3), (0, 0.975, 0.25), rot=("x", 1))
s.box("ArmBoard", pad, (0.7, 0.04, 0.14), (0.5, 0.92, -0.35))
s.collider((0.6, 1.0, 1.95), (0, 0.5, 0))
s.save(f"{D}/op_table.tscn")

# 환자 감시 모니터 (바퀴 달린 받침대 + 1999년식 상자 모니터). 길을 막지 않음
s = prop("Monitor", False)
pole = s.mat("pole", (0.6, 0.62, 0.63), 0.4, 0.5)
case = s.mat("case", (0.78, 0.77, 0.72), 0.6)
scr = s.mat("screen", (0.03, 0.05, 0.04), 0.2)
for i in range(5):
    import math
    a = math.radians(72 * i)
    s.box(f"Foot{i}", pole, (0.03, 0.03, 0.3), (round(0.13 * math.sin(a), 3), 0.04, round(0.13 * math.cos(a), 3)), rot=("y", 72 * i))
s.cyl("Pole", pole, 0.018, 0.018, 1.2, (0, 0.62, 0), seg=6)
s.box("Case", case, (0.36, 0.3, 0.3), (0, 1.35, 0))
s.box("Screen", scr, (0.28, 0.2, 0.01), (0, 1.37, 0.155))
s.box("Cable", s.mat("cable", (0.1, 0.1, 0.1), 0.9), (0.02, 0.6, 0.02), (0.15, 0.95, -0.1), rot=("z", 25))
s.collider((0.36, 0.3, 0.3), (0, 1.35, 0))
s.save(f"{D}/monitor.tscn")

# 마취기 (가스통 둘 달린 키 큰 카트). 길을 막음
s = prop("Anesthesia", True)
body = s.mat("body", (0.62, 0.66, 0.64), 0.6, 0.2)
top = s.mat("top", (0.75, 0.75, 0.72), 0.5)
o2 = s.mat("o2", (0.25, 0.45, 0.3), 0.5, 0.3)
n2o = s.mat("n2o", (0.2, 0.3, 0.55), 0.5, 0.3)
s.box("Body", body, (0.7, 1.1, 0.55), (0, 0.6, 0))
s.box("Shelf", top, (0.74, 0.03, 0.58), (0, 1.17, 0))
s.box("Panel", s.mat("panel", (0.1, 0.11, 0.1), 0.3), (0.5, 0.35, 0.04), (0, 1.45, -0.1))
s.cyl("Bag", s.mat("bag", (0.15, 0.15, 0.15), 0.9), 0.06, 0.07, 0.18, (0.3, 1.05, 0.3), rot=("x", 90))
s.cyl("TankA", o2, 0.07, 0.07, 0.75, (-0.28, 0.45, -0.32), seg=8)
s.cyl("TankB", n2o, 0.07, 0.07, 0.75, (-0.1, 0.45, -0.32), seg=8)
s.collider((0.74, 1.6, 0.6), (0, 0.8, 0))
s.save(f"{D}/anesthesia.tscn")

# 내려가는 계단 (4m 동안 3m 내려감, 북쪽(-z)으로 내려감). 원점 = 계단 맨 위 앞 가장자리 가운데 (바닥 높이)
# 바닥에 뚫린 계단 구멍 안쪽에 계단·옆벽·바닥을 그린다. 구멍 둘레는 난간과 보이지 않는 벽(문 틈 레이어 16)으로 막는다.
# 레이어 16은 플레이어만 막고 빛은 통과시킨다 (구멍 위로 빛이 지나가야 하니까)
s = Scene("StaticBody3D", "StairDown", "collision_layer = 16\ncollision_mask = 0\n")
step = s.mat("step", (0.55, 0.54, 0.5), 0.9)
nose = s.mat("nose", (0.3, 0.3, 0.3), 0.6, 0.3)
wall = s.mat("wall", (0.36, 0.37, 0.35), 0.95)
rail = s.mat("rail", (0.5, 0.52, 0.53), 0.4, 0.6)
dark = s.mat("dark", (0.0, 0.0, 0.0), 1.0)
for i in range(8):
    top_y = round(-0.375 * (i + 1), 3); z = round(-0.25 - 0.5 * i, 3)
    h = round(3.3 + top_y, 3)
    s.box(f"Step{i}", step, (3.8, h, 0.5), (0, round(top_y - h / 2, 3), z))
    s.box(f"Nose{i}", nose, (3.8, 0.03, 0.06), (0, round(top_y + 0.01, 3), round(z + 0.22, 3)))
for side in (-1, 1):
    s.box(f"Side{side}", wall, (0.04, 3.3, 4.0), (side * 1.92, -1.65, -2.0))
s.box("Back", dark, (3.8, 3.3, 0.04), (0, -1.65, -4.0))
s.box("Bottom", dark, (3.8, 0.02, 4.0), (0, -3.3, -2.0))
s.box("FrontLip", wall, (3.8, 0.4, 0.04), (0, -0.2, 0.0))
# 동쪽(+x) 난간: 계단참 쪽으로 열려 있어서 떨어지지 않게
for i, z in enumerate((-0.1, -1.4, -2.7, -3.9)):
    s.box(f"Post{i}", rail, (0.04, 1.0, 0.04), (1.85, 0.5, z))
s.box("Rail", rail, (0.05, 0.05, 3.9), (1.85, 1.0, -2.0))
s.box("Rail2", rail, (0.03, 0.03, 3.9), (1.85, 0.55, -2.0))
s.collider((3.8, 1.2, 4.0), (0, 0.6, -2.0))
s.save(f"{D}/stair_down.tscn")

# 수술등·중환자실 천장등의 비상 배터리함 (벽에 붙음, 앞면 +z). 등 자체는 surgical_light.gd가 fixtures 위치에 만든다
s = Scene("StaticBody3D", "SurgicalLight", "collision_layer = 4\ncollision_mask = 0\n")
scr_ = s.ext_res("Script", "res://scripts/objects/surgical_light.gd")
s.root += f'script = ExtResource("{scr_}")\n'
case = s.mat("case", (0.62, 0.64, 0.6), 0.6, 0.2)
lid = s.mat("lid", (0.45, 0.47, 0.45), 0.5, 0.3)
slot = s.mat("slot", (0.05, 0.05, 0.05), 0.9)
s.box("Case", case, (0.42, 0.55, 0.12), (0, 1.3, 0.06))
s.box("Lid", lid, (0.36, 0.2, 0.01), (0, 1.38, 0.125))
for i in range(4):
    s.box(f"Slot{i}", slot, (0.06, 0.12, 0.01), (round(-0.12 + 0.08 * i, 3), 1.17, 0.125))
s.box("Conduit", lid, (0.05, 1.4, 0.05), (0.15, 2.3, 0.03))
s.node("Led", "MeshInstance3D", ".", transform=T(0.15, 1.5, 0.125), mesh=f'SubResource("{s.mesh("BoxMesh", lid, size=(0.03, 0.03, 0.01))}")')
s.node("Label", "Label3D", ".", transform=T(0, 1.65, 0.07), text='"무영등 비상전원"', font_size="32", pixel_size="0.0019",
       modulate="Color(0.85, 0.85, 0.8, 1)", outline_size="0", double_sided="false", font='ExtResource("' + s.ext_res("FontFile", "res://fonts/Pretendard-Regular.otf") + '")')
s.collider((0.5, 0.65, 0.2), (0, 1.3, 0.08))
s.save(os.path.join(os.path.dirname(D), "surgical_light.tscn"))
print("2F props written")
