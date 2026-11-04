# 랜턴·병원 소품 씬을 기본 도형(상자, 원기둥, 고리)으로 조립한다
import os, math
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "amhwa2", "scenes", "props")
os.makedirs(D, exist_ok=True)

def T(x=0, y=0, z=0, rot=None):
    # rot: ("x"|"y"|"z", degrees). tscn Transform3D는 행 우선
    if not rot:
        return f"Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})"
    ax, deg = rot; c = round(math.cos(math.radians(deg)), 5); s = round(math.sin(math.radians(deg)), 5)
    if ax == "x": r = [1, 0, 0, 0, c, -s, 0, s, c]
    if ax == "y": r = [c, 0, s, 0, 1, 0, -s, 0, c]
    if ax == "z": r = [c, -s, 0, s, c, 0, 0, 0, 1]
    return "Transform3D(" + ", ".join(str(v) for v in r) + f", {x}, {y}, {z})"

class Scene:
    def __init__(s, root_type, name, extra=""):
        s.ext, s.sub, s.nodes = [], [], []
        s.root = f'[node name="{name}" type="{root_type}"]\n{extra}'
        s.mats = {}
    def ext_res(s, typ, path):
        i = f"e{len(s.ext)+1}"; s.ext.append(f'[ext_resource type="{typ}" path="{path}" id="{i}"]'); return i
    def mat(s, key, color, rough=0.8, metal=0.0, emit=None, energy=1.0, alpha=None):
        if key in s.mats: return s.mats[key]
        i = f"m_{key}"
        lines = [f'[sub_resource type="StandardMaterial3D" id="{i}"]', f"albedo_color = Color({color[0]}, {color[1]}, {color[2]}, {alpha if alpha else 1})", f"roughness = {rough}", f"metallic = {metal}"]
        if alpha: lines.insert(1, "transparency = 1")
        if emit: lines += ["emission_enabled = true", f"emission = Color({emit[0]}, {emit[1]}, {emit[2]}, 1)", f"emission_energy_multiplier = {energy}"]
        s.sub.append("\n".join(lines)); s.mats[key] = i; return i
    def mesh(s, kind, mat, **kw):
        i = f"r{len(s.sub)+1}"
        lines = [f'[sub_resource type="{kind}" id="{i}"]', f'material = SubResource("{mat}")']
        for k, v in kw.items():
            if isinstance(v, tuple): v = f"Vector{len(v)}(" + ", ".join(str(a) for a in v) + ")"
            lines.append(f"{k} = {v}")
        s.sub.append("\n".join(lines)); return i
    def shape(s, size):
        i = f"r{len(s.sub)+1}"; s.sub.append(f'[sub_resource type="BoxShape3D" id="{i}"]\nsize = Vector3({size[0]}, {size[1]}, {size[2]})'); return i
    def node(s, name, typ, parent=".", **props):
        lines = [f'[node name="{name}" type="{typ}" parent="{parent}"]']
        for k, v in props.items(): lines.append(f"{k} = {v}")
        s.nodes.append("\n".join(lines))
    def box(s, name, mat, size, pos, parent=".", rot=None):
        m = s.mesh("BoxMesh", mat, size=size)
        s.node(name, "MeshInstance3D", parent, transform=T(*pos, rot=rot), mesh=f'SubResource("{m}")')
    def cyl(s, name, mat, r_top, r_bot, h, pos, seg=8, parent=".", rot=None):
        m = s.mesh("CylinderMesh", mat, top_radius=r_top, bottom_radius=r_bot, height=h, radial_segments=seg, rings=1)
        s.node(name, "MeshInstance3D", parent, transform=T(*pos, rot=rot), mesh=f'SubResource("{m}")')
    def collider(s, size, pos):
        sh = s.shape(size); s.node("CollisionShape3D", "CollisionShape3D", ".", transform=T(*pos), shape=f'SubResource("{sh}")')
    def save(s, fname):
        out = "[gd_scene format=3]\n\n" + "\n".join(s.ext) + ("\n\n" if s.ext else "") + "\n\n".join(s.sub) + "\n\n" + s.root + "\n" + "\n\n".join(s.nodes) + "\n"
        open(fname, "w").write(out)

METAL = ((0.42, 0.44, 0.45), 0.55, 0.4)
DARK = ((0.12, 0.12, 0.12), 0.9, 0.0)

# ---------- 공통: 소품 루트 ----------
def prop(name, blocker):
    sc = Scene("StaticBody3D", name, "collision_layer = 1\ncollision_mask = 0\n")
    scr = sc.ext_res("Script", "res://scripts/objects/prop.gd")
    sc.root += f'script = ExtResource("{scr}")\nblocks_path = {"true" if blocker else "false"}\n'
    return sc

