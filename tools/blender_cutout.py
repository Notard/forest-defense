"""컷아웃 조각을 Blender에서 움직여 동작별 프레임 PNG로 렌더한다 (plan.md 3단계, 2D 컷아웃).

    blender --background --python tools/blender_cutout.py -- fox [동작 ...]

읽는 것
  tools/rigs/<캐릭터>.json        캔버스, 동작 키프레임
  art/parts/<캐릭터>/rig.json     조각 위치·기준점·부모·순서 (tools/cut_parts.py가 만듦)
만드는 것
  art/render/<캐릭터>/<동작>/0001.png …   프레임 (git 제외)
  art/blend/<캐릭터>.blend                 확인용 장면 (마지막 동작이 들어 있음, git 제외)

좌표: 기준 그림 1px = 0.01m. 그림의 x → 월드 X, 그림의 y(아래 +) → 월드 -Z.
카메라는 -Y에서 +Y를 보는 직교 카메라. 앞 부위일수록 카메라 쪽(-Y)으로 0.01m씩 당긴다.
회전 rot(도)은 화면 기준 시계 방향 + 이며 월드 Y축 회전과 같다.
"""
import json
import math
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parent.parent
PX = 0.01


def args() -> list[str]:
    argv = sys.argv
    return argv[argv.index("--") + 1:] if "--" in argv else []


def world(x: float, y: float, depth: float = 0.0):
    return (x * PX, depth, -y * PX)


def reset_scene() -> bpy.types.Scene:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    # 그림 색을 그대로 내보내려면 Standard 변환이어야 한다 (AgX·Filmic은 색을 바꾼다)
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    if hasattr(scene, "eevee"):
        scene.eevee.taa_render_samples = 32
    return scene


def make_material(name: str, image_path: Path) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    if hasattr(mat, "surface_render_method"):
        mat.surface_render_method = "BLENDED"
    else:
        mat.blend_method = "BLEND"
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(image_path))
    tex.image.alpha_mode = "STRAIGHT"
    tex.interpolation = "Linear"
    tex.extension = "CLIP"
    emit = nodes.new("ShaderNodeEmission")
    clear = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(tex.outputs["Color"], emit.inputs["Color"])
    links.new(tex.outputs["Alpha"], mix.inputs["Fac"])
    links.new(clear.outputs[0], mix.inputs[1])
    links.new(emit.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], out.inputs["Surface"])
    return mat


def make_plane(name: str, x0: float, y0: float, w: float, h: float, depth: float) -> bpy.types.Object:
    # 반투명(BLENDED) 물체는 원점의 카메라 거리로 그리는 순서를 정한다. 원점을 평면 가운데·자기 깊이에 두어야
    # 앞뒤가 맞는다 (모두 같은 원점이면 꼬리가 몸통 위에 그려져 가려진 채움이 비친다, WORKLOG 3-b).
    cx, cy = x0 + w / 2, y0 + h / 2
    verts = [world(x - cx, y - cy) for x, y in ((x0, y0 + h), (x0 + w, y0 + h), (x0 + w, y0), (x0, y0))]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], [(0, 1, 2, 3)])
    uv = mesh.uv_layers.new()
    for loop, coord in zip(uv.data, [(0, 0), (1, 0), (1, 1), (0, 1)]):
        loop.uv = coord
    obj = bpy.data.objects.new(name, mesh)
    obj.location = world(cx, cy, depth)
    bpy.context.collection.objects.link(obj)
    return obj


def build(character: str, parts_meta: dict) -> dict[str, bpy.types.Object]:
    """조각마다 기준점 빈 객체(움직이는 단위)와 그 아래 텍스처 평면을 만든다."""
    pivots: dict[str, bpy.types.Object] = {}
    count = len(parts_meta["parts"])
    for part in parts_meta["parts"]:
        empty = bpy.data.objects.new(f"pivot_{part['name']}", None)
        empty.empty_display_type = "PLAIN_AXES"
        empty.location = world(*part["pivot"])
        bpy.context.collection.objects.link(empty)
        pivots[part["name"]] = empty
    for part in parts_meta["parts"]:
        depth = -part["z"] * PX  # 앞 부위(z 큼)일수록 카메라 쪽(-Y)
        x0, y0 = part["offset"]
        w, h = part["size"]
        plane = make_plane(f"part_{part['name']}", x0, y0, w, h, depth)
        plane.data.materials.append(make_material(part["name"], ROOT / "art" / "parts" / character / f"{part['name']}.png"))
        set_parent(plane, pivots[part["name"]])
    for part in parts_meta["parts"]:
        if part["parent"]:
            set_parent(pivots[part["name"]], pivots[part["parent"]])
    for empty in pivots.values():
        empty["rest_location"] = list(empty.location)
    return pivots


def set_parent(child: bpy.types.Object, parent: bpy.types.Object) -> None:
    bpy.context.view_layer.update()
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()


def make_camera(box: list[float], frame_px: int) -> None:
    left, top, right, bottom = box
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(right - left, bottom - top) * PX
    cam_data.clip_start, cam_data.clip_end = 0.01, 100
    cam = bpy.data.objects.new("cam", cam_data)
    cam.location = world((left + right) / 2, (top + bottom) / 2, -10)
    cam.rotation_euler = (math.radians(90), 0, 0)
    bpy.context.collection.objects.link(cam)
    scene = bpy.context.scene
    scene.camera = cam
    w, h = right - left, bottom - top
    scene.render.resolution_x = frame_px if w >= h else round(frame_px * w / h)
    scene.render.resolution_y = frame_px if h >= w else round(frame_px * h / w)
    scene.render.resolution_percentage = 100


def key_action(pivots: dict, action: dict) -> None:
    for empty in pivots.values():
        empty.animation_data_clear()
        empty.location = empty["rest_location"]
        empty.rotation_euler = (0, 0, 0)
        empty.scale = (1, 1, 1)
    for name, keys in action["keys"].items():
        empty = pivots[name]
        rest = empty["rest_location"]
        for frame, v in keys:
            empty.location = (rest[0] + v.get("dx", 0) * PX, rest[1], rest[2] - v.get("dy", 0) * PX)
            empty.rotation_euler = (0, math.radians(v.get("rot", 0)), 0)
            empty.scale = (v.get("sx", 1), 1, v.get("sy", 1))
            for path in ("location", "rotation_euler", "scale"):
                empty.keyframe_insert(path, frame=frame)


def main() -> None:
    a = args()
    if not a:
        sys.exit(__doc__)
    character, wanted = a[0], a[1:]
    rig = json.loads((ROOT / "tools" / "rigs" / f"{character}.json").read_text(encoding="utf-8"))
    parts_meta = json.loads((ROOT / "art" / "parts" / character / "rig.json").read_text(encoding="utf-8"))

    scene = reset_scene()
    pivots = build(character, parts_meta)
    make_camera(rig["canvas"]["box"], rig["canvas"]["frame_px"])

    for name, action in rig["actions"].items():
        if wanted and name not in wanted:
            continue
        key_action(pivots, action)
        scene.render.fps = action["fps"]
        scene.frame_start, scene.frame_end = 1, action["frames"]
        out = ROOT / "art" / "render" / character / name
        out.mkdir(parents=True, exist_ok=True)
        for old in out.glob("*.png"):
            old.unlink()
        scene.render.filepath = str(out) + "/"
        bpy.ops.render.render(animation=True)
        print(f"[cutout] {character}/{name}: {action['frames']} frames → {out.relative_to(ROOT).as_posix()}")

    blend = ROOT / "art" / "blend" / f"{character}.blend"
    blend.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))


if __name__ == "__main__":
    main()
