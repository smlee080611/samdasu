# 2층 수술·중환자동 생성기 → amhwa2/scenes/floors/level_2f.tscn
# 실행: python3 tools/gen_level_2f.py   (다시 돌리면 level_2f.tscn을 통째로 새로 씀. 에디터에서 손본 게 있으면 사라지니 주의)
#
# 1층과 같은 골격(가운데 엘리베이터 홀·막힌 중앙 계단, 양 끝 비상계단, 남북 복도 두 줄)을 그대로 쌓았다.
# 다른 점:
#  - 창이 하나도 없다. 달빛도 마당도 없다. 비상 유도등은 계단에만.
#  - 엘리베이터 홀에서 쉴 수 없다 (엘리베이터는 1층에 멈춰 있음). 쉴 곳은 랜턴 곁, 켜 둔 수술등 아래뿐.
#  - 수술실 두 곳과 중환자실 두 곳에 수술등·천장등이 있다. 배터리함에 헤드램프 배터리를 옮겨 꽂으면 켜진다.
#  - 구한 사람은 가까운 비상계단으로 내려가 1층 현관 밖까지 걸어간다.
import math, os
from collections import deque
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "amhwa2")
OUT = os.path.join(ROOT, "scenes", "floors", "level_2f.tscn")
W, H = 38, 19
g = [["#"] * W for _ in range(H)]
def carve(x0, x1, y0, y1, c="."):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1): g[y][x] = c
doors = []   # (x, y, 열림)
def door(x, y, op=False):
    g[y][x] = "."; doors.append((x, y, op))

carve(1, 36, 6, 6); carve(1, 36, 12, 12)            # 북쪽·남쪽 복도
carve(1, 3, 6, 12); carve(35, 36, 6, 12)            # 양 끝 연결 복도
# ---- 북쪽 ----
carve(1, 3, 1, 4); g[5][2] = "."                     # 서쪽 비상계단
carve(1, 2, 1, 2, "v")                               # 1층으로 내려가는 계단 구멍
carve(5, 9, 1, 4); door(7, 5, True)                  # 제1수술실 (응급 수술 중이던 곳, 문이 열려 있음)
carve(11, 15, 1, 4); door(13, 5)                     # 회복실
carve(17, 21, 1, 5)                                  # 엘리베이터 홀 + 중앙 계단(막힘)
carve(23, 27, 1, 4); door(25, 5)                     # 제2수술실
carve(29, 33, 1, 4); door(31, 5)                     # 마취·준비실
carve(35, 36, 1, 4); g[5][36] = "."                  # 동쪽 비상계단
carve(35, 36, 1, 2, "v")
# ---- 가운데 ----
carve(5, 7, 8, 10); door(6, 7, True)                 # 스크럽실 (손 씻는 곳)
carve(9, 11, 8, 10); door(10, 11)                    # 멸균물품실
carve(13, 15, 8, 10); door(14, 7)                    # 탈의실
carve(17, 21, 8, 10); carve(18, 20, 7, 7)            # 중환자실 간호 스테이션 (홀을 마주 봄)
carve(23, 25, 8, 10); door(24, 11)                   # 혈액·약품 냉장실
carve(27, 29, 8, 10); door(28, 7)                    # 당직의사실
carve(31, 33, 8, 10); door(32, 11)                   # 장비 창고
# ---- 남쪽 ----
carve(1, 3, 14, 17); door(2, 13)                     # 오물실
carve(5, 15, 14, 17); door(10, 13)                   # 제1중환자실
carve(17, 21, 14, 17); carve(18, 20, 13, 13)         # 보호자 대기실 (남쪽 복도에서 트임)
carve(23, 33, 14, 17); door(28, 13)                  # 제2중환자실
carve(35, 36, 14, 17); door(35, 13)                  # 린넨실
EXIT_W = (2, 4)    # 서쪽 계단참: 계단으로 도착하는 칸이자 구한 사람이 내려가는 곳 (Level.exit_floor = 1이 계단에서 찾음)
EXIT_E = (36, 4)   # 동쪽 계단참
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

# ---------- 비상계단 ----------
put_at("stair_down", 4, 6, 0)
put_at("stair_down", 72, 6, 0)
put("cart", (3, 1), (0, -1), 0.5, block=True)          # 3층으로 가는 계단 자리: 카트로 막아 둠 (3층 이상 통제)
put("wheelchair", (3, 2), (1, 0), 0.7)
# ---------- 엘리베이터 홀 (1층과 같은 자리) ----------
put("elevator", (17, 1), (0, -1), 0.0, gap=0.0); put("elevator", (18, 1), (0, -1), 0.0, gap=0.0)
put_at("stair_flight", 42, 6, 0)
for t in ((20, 1), (21, 1), (20, 2), (21, 2)): nav_block(t)
put_at("barricade", 42, 7.0, 0); blocked.add((20, 3)); nav_block((21, 3))
put("wheelchair", (17, 4), (-1, 0), 0.7, along=0.3)
put("bed", (21, 4), (1, 0), 1.85, block=True)                     # 이송 침대가 홀에 멈춰 있음
# ---------- 제1수술실 (5~9, 1~4): 수술대는 7열 가운데 ----------
put_at("op_table", 15, 6, 0); blocked.update({(7, 2), (7, 3)})
put("anesthesia", (7, 1), (0, -1), 0.6, block=True)
put("monitor", (6, 1), (0, -1), 0.4)
put("cart", (9, 1), (1, 0), 0.5, block=True)
put("cart", (5, 4), (-1, 0), 0.5, block=True)
put("shelf", (5, 1), (-1, 0), 0.5, block=True)
put("iv_stand", (8, 1), (0, -1), 0.3)
# ---------- 회복실 (11~15, 1~4): 침대 넷, 북쪽 벽 ----------
for x in (11, 13, 15):
    put("bed", (x, 1), (0, -1), 1.85, block=True)
    put("monitor", (x, 2), (1, 0) if x < 15 else (-1, 0), 0.4, along=-0.5)
put_at("bed_curtain", 26, 3, 90); put_at("bed_curtain", 30, 3, 90)   # 침대 사이 커튼 (레일이 남북 방향)
put("cart", (11, 4), (-1, 0), 0.5, block=True)
# ---------- 제2수술실 (23~27, 1~4): 수술대는 25열 ----------
put_at("op_table", 51, 6, 0); blocked.update({(25, 2), (25, 3)})
put("anesthesia", (25, 1), (0, -1), 0.6, block=True)
put("monitor", (24, 1), (0, -1), 0.4)
put("cart", (27, 1), (1, 0), 0.5, block=True)
put("shelf", (27, 4), (1, 0), 0.5, block=True)
put("iv_stand", (26, 1), (0, -1), 0.3)
# ---------- 마취·준비실 (29~33, 1~4) ----------
put("anesthesia", (29, 1), (0, -1), 0.6, block=True)
put("anesthesia", (30, 1), (0, -1), 0.6, block=True)
put("shelf", (33, 1), (1, 0), 0.5, block=True); put("shelf", (33, 2), (1, 0), 0.5, block=True)
put("cart", (29, 4), (-1, 0), 0.5, block=True)
put("bed", (32, 4), (0, 1), 1.85, block=True)
# ---------- 가운데 구역 ----------
for x in (5, 6, 7): put("sink", (x, 8), (0, -1), 0.45)                      # 스크럽실
put("shelf", (5, 10), (-1, 0), 0.5, block=True)
for t, d in (((9, 8), (0, -1)), ((11, 8), (0, -1)), ((9, 9), (-1, 0)), ((11, 9), (1, 0)), ((11, 10), (1, 0))):   # 멸균물품실
    put("shelf", t, d, 0.5, block=True)
for x in (13, 14, 15): put("locker", (x, 10), (0, 1), 0.44)                 # 탈의실
put("locker", (13, 9), (-1, 0), 0.44); put("bench", (15, 8), (1, 0), 0.5)
for x in (18, 20):                                                            # 스테이션 카운터
    put_at("counter", x * 2 + 1, 8 * 2 + 1 - 0.55, 180); blocked.add((x, 8))
put("desk", (17, 10), (0, 1), 0.65); put("desk", (21, 10), (0, 1), 0.65)
put_at("chair", 17 * 2 + 1.2, 10 * 2 + 1 - 0.1, 200)
put("shelf", (21, 8), (1, 0), 0.5, block=True)
put("monitor", (19, 10), (0, 1), 0.4)                                         # 중앙 감시 모니터
for t, d in (((23, 8), (0, -1)), ((25, 8), (0, -1)), ((23, 9), (-1, 0)), ((25, 9), (1, 0))):   # 혈액·약품 냉장실
    put("shelf", t, d, 0.5, block=True)
put("bed", (27, 8), (-1, 0), 1.85, block=True); put("desk", (29, 10), (0, 1), 0.65)   # 당직의사실
put_at("chair", 29 * 2 + 1, 10 * 2 + 1 - 0.2, 160); put("locker", (29, 8), (1, 0), 0.44)
for t, d in (((31, 8), (0, -1)), ((33, 8), (0, -1)), ((33, 10), (1, 0))):     # 장비 창고
    put("shelf", t, d, 0.5, block=True)
put("wheelchair", (31, 10), (0, 1), 0.7); put("monitor", (33, 9), (1, 0), 0.4)
# ---------- 남쪽 ----------
put("shelf", (1, 15), (-1, 0), 0.5, block=True); put("cart", (1, 17), (-1, 0), 0.5, block=True)   # 오물실
put("sink", (3, 14), (1, 0), 0.45)
for x in range(5, 16, 2):                                                     # 제1중환자실: 남쪽 벽에 침대 여섯
    put("bed", (x, 17), (0, 1), 1.85, block=True)
    put("monitor", (x + (1 if x < 15 else -1), 17), (0, 1), 0.4, along=0.4 if x < 15 else -0.4)
    if x < 15:
        put_at("bed_curtain", x * 2 + 4, 35, 90)
for x in (7, 11): put("iv_stand", (x, 16), (0, 1), 0.3, along=0.7)
put("desk", (5, 14), (0, -1), 0.65); put_at("chair", 5 * 2 + 1, 14 * 2 + 1 + 0.3, 20)
put("cart", (15, 14), (1, 0), 0.5, block=True)
put("bench", (17, 15), (-1, 0), 0.5); put("bench", (17, 16), (-1, 0), 0.5)  # 보호자 대기실
put("bench", (21, 15), (1, 0), 0.5); put("bench", (21, 16), (1, 0), 0.5)
put("table", (19, 17), (0, 1), 0.75, gap=0.3)
for x in range(23, 34, 2):                                                    # 제2중환자실
    put("bed", (x, 17), (0, 1), 1.85, block=True)
    put("monitor", (x + (1 if x < 33 else -1), 17), (0, 1), 0.4, along=0.4 if x < 33 else -0.4)
    if x < 33:
        put_at("bed_curtain", x * 2 + 4, 35, 90)
put("iv_stand", (25, 16), (0, 1), 0.3, along=0.7)
put("desk", (33, 14), (0, -1), 0.65); put("cart", (23, 14), (-1, 0), 0.5, block=True)
put("shelf", (36, 15), (1, 0), 0.5, block=True); put("shelf", (36, 17), (1, 0), 0.5, block=True)   # 린넨실
# ---------- 복도 손잡이와 소화기 ----------
door_tiles = {(x, y) for x, y, _ in doors}
for t in [(x, y) for y in (6, 12) for x in range(4, 35)]:
    for d in ((0, -1), (0, 1)):
        n = (t[0] + d[0], t[1] + d[1])
        if g[n[1]][n[0]] == "#":
            put("handrail", t, d, 0.0, gap=0.0)
put("extinguisher", (12, 6), (0, 1), 0.2); put("extinguisher", (26, 12), (0, -1), 0.2)
put("wheelchair", (34, 6), (0, -1), 0.7, along=0.2)
put("cart", (16, 12), (0, 1), 0.5, along=0.3)

# ---------- 수술등·천장등 (배터리함 위치, 등 위치) ----------
# (이름, 배터리함 칸, 붙는 벽 방향, 등 위치들(층 좌표), 범위, 초당 소모, 대사용 이름)
LAMPS = [
    # 수술등: 수술대 양옆에 하나씩. 방(10×8m) 구석까지 닿게 범위 5.6m
    ("수술등_1", (8, 4), (0, 1), [(13.5, 2.75, 6.0), (16.5, 2.75, 6.0)], 5.6, 2.0, "수술실"),
    ("수술등_2", (26, 4), (0, 1), [(49.5, 2.75, 6.0), (52.5, 2.75, 6.0)], 5.6, 2.0, "수술실"),
    # 중환자실 처치등: 22×8m 병실에 넷. 침대 사이 어디에도 어두운 틈이 없게 (틈이 있으면 광인이 거기 숨는다)
    ("천장등_중환자실1", (11, 14), (0, -1), [(12.75, 2.8, 32.0), (18.25, 2.8, 32.0), (23.75, 2.8, 32.0), (29.25, 2.8, 32.0)], 5.2, 3.0, "중환자실"),
    ("천장등_중환자실2", (29, 14), (0, -1), [(48.75, 2.8, 32.0), (54.25, 2.8, 32.0), (59.75, 2.8, 32.0), (65.25, 2.8, 32.0)], 5.2, 3.0, "중환자실"),
]
for name, t, d, fx, reach, drain, rn in LAMPS:
    assert t not in door_tiles
# ---------- 표지판 ----------
signs = []
def sign_on(t, d, text, width=0.5, y=2.5):
    cx, cz = cen(t)
    signs.append((text, round(cx + d[0] * 0.99, 3), y, round(cz + d[1] * 0.99, 3), DIR_YAW[d], width))
sign_on((7, 6), (0, -1), "제1수술실", 0.8, y=2.55); sign_on((13, 6), (0, -1), "회복실", 0.6, y=2.55)
sign_on((25, 6), (0, -1), "제2수술실", 0.8, y=2.55); sign_on((31, 6), (0, -1), "마취·준비실", 0.9, y=2.55)
sign_on((6, 6), (0, 1), "스크럽", 0.6); sign_on((14, 6), (0, 1), "탈의실", 0.6); sign_on((28, 6), (0, 1), "당직의사실", 0.9)
sign_on((10, 12), (0, -1), "멸균물품실", 0.9); sign_on((24, 12), (0, -1), "혈액·약품", 0.8); sign_on((32, 12), (0, -1), "장비 창고", 0.8)
sign_on((10, 12), (0, 1), "중환자실 1", 0.9); sign_on((28, 12), (0, 1), "중환자실 2", 0.9)
sign_on((2, 12), (0, 1), "오물실", 0.6); sign_on((35, 12), (0, 1), "린넨실", 0.6)
signs.append(("중환자실 스테이션", 39.0, 2.6, 13.9, 180, 1.5))
signs.append(("보호자 대기실", 39.0, 2.6, 25.9, 180, 1.2))
signs.append(("비상계단  1F ↓", 5.0, 2.6, 11.95, 0, 1.2))
signs.append(("비상계단  1F ↓", 73.0, 2.6, 11.95, 0, 1.2))
signs.append(("3F 이상 출입 통제", 7.95, 1.9, 4.5, -90, 1.1))
signs.append(("계단 사용 금지", 42.0, 1.75, 7.62, 0, 1.0))
sign_on((19, 1), (0, -1), "엘리베이터 운행 중지", 1.1, y=2.0)
sign_on((17, 2), (-1, 0), "2F 수술·중환자동\n수술실 · 중환자실", 1.0, y=1.9)
sign_on((10, 14), (0, -1), "무영등·처치등 정전 시\n비상전원 배터리함 사용", 1.0, y=1.95)

BOARD = ("11/2 (화) 2층 현황\n\n"
         "제1수술실  01:30~ 응급 개복 (정 / 마취 정)\n"
         "중환자실 1 · 2  각 6병상 만실\n\n"
         "※ 무영등 비상전원 배터리 미보충\n"
         "   (시설과 연락 요망!!)\n"
         "※ 3층 이상 출입 통제")
BOARD_POS = (39.0, 1.55, 21.99)

# ---------- 사람 ----------
NAMES = iter("정해림 백승호 마은정 구본철 염순애 차경민 하동수 진미영 우태현 엄귀분 석준혁 전말녀 표성길 함지은 맹상철 길옥자 도영훈 피순남 육재민 탁금순 봉철수 남윤희".split())
people = []
def person(t, role="환자"):
    people.append((t, f"{role} {next(NAMES)}"))
# 제1수술실: 수술팀 넷이 수술대를 둘러싼 채 굳음
person((6, 2), "의사"); person((8, 3), "간호사"); person((8, 2), "마취과 의사"); person((6, 3), "간호사")
person((12, 2)); person((14, 3), "간호사")                       # 회복실
person((24, 2), "의사"); person((26, 3), "간호사"); person((24, 4), "간호사")   # 제2수술실
person((31, 3), "간호사")                                         # 마취·준비실
person((6, 9), "의사")                                            # 스크럽실: 손을 씻다가
person((19, 9), "간호사")                                         # 스테이션
person((28, 9), "의사")                                           # 당직의사실
person((6, 15)); person((9, 16)); person((12, 15)); person((14, 16), "간호사")   # 제1중환자실
person((24, 15)); person((27, 16)); person((31, 15), "간호사")    # 제2중환자실
person((19, 15), "보호자")                                        # 보호자 대기실
person((30, 6), "보호자")                                         # 복도
LIGHTS = [(3, 4), (35, 4)]   # 계단의 초록 비상 유도등만
# ---------- 뒤질 곳 ----------
import random as _rnd
_R = _rnd.Random(11)
FIXED_LOOT = {("desk", (17, 10)): "battery", ("shelf", (31, 8)): "battery", ("desk", (29, 10)): "battery",
              ("cart", (29, 4)): "battery", ("shelf", (9, 8)): "chem", ("locker", (14, 10)): "chem",
              # 붕대: 멸균물품실, 수술실 카트, 중환자실 처치 카트
              ("shelf", (11, 8)): "bandage", ("cart", (5, 4)): "bandage", ("cart", (15, 14)): "bandage"}
def _tile_of(x, z): return (int(x // 2), int(z // 2))
for i, (kind, x, y, z, yaw, extra) in enumerate(props):
    if kind not in ("locker", "desk", "shelf", "cart"):
        continue
    loot = FIXED_LOOT.get((kind, _tile_of(x, z)))
    if loot is None:
        r = _R.random()
        loot = "chem" if (kind == "locker" and r < 0.15) else "empty"
    extra = dict(extra); extra["loot"] = f'"{loot}"'
    props[i] = (kind, x, y, z, yaw, extra)
assert sum(1 for p in props if p[5].get("loot") == '"battery"') == 4, "예비 배터리는 4곳"

NOTES = [
 ("수술 기록 — 제1수술실", "02:10 정전. 무영등 꺼짐.\n비상전원 배터리함이 비어 있었다.\n(지난달 점검 때 빼 간 뒤 아무도 안 채움)\n\n봉합은 끝냈다. 환자는 아직 마취에서 깨지 않았다.\n\n손전등 배터리를 모아서 배터리함에 꽂아 보자는 말이 나왔다.\n아무도 움직이지 않았다.\n\n— 마취과 정", (19.6, 0.92, 3.1)),
 ("중환자실 간호 기록 — 03:20", "인공호흡기 정지. 손으로 앰부를 짜는 중.\n\n3번 침대 환자분이 일어나 앉으셨다.\n의식이 없는데 눈은 떠 있다.\n\n천장 처치등만 켜면 다들 괜찮아질 것 같은데\n배터리함이 비어 있다.\n\n내 손도 무겁다.", (11.3, 0.775, 28.4)),
 ("연구 메모 A-11", "2층 수술동에는 창이 없다.\n중증 실험군을 이곳에 모은 이유.\n\n빛이 강할수록, 여러 명에게 한꺼번에 비출수록 회복이 빠름.\n(집단 노출 결과)\n\n단, 몸이 먼저 풀리고 정신은 늦게 돌아온다.\n그 사이에는 빛을 피해 달아나려 한다. 출입문 통제 필수.\n\n발전기만 돌면 층 전체를 한 번에 되돌릴 수 있다.\n발전기는 지하에.", (59.3, 0.775, 21.6)),
 ("사물함에 붙은 쪽지", "이거 보는 사람\n\n수술실 배터리함에 배터리 좀 꽂아 줘요\n헤드램프 거랑 규격 같아요\n\n우리 아직 안에 있어요", (27.0, 0.01, 21.0)),
]
# ---------- 검사 ----------
floor = {(x, y) for y in range(H) for x in range(W) if g[y][x] == "."}
def reach(start, bad):
    seen = {start}; q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in floor and n not in bad and n not in seen:
                seen.add(n); q.append(n)
    return seen
r = reach(EXIT_W, blocked)
lost = floor - blocked - r
assert not lost, f"가구 때문에 못 가는 칸: {sorted(lost)}"
assert EXIT_E in r
for t, n in people:
    assert t in floor and t not in blocked and t not in door_tiles, (t, n)
    for L in LIGHTS:
        assert math.dist(t, L) > 3.0, ("비상등 너무 가까움", t, n)
assert len({p[0] for p in people}) == len(people)
for name, t, d, fx, reach_, drain, rn in LAMPS:
    assert t in floor and t not in blocked, (name, t)

# ---------- tscn 쓰기 ----------
KINDS = sorted({p[0] for p in props} | {"note", "sign", "board"})
def T(x, y, z, yaw):
    c, s = round(math.cos(math.radians(yaw)), 5), round(math.sin(math.radians(yaw)), 5)
    return f"Transform3D({c}, 0, {s}, 0, 1, 0, {-s}, 0, {c}, {x}, {y}, {z})"
o = ['[gd_scene format=3]\n']
o.append('[ext_resource type="Script" path="res://scripts/objects/level.gd" id="level"]')
o.append('[ext_resource type="Script" path="res://scripts/objects/clock.gd" id="clock"]')
for i, p in (("person", "person"), ("door", "door"), ("elight", "emergency_light"), ("stairs", "stairs"), ("lamp", "surgical_light")):
    o.append(f'[ext_resource type="PackedScene" path="res://scenes/{p}.tscn" id="{i}"]')
for t in ("wall", "floor", "ceiling"):
    o.append(f'[ext_resource type="Texture2D" path="res://textures/{t}.png" id="t_{t}"]')
for k in KINDS:
    o.append(f'[ext_resource type="PackedScene" path="res://scenes/props/{k}.tscn" id="p_{k}"]')
o.append("")
for mid, tex, rough in (("wall", "wall", 0.95), ("floor", "floor", 0.8), ("ceil", "ceiling", 1.0)):
    o.append(f'[sub_resource type="StandardMaterial3D" id="{mid}"]\nalbedo_texture = ExtResource("t_{tex}")\nroughness = {rough}\ncull_mode = 2\ntexture_filter = 4\n')
o.append('[node name="Level2F" type="Node3D"]\nscript = ExtResource("level")\nwall_map = "' + "\n".join(MAP) +
         f'"\nfloor_no = 2\nentrance_tile = Vector2i(-1, -1)\nexit_floor = 1\n'
         'arrive_thought = "창이 하나도 없다. 여기는 달빛도 들지 않는다."\n'
         'hall_reserve = 0.0\nwall_material = SubResource("wall")\nfloor_material = SubResource("floor")\nceiling_material = SubResource("ceil")\n')
for grp in ("People", "Doors", "Lights", "Lamps", "Props", "Signs", "Notes", "Clocks"):
    o.append(f'[node name="{grp}" type="Node3D" parent="."]\n')
o.append(f'[node name="벽시계_스테이션" type="Node3D" parent="Clocks"]\ntransform = {T(37.0, 2.35, 22.0, 180)}\nscript = ExtResource("clock")\n')
for t, n in people:
    x, z = cen(t)
    o.append(f'[node name="{n.replace(" ", "_")}" parent="People" instance=ExtResource("person")]\ntransform = {T(x, 0, z, 0)}\nperson_name = "{n}"\n')
for x, y, op in doors:
    cx, cz = cen((x, y))
    room_north = y in (5, 11)
    o.append(f'[node name="문_{x}_{y}" parent="Doors" instance=ExtResource("door")]\ntransform = {T(cx, 0, cz, 180 if room_north else 0)}' + ("\nopen = true\n" if op else "\n"))
for i, t in enumerate(LIGHTS):
    cx, cz = cen(t)
    o.append(f'[node name="비상등_{i}" parent="Lights" instance=ExtResource("elight")]\ntransform = {T(cx, 2.7, cz, 0)}\n')
for name, t, d, fx, reach_, drain, rn in LAMPS:
    cx, cz = cen(t)
    x, z = cx + d[0] * 0.99, cz + d[1] * 0.99
    arr = ", ".join(f"{a}, {b}, {c}" for a, b, c in fx)
    o.append(f'[node name="{name}" parent="Lamps" instance=ExtResource("lamp")]\ntransform = {T(round(x, 3), 0, round(z, 3), DIR_YAW[d])}\n'
             f'fixtures = PackedVector3Array({arr})\nreach = {reach_}\ndrain_per_sec = {drain}\nroom_name = "{rn}"\n')
o.append(f'[node name="StairsW" parent="." instance=ExtResource("stairs")]\ntransform = {T(4, 0, 6.6, 0)}\nside = "W"\nto_floor = 1\narrive_tile = Vector2i({EXIT_W[0]}, {EXIT_W[1]})\n')
o.append(f'[node name="StairsE" parent="." instance=ExtResource("stairs")]\ntransform = {T(72, 0, 6.6, 0)}\nside = "E"\nto_floor = 1\narrive_tile = Vector2i({EXIT_E[0]}, {EXIT_E[1]})\n')
cnt = {}
for kind, x, y, z, yaw, extra in props:
    cnt[kind] = cnt.get(kind, 0) + 1
    ex = "".join(f"\n{k} = {v}" for k, v in extra.items())
    o.append(f'[node name="{kind}_{cnt[kind]}" parent="Props" instance=ExtResource("p_{kind}")]\ntransform = {T(x, y, z, yaw)}{ex}\n')
for i, (text, x, y, z, yaw, w) in enumerate(signs):
    tt = text.replace("\n", "\\n")
    o.append(f'[node name="표지판_{i}" parent="Signs" instance=ExtResource("p_sign")]\ntransform = {T(x, y, z, yaw)}\ntext = "{tt}"\nwidth = {w}\n')
o.append(f'[node name="현황판" parent="Signs" instance=ExtResource("p_board")]\ntransform = {T(*BOARD_POS, 180)}\ntext = "{BOARD}"\n')
for i, (title, body, (x, y, z)) in enumerate(NOTES):
    b = body.replace("\\", "\\\\").replace('"', '\\"')
    o.append(f'[node name="쪽지_{i}" parent="Notes" instance=ExtResource("p_note")]\ntransform = {T(round(x, 3), y, round(z, 3), 15 * i)}\ntitle = "{title}"\nbody = "{b}"\n')
open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(o))
grid = [list(r) for r in MAP]
for t in blocked: grid[t[1]][t[0]] = "b"
for t, n in people: grid[t[1]][t[0]] = "S"
for x, y, op in doors: grid[y][x] = "D" if not op else "d"
for name, t, d, *_ in LAMPS: grid[t[1]][t[0]] = "L"
grid[EXIT_W[1]][EXIT_W[0]] = "E"; grid[EXIT_E[1]][EXIT_E[0]] = "E"
print("\n".join("".join(r) for r in grid)); print(cnt, "people", len(people))
