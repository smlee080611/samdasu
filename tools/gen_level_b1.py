# 지하 1층 기계실·발전기실 생성기 → amhwa2/scenes/floors/level_b1.tscn
# 실행: python3 tools/gen_level_b1.py   (다시 돌리면 씬을 통째로 새로 씀. 에디터에서 손본 게 있으면 사라지니 주의)
#
# 빛이 전혀 없는 층. 비상 유도등은 계단참 하나뿐이고 쉴 곳도 없다.
# 1층 상담실 자리의 "기계실 계단"으로 내려온다 (계단 짝 Side = "B").
# 발전기실(잠김, 직원 열쇠)에서 크랭크를 셋이 돌려 시동을 걸고, 차단기를 층별로 올리면 엔딩.
# 돌리는 동안 낡은 전구(Flickers)가 껌뻑이면서 이 층의 석상들이 광인으로 깨어나 발전기 소리 쪽으로 몰려온다.
import math, os
from collections import deque
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "amhwa2")
OUT = os.path.join(ROOT, "scenes", "floors", "level_b1.tscn")
W, H = 28, 15
g = [["#"] * W for _ in range(H)]
def carve(x0, x1, y0, y1, c="."):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1): g[y][x] = c
doors = []   # (x, y, 열림)
def door(x, y, op=False):
    g[y][x] = "."; doors.append((x, y, op))

carve(1, 26, 6, 6)                                   # 가운데 복도 하나
carve(1, 3, 1, 4); g[5][2] = "."                     # 계단실 (1층으로 올라가는 계단)
carve(5, 10, 1, 4); door(7, 5, True)                 # 보일러실 (문 열려 있음)
carve(12, 15, 1, 4); door(13, 5)                     # 자재 창고
carve(17, 21, 1, 4); door(19, 5, True)               # 시설과 사무실 (문 열려 있음)
carve(23, 26, 1, 4); door(24, 5)                     # 연구 구역 전실 (잠김)
carve(1, 6, 8, 13); door(3, 7, True)                 # 물탱크실 (문 열려 있음)
carve(8, 19, 8, 13); door(13, 7)                     # 발전기실 (잠김)
carve(21, 26, 8, 13); door(23, 7, True)              # 세탁실 (문 열려 있음)
ARRIVE = (2, 4)                                      # 계단으로 도착하는 칸이자 구한 사람이 올라가는 곳
LOCKED = {(13, 7), (24, 5)}
MAP = ["".join(r) for r in g]

def cen(t): return (t[0] * 2 + 1, t[1] * 2 + 1)
DIR_YAW = {(0, -1): 0, (0, 1): 180, (-1, 0): 90, (1, 0): -90}
props = []
blocked = set()
def put(kind, t, d, depth, along=0.0, y=0.0, block=False, extra=None, gap=0.02):
    cx, cz = cen(t)
    off = 1.0 - depth / 2 - gap
    side = (-d[1], d[0])
    x = cx + d[0] * off + side[0] * along
    z = cz + d[1] * off + side[1] * along
    props.append((kind, round(x, 3), y, round(z, 3), DIR_YAW[d], extra or {}))
    if block: blocked.add(t)
def put_at(kind, x, z, yaw, y=0.0, extra=None):
    props.append((kind, round(x, 3), y, round(z, 3), yaw, extra or {}))
def nav_block(t):
    put_at("nav_block", *cen(t), 0); blocked.add(t)

# ---------- 계단실: 1층으로 올라가는 계단 (1층 서쪽 계단과 같은 배치) ----------
put_at("stair_flight", 4, 6, 0)
for t in ((1, 1), (2, 1), (1, 2), (2, 2)): nav_block(t)
# ---------- 보일러실 ----------
put_at("boiler", 13.0, 4.2, 0); blocked.update({(6, 1), (6, 2)}); nav_block((5, 1))
put_at("boiler", 18.6, 4.2, 0); blocked.update({(9, 1), (9, 2)}); nav_block((8, 1))
put("shelf", (10, 4), (1, 0), 0.5, block=True)
# ---------- 자재 창고 ----------
for t, d in (((12, 1), (0, -1)), ((14, 1), (0, -1)), ((15, 3), (1, 0)), ((15, 4), (1, 0)), ((12, 3), (-1, 0))):
    put("shelf", t, d, 0.5, block=True)
# ---------- 시설과 사무실 ----------
put("desk", (17, 1), (0, -1), 0.65); put_at("chair", 17 * 2 + 1, 1 * 2 + 1 + 0.4, 10)
put("desk", (21, 1), (0, -1), 0.65)
put("locker", (17, 4), (-1, 0), 0.44); put("locker", (21, 3), (1, 0), 0.44)
put("bench", (21, 4), (1, 0), 0.5)
# ---------- 연구 구역 전실 ----------
put("desk", (26, 1), (0, -1), 0.65); put("shelf", (23, 1), (-1, 0), 0.5, block=True)
put("locker", (26, 4), (1, 0), 0.44); put("cart", (23, 4), (-1, 0), 0.5, block=True)
# ---------- 물탱크실 ----------
put_at("water_tank", 4.0, 19.0, 0); blocked.update({(1, 9), (2, 9)}); nav_block((1, 8)); nav_block((2, 8))
put_at("water_tank", 4.0, 25.2, 0); blocked.update({(1, 12), (2, 12)}); nav_block((1, 13)); nav_block((2, 13))
put("shelf", (6, 13), (1, 0), 0.5, block=True)
# ---------- 발전기실: 발전기는 방 가운데 (13~14, 10~11). 크랭크는 서쪽 면 ----------
GEN = (28.0, 22.0)
for t in ((13, 10), (14, 10), (13, 11), (14, 11)): nav_block(t)   # 발전기가 차지한 칸은 길찾기에서 뺀다
CRANK_TILES = [(12, 10), (12, 11), (11, 10)]          # 내려온 사람들이 서는 칸 (크랭크 옆)
put("shelf", (8, 13), (-1, 0), 0.5, block=True); put("cart", (19, 13), (1, 0), 0.5, block=True)
put("extinguisher", (8, 8), (-1, 0), 0.2)
BREAKERS = [((19, 9), -1), ((19, 10), 1), ((19, 11), 2)]   # 동쪽 벽: 지하 / 1층 / 2층
# ---------- 세탁실 ----------
for x in (22, 24, 26):
    put("washer", (x, 13), (0, 1), 1.0, block=True)
put("cart", (21, 9), (-1, 0), 0.5, block=True); put("cart", (26, 9), (1, 0), 0.5, block=True)
put("table", (24, 10), (0, 1), 0.75, gap=0.6, block=True)
put("shelf", (21, 11), (-1, 0), 0.5, block=True)
# ---------- 복도 ----------
put("extinguisher", (10, 6), (0, -1), 0.2); put("cart", (16, 6), (0, 1), 0.5, along=0.2)
put("wheelchair", (25, 6), (0, -1), 0.7, along=0.2)

# ---------- 껌뻑이는 전구 (발전기를 돌리는 동안만): 복도와 문이 열린 방 ----------
FLICKERS = [(4, 6), (10, 6), (16, 6), (22, 6), (8, 3), (19, 2), (4, 10), (23, 10), (10, 9), (17, 12)]

# ---------- 표지판 ----------
signs = []
def sign_on(t, d, text, width=0.5, y=2.5):
    cx, cz = cen(t)
    signs.append((text, round(cx + d[0] * 0.99, 3), y, round(cz + d[1] * 0.99, 3), DIR_YAW[d], width))
sign_on((7, 6), (0, -1), "보일러실", 0.7, y=2.55); sign_on((13, 6), (0, -1), "자재 창고", 0.8, y=2.55)
sign_on((19, 6), (0, -1), "시설과", 0.6, y=2.55); sign_on((24, 6), (0, -1), "연구 구역\n관계자 외 출입 금지", 1.1, y=2.5)
sign_on((3, 6), (0, 1), "물탱크실", 0.7); sign_on((13, 6), (0, 1), "비상발전기실", 1.0); sign_on((23, 6), (0, 1), "세탁실", 0.6)
signs.append(("계단  1F ↑", 5.0, 2.6, 11.95, 0, 1.0))
sign_on((19, 8), (1, 0), "층별 차단기\n한 번에 하나씩", 0.9, y=2.1)
sign_on((12, 8), (0, -1), "수동 시동: 3인 이상", 1.0, y=2.1)

# ---------- 사람 ----------
NAMES = iter("곽동식 변순덕 지창호 설미자 모영수 천복희 방기철 여춘자 석대현 선우정 편성태 옥진숙".split())
people = []
def person(t, role="환자"):
    people.append((t, f"{role} {next(NAMES)}"))
person((18, 3), "시설 기사")                  # 시설과 사무실: 발전기실 열쇠를 가진 사람
person((7, 3), "시설 기사"); person((10, 2))   # 보일러실
person((14, 3), "경비")                        # 자재 창고
person((24, 2), "연구원"); person((25, 3), "연구원")   # 연구 구역 전실
person((4, 9)); person((5, 12))                # 물탱크실
person((22, 10), "보호자"); person((25, 11)); person((23, 12))   # 세탁실
person((15, 6))                                # 복도
GIFTS = {(18, 3): "key", (7, 3): "bandage", (14, 3): "key"}
LIGHTS = [(3, 3)]   # 계단참의 초록 비상 유도등 하나

# ---------- 뒤질 곳 ----------
FIXED_LOOT = {("desk", (21, 1)): "battery", ("shelf", (14, 1)): "battery", ("shelf", (12, 3)): "chem",
              ("cart", (26, 9)): "bandage", ("locker", (26, 4)): "chem"}
def _tile_of(x, z): return (int(x // 2), int(z // 2))
for i, (kind, x, y, z, yaw, extra) in enumerate(props):
    if kind not in ("locker", "desk", "shelf", "cart"):
        continue
    extra = dict(extra); extra["loot"] = '"%s"' % FIXED_LOOT.get((kind, _tile_of(x, z)), "empty")
    props[i] = (kind, x, y, z, yaw, extra)
assert sum(1 for p in props if p[5].get("loot") == '"battery"') == 2, "예비 배터리는 2곳"

NOTES = [
 ("발전기 점검 일지 — 시설과", "10/28  수동 크랭크 시동 시험: 정상.\n       셋이 붙어야 겨우 돌아감. 둘로는 압축을 못 넘김.\n\n10/30  자동 기동 릴레이 고장. 부품 주문함.\n       그때까지 정전이 나면 손으로 돌려야 함.\n\n11/1   지하 연구 구역에서 전기를 너무 끌어 씀.\n       차단기가 자꾸 떨어짐. 층별로 하나씩 올릴 것.", (35.3, 0.775, 2.4)),
 ("연구 메모 A-14", "빛이 약하거나 끊기면 몸만 풀리고 정신은 돌아오지 않는다.\n가장 위험한 상태.\n\n지하 조명은 낡아서 전압이 흔들리면 껌뻑인다.\n발전기를 돌리는 동안이 가장 위험할 것.\n\n한 번 제대로 켜지기만 하면, 다 끝난다.", (53.2, 0.775, 2.4)),
 ("벽에 긁어 쓴 글씨", "돌리다가\n손이\n\n", (22.6, 0.01, 20.6)),
]
# ---------- 검사 ----------
floor = {(x, y) for y in range(H) for x in range(W) if g[y][x] == "."}
door_tiles = {(x, y) for x, y, _ in doors}
def reach(start, bad):
    seen = {start}; q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in floor and n not in bad and n not in seen:
                seen.add(n); q.append(n)
    return seen
r = reach(ARRIVE, blocked)
lost = floor - blocked - r
assert not lost, f"가구 때문에 못 가는 칸: {sorted(lost)}"
for t in CRANK_TILES: assert t in r, ("크랭크 칸에 못 감", t)
for t, n in people:
    assert t in floor and t not in blocked and t not in door_tiles, (t, n)
    for L in LIGHTS:
        assert math.dist(t, L) > 3.0, ("비상등 너무 가까움", t, n)
assert len({p[0] for p in people}) == len(people)
assert all(t in {p[0] for p in people} for t in GIFTS)
assert all(t in door_tiles for t in LOCKED)

# ---------- tscn 쓰기 ----------
KINDS = sorted({p[0] for p in props} | {"note", "sign"})
def T(x, y, z, yaw):
    c, s = round(math.cos(math.radians(yaw)), 5), round(math.sin(math.radians(yaw)), 5)
    return f"Transform3D({c}, 0, {s}, 0, 1, 0, {-s}, 0, {c}, {x}, {y}, {z})"
o = ['[gd_scene format=3]\n']
o.append('[ext_resource type="Script" path="res://scripts/objects/level.gd" id="level"]')
o.append('[ext_resource type="Script" path="res://scripts/objects/flicker_light.gd" id="flicker"]')
for i, p in (("person", "person"), ("door", "door"), ("elight", "emergency_light"), ("stairs", "stairs"), ("generator", "generator"), ("breaker", "breaker")):
    o.append(f'[ext_resource type="PackedScene" path="res://scenes/{p}.tscn" id="{i}"]')
for t in ("wall", "floor", "ceiling"):
    o.append(f'[ext_resource type="Texture2D" path="res://textures/{t}.png" id="t_{t}"]')
for k in KINDS:
    o.append(f'[ext_resource type="PackedScene" path="res://scenes/props/{k}.tscn" id="p_{k}"]')
o.append("")
# 지하는 콘크리트라 벽·바닥을 어둡고 누렇게 물들인다 (같은 텍스처, 색만 다름)
for mid, tex, rough, col in (("wall", "wall", 0.95, "0.62, 0.6, 0.55"), ("floor", "floor", 0.85, "0.5, 0.5, 0.48"), ("ceil", "ceiling", 1.0, "0.5, 0.5, 0.5")):
    o.append(f'[sub_resource type="StandardMaterial3D" id="{mid}"]\nalbedo_color = Color({col}, 1)\nalbedo_texture = ExtResource("t_{tex}")\nroughness = {rough}\ncull_mode = 2\ntexture_filter = 4\n')
o.append('[node name="LevelB1" type="Node3D"]\nscript = ExtResource("level")\nwall_map = "' + "\n".join(MAP) +
         '"\nfloor_no = -1\nentrance_tile = Vector2i(-1, -1)\nexit_floor = 1\n'
         'arrive_thought = "기름 냄새가 난다. 여기는 빛이라곤 없다."\n'
         'hall_reserve = 0.0\nstatue_grab_ratio = 0.4\nwall_material = SubResource("wall")\nfloor_material = SubResource("floor")\nceiling_material = SubResource("ceil")\n')
for grp in ("People", "Doors", "Lights", "Flickers", "Machines", "Props", "Signs", "Notes"):
    o.append(f'[node name="{grp}" type="Node3D" parent="."]\n')
for t, n in people:
    x, z = cen(t)
    gift = f'gift = "{GIFTS[t]}"\n' if t in GIFTS else ""
    o.append(f'[node name="{n.replace(" ", "_")}" parent="People" instance=ExtResource("person")]\ntransform = {T(x, 0, z, 0)}\nperson_name = "{n}"\n{gift}')
for x, y, op in doors:
    cx, cz = cen((x, y))
    room_north = y == 5
    o.append(f'[node name="문_{x}_{y}" parent="Doors" instance=ExtResource("door")]\ntransform = {T(cx, 0, cz, 180 if room_north else 0)}' + ("\nopen = true\n" if op else ("\nlocked = true\n" if (x, y) in LOCKED else "\n")))
for i, t in enumerate(LIGHTS):
    cx, cz = cen(t)
    o.append(f'[node name="비상등_{i}" parent="Lights" instance=ExtResource("elight")]\ntransform = {T(cx, 2.7, cz, 0)}\n')
for i, t in enumerate(FLICKERS):
    cx, cz = cen(t)
    o.append(f'[node name="전구_{i}" type="Node3D" parent="Flickers"]\ntransform = {T(cx, 2.55, cz, 0)}\nscript = ExtResource("flicker")\n')
tiles = ", ".join(f"Vector2i({a}, {b})" for a, b in CRANK_TILES)
o.append(f'[node name="발전기" parent="Machines" instance=ExtResource("generator")]\ntransform = {T(GEN[0], 0, GEN[1], 0)}\ncrank_tiles = Array[Vector2i]([{tiles}])\n')
for t, fl in BREAKERS:
    cx, cz = cen(t)
    name = {-1: "차단기_B1", 1: "차단기_1F", 2: "차단기_2F"}[fl]
    o.append(f'[node name="{name}" parent="Machines" instance=ExtResource("breaker")]\ntransform = {T(cx + 0.99, 0, cz, -90)}\nfloor_no = {fl}\n')
o.append(f'[node name="StairsB" parent="." instance=ExtResource("stairs")]\ntransform = {T(4, 0, 6.6, 0)}\nside = "B"\nto_floor = 1\narrive_tile = Vector2i({ARRIVE[0]}, {ARRIVE[1]})\n')
cnt = {}
for kind, x, y, z, yaw, extra in props:
    cnt[kind] = cnt.get(kind, 0) + 1
    ex = "".join(f"\n{k} = {v}" for k, v in extra.items())
    o.append(f'[node name="{kind}_{cnt[kind]}" parent="Props" instance=ExtResource("p_{kind}")]\ntransform = {T(x, y, z, yaw)}{ex}\n')
for i, (text, x, y, z, yaw, w) in enumerate(signs):
    tt = text.replace("\n", "\\n")
    o.append(f'[node name="표지판_{i}" parent="Signs" instance=ExtResource("p_sign")]\ntransform = {T(x, y, z, yaw)}\ntext = "{tt}"\nwidth = {w}\n')
for i, (title, body, (x, y, z)) in enumerate(NOTES):
    b = body.replace("\\", "\\\\").replace('"', '\\"')
    o.append(f'[node name="쪽지_{i}" parent="Notes" instance=ExtResource("p_note")]\ntransform = {T(round(x, 3), y, round(z, 3), 20 * i)}\ntitle = "{title}"\nbody = "{b}"\n')
open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(o))
grid = [list(r) for r in MAP]
for t in blocked: grid[t[1]][t[0]] = "b"
for t, n in people: grid[t[1]][t[0]] = "S"
for x, y, op in doors: grid[y][x] = "L" if (x, y) in LOCKED else ("d" if op else "D")
for t in CRANK_TILES: grid[t[1]][t[0]] = "c"
grid[ARRIVE[1]][ARRIVE[0]] = "E"
print("\n".join("".join(r) for r in grid)); print(cnt, "people", len(people))
