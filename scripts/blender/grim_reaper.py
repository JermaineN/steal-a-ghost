# Builds the Grim Reaper (the Secret ghost, GhostConfig `secret_1`) in Blender, in the game's
# chunky cartoon style: a big skull with glowing eyes under a pointed hood, a layered tattered
# robe that floats on a wispy hem, bony hands, a huge scythe with a glowing edge, and an
# hourglass. Every part gets a flat colour (some with a gradient); the colours and some ambient
# occlusion are then baked into one texture, so it imports as a single textured MeshPart like
# the other ghosts.
#
# Run (from the repo root):
#   E:\Apps\blender.exe -b --python scripts/blender/grim_reaper.py -- assets/grim_reaper
# Writes into that folder: grim_reaper.fbx, grim_reaper.obj, grim_reaper_texture.png,
# grim_reaper.blend and preview_*.png renders.
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
os.makedirs(OUT, exist_ok=True)
TEXTURE_SIZE = 1024

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


# ---------------------------------------------------------------------------
# Materials (sRGB 0-255 colours, like the Roblox colour picker)
# ---------------------------------------------------------------------------


def linear(rgb):
    return tuple((c / 255) ** 2.2 for c in rgb) + (1.0,)


def material(name, rgb, glow=False, gradient=None):
    """A flat colour; `gradient` = (bottomRgb, topRgb, zBottom, zTop) blends by height."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = linear(rgb)
    bsdf.inputs["Roughness"].default_value = 0.6
    if glow:
        bsdf.inputs["Emission Color"].default_value = linear(rgb)
        bsdf.inputs["Emission Strength"].default_value = 1.0
    if gradient:
        bottom, top, z0, z1 = gradient
        geometry = nodes.new("ShaderNodeNewGeometry")
        split = nodes.new("ShaderNodeSeparateXYZ")
        remap = nodes.new("ShaderNodeMapRange")
        remap.inputs["From Min"].default_value = z0
        remap.inputs["From Max"].default_value = z1
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = linear(bottom)
        ramp.color_ramp.elements[1].color = linear(top)
        links.new(geometry.outputs["Position"], split.inputs[0])
        links.new(split.outputs["Z"], remap.inputs["Value"])
        links.new(remap.outputs["Result"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


CLOAK = material("Cloak", (34, 28, 46), gradient=((14, 11, 20), (52, 44, 70), 0.2, 4.2))
MANTLE = material("Mantle", (45, 38, 62), gradient=((30, 25, 42), (66, 58, 88), 3.2, 4.0))
INNER = material("HoodInside", (8, 6, 12))
TRIM = material("Trim", (95, 88, 120))
BONE = material("Bone", (242, 238, 228), gradient=((205, 198, 188), (250, 248, 240), 3.8, 4.8))
DARK = material("Socket", (14, 10, 20))
EYE = material("EyeGlow", (170, 245, 255), glow=True)
WOOD = material("Staff", (58, 40, 36), gradient=((40, 28, 26), (82, 58, 50), 0.5, 6.3))
METAL = material("Blade", (196, 202, 214), gradient=((150, 156, 172), (225, 230, 240), 4.4, 6.4))
EDGE = material("BladeEdge", (190, 250, 255), glow=True)
GOLD = material("Gold", (232, 182, 64))
ROPE = material("Rope", (92, 82, 112))
SAND = material("Sand", (246, 214, 140))
GLASS = material("Glass", (205, 232, 255))

parts = []


def add_object(name, bm, mats, smooth=True, subsurf=0):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    for mat in mats:
        obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = smooth
    if subsurf:
        mod = obj.modifiers.new("Subsurf", "SUBSURF")
        mod.levels = subsurf
        mod.render_levels = subsurf
    parts.append(obj)
    return obj


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


# ---------------------------------------------------------------------------
# Shape helpers
# ---------------------------------------------------------------------------


def lathe(name, profile, mat, segs=32, yscale=0.85, hem=None, folds=0.0, subsurf=1):
    """Spins (z, radius) rings, top to bottom. `hem(angle)` returns (dz, radiusScale) for the
    bottom ring (tattered edges); `folds` ripples the radius like cloth folds."""
    bm = bmesh.new()
    rings = []
    for index, (z, r) in enumerate(profile):
        ring = []
        depth = index / max(1, len(profile) - 1)
        for s in range(segs):
            a = 2 * math.pi * s / segs
            rr = r * (1 + folds * depth * math.sin(7 * a + 0.6))
            zz = z
            if hem and index == len(profile) - 1:
                dz, scale = hem(a)
                zz += dz
                rr *= scale
            ring.append(bm.verts.new((rr * math.sin(a), -rr * math.cos(a) * yscale, zz)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for s in range(segs):
            bm.faces.new((rings[i][s], rings[i][(s + 1) % segs], rings[i + 1][(s + 1) % segs], rings[i + 1][s]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return add_object(name, bm, [mat], subsurf=subsurf)


def tattered(points, depth, base=0.0, flare=1.06):
    """A zigzag hem: `points` rag tips hanging `depth` lower than the notches between them."""

    def hem(a):
        t = (a * points / (2 * math.pi)) % 1.0
        tri = abs(t - 0.5) * 2  # 1 at a notch, 0 at a tip
        return base - depth * (1 - tri) ** 1.5, 1 + (flare - 1) * (1 - tri)

    return hem


def sphere(name, center, radius, mat, scale=(1, 1, 1), segs=24, rings=12, subsurf=0):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
    for v in bm.verts:
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2])) + Vector(center)
    return add_object(name, bm, [mat], subsurf=subsurf)


def box(name, center, size, mat, bevel=0.0, rotation=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect="EDGES")
    if rotation:
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=rotation)
    for v in bm.verts:
        v.co += Vector(center)
    return add_object(name, bm, [mat], smooth=bool(bevel))


def tube(name, p1, p2, r1, r2, mat, segs=16, subsurf=0, smooth=True):
    """A tapered cylinder from p1 (radius r1) to p2 (radius r2), capped."""
    p1, p2 = Vector(p1), Vector(p2)
    axis = (p2 - p1).normalized()
    side = axis.orthogonal().normalized()
    other = axis.cross(side)
    bm = bmesh.new()
    rings = []
    for point, r in ((p1, r1), (p2, r2)):
        ring = []
        for s in range(segs):
            a = 2 * math.pi * s / segs
            ring.append(bm.verts.new(point + (side * math.cos(a) + other * math.sin(a)) * r))
        rings.append(ring)
    for s in range(segs):
        bm.faces.new((rings[0][s], rings[0][(s + 1) % segs], rings[1][(s + 1) % segs], rings[1][s]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return add_object(name, bm, [mat], smooth=smooth, subsurf=subsurf)


def ring(name, center, major, minor, mat, axis=(0, 0, 1), yscale=1.0, segs=32):
    """A torus around `axis` (a direction) through `center`."""
    axis = Vector(axis).normalized()
    side = axis.orthogonal().normalized() if abs(axis.z) < 0.99 else Vector((1, 0, 0))
    other = axis.cross(side)
    bm = bmesh.new()
    verts = []
    minor_segs = 8
    for s in range(segs):
        a = 2 * math.pi * s / segs
        row = []
        for m in range(minor_segs):
            b = 2 * math.pi * m / minor_segs
            r = major + minor * math.cos(b)
            local = side * (r * math.cos(a)) + other * (r * math.sin(a) * yscale) + axis * (minor * math.sin(b))
            row.append(bm.verts.new(local + Vector(center)))
        verts.append(row)
    for s in range(segs):
        for m in range(minor_segs):
            bm.faces.new(
                (
                    verts[s][m],
                    verts[(s + 1) % segs][m],
                    verts[(s + 1) % segs][(m + 1) % minor_segs],
                    verts[s][(m + 1) % minor_segs],
                )
            )
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return add_object(name, bm, [mat])


# ---------------------------------------------------------------------------
# The Reaper (faces -Y, the Blender front view; about 6.6 units tall)
# ---------------------------------------------------------------------------

# Robe: flares out to a tattered, floating hem with soft folds.
lathe(
    "Robe",
    [
        (3.75, 0.36), (3.68, 0.62), (3.55, 0.76), (3.3, 0.83), (2.9, 0.88), (2.4, 0.96), (2.0, 1.03),
        (1.6, 1.11), (1.25, 1.19), (0.9, 1.27), (0.7, 1.32), (0.55, 1.36),
    ],
    CLOAK,
    segs=56,
    subsurf=0,
    hem=tattered(7, 0.9, base=0.15, flare=1.16),
    folds=0.05,
)
# Short shoulder cape over it, also tattered.
lathe(
    "Mantle",
    [(4.02, 0.42), (3.97, 0.66), (3.88, 0.84), (3.72, 0.96), (3.5, 1.03), (3.25, 1.06)],
    MANTLE,
    segs=56,
    subsurf=0,
    hem=tattered(8, 0.38, flare=1.06),
)
# Rope belt.
ring("Belt", (0, 0, 2.55), 0.95, 0.06, ROPE, yscale=0.85)
tube("BeltTail", (0.35, -0.86, 2.52), (0.42, -1.0, 1.85), 0.05, 0.04, ROPE, segs=8)
sphere("BeltKnot", (0.35, -0.86, 2.55), 0.1, ROPE, segs=12, rings=8)

# Hood: a sphere with the face opening cut out, a pointed tip at the back, and thickness.
bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=18, radius=0.9)
doomed = []
for v in bm.verts:
    d = v.co.normalized()
    if (d.y < -0.42 and -0.78 < d.z < 0.58) or d.z < -0.82:
        doomed.append(v)
bmesh.ops.delete(bm, geom=doomed, context="VERTS")
for v in bm.verts:
    d = v.co.normalized()
    # Pull the back of the crown up and back into a drooping point.
    pull = max(0.0, d.z) * max(0.0, d.y + 0.2)
    v.co += Vector((0, 0.55 * pull**1.5, 0.7 * pull**2))
    v.co = Vector((v.co.x * 1.05, v.co.y, v.co.z * 1.08)) + Vector((0, 0.08, 4.32))
hood = add_object("Hood", bm, [CLOAK, INNER, TRIM], subsurf=0)
solid = hood.modifiers.new("Solidify", "SOLIDIFY")
solid.thickness = 0.1
solid.offset = 1
solid.material_offset = 1
solid.material_offset_rim = 2
sub = hood.modifiers.new("Subsurf", "SUBSURF")
sub.levels = 1
sub.render_levels = 1

# Skull: a big rounded cranium, a chunky jaw, deep sockets with glowing eyes.
sphere("Cranium", (0, -0.12, 4.32), 0.56, BONE, scale=(1.0, 0.95, 0.98), subsurf=1)
box("Jaw", (0, -0.3, 3.9), (0.62, 0.52, 0.34), BONE, bevel=0.12)
box("Mouth", (0, -0.565, 3.93), (0.44, 0.04, 0.13), DARK, bevel=0.03)
for i in range(5):
    box(f"Tooth{i}", (-0.17 + i * 0.085, -0.585, 3.93), (0.066, 0.03, 0.11), BONE, bevel=0.015)
for side in (-1, 1):
    sphere(f"Socket{side}", (side * 0.21, -0.6, 4.3), 0.17, DARK, scale=(1.0, 0.45, 1.15))
    sphere(f"Eye{side}", (side * 0.21, -0.665, 4.29), 0.09, EYE, segs=12, rings=8)
    sphere(f"Cheek{side}", (side * 0.3, -0.5, 4.05), 0.1, BONE, scale=(1.0, 0.6, 0.6), segs=12, rings=8)
# Nose: an upside-down triangle.
bm = bmesh.new()
tri = [bm.verts.new(p) for p in ((-0.07, -0.66, 4.15), (0.07, -0.66, 4.15), (0, -0.66, 4.02))]
back = [bm.verts.new(p) for p in ((-0.07, -0.6, 4.15), (0.07, -0.6, 4.15), (0, -0.6, 4.02))]
bm.faces.new(tri)
bm.faces.new(list(reversed(back)))
for i in range(3):
    bm.faces.new((tri[i], back[i], back[(i + 1) % 3], tri[(i + 1) % 3]))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
add_object("Nose", bm, [DARK], smooth=False)

# Sleeves: bell-shaped, from the shoulders out to the wrists.
RIGHT_WRIST = Vector((1.42, -0.42, 3.05))
LEFT_WRIST = Vector((-1.32, -0.5, 2.78))
tube("RightSleeve", (0.72, 0.0, 3.62), RIGHT_WRIST, 0.24, 0.36, CLOAK, segs=24)
tube("LeftSleeve", (-0.72, 0.0, 3.62), LEFT_WRIST, 0.24, 0.36, CLOAK, segs=24)
ring("RightCuff", RIGHT_WRIST, 0.34, 0.045, TRIM, axis=RIGHT_WRIST - Vector((0.72, 0.0, 3.62)))
ring("LeftCuff", LEFT_WRIST, 0.34, 0.045, TRIM, axis=LEFT_WRIST - Vector((-0.72, 0.0, 3.62)))

# Scythe: a long staff on the right, gold bands, and a huge curved blade over the head.
STAFF_BOTTOM = Vector((1.55, -0.55, 0.45))
STAFF_TOP = Vector((1.82, -0.5, 6.25))
staff_dir = (STAFF_TOP - STAFF_BOTTOM).normalized()
tube("Staff", STAFF_BOTTOM, STAFF_TOP, 0.085, 0.075, WOOD, segs=12)
for t in (0.02, 0.62, 0.93):
    p = STAFF_BOTTOM.lerp(STAFF_TOP, t)
    tube(f"Band{t}", p - staff_dir * 0.06, p + staff_dir * 0.06, 0.11, 0.11, GOLD, segs=12)
sphere("StaffCap", STAFF_TOP + staff_dir * 0.08, 0.13, GOLD, segs=12, rings=8)
sphere("StaffFoot", STAFF_BOTTOM - staff_dir * 0.05, 0.11, GOLD, segs=12, rings=8)

# Blade: stations along a curved spine; each has a thick back edge, a glowing cutting edge.
blade_root = STAFF_TOP - staff_dir * 0.22
u_axis = Vector((-1, 0, 0))
v_axis = staff_dir
w_axis = u_axis.cross(v_axis).normalized()
bm = bmesh.new()
stations = []
N = 28
for i in range(N + 1):
    t = i / N
    u = 3.0 * t
    v = 0.4 * math.sin(math.pi * t) - 1.75 * t**2.2
    # Tangent, to find the direction down to the cutting edge.
    du = 3.0
    dv = 0.4 * math.pi * math.cos(math.pi * t) - 1.75 * 2.2 * t**1.2
    tangent = Vector((du, dv)).normalized()
    down = Vector((tangent.y, -tangent.x))  # right-hand normal points below the spine
    width = 0.62 * (1 - t) ** 0.55 + 0.02
    thick = 0.07 * (1 - t) + 0.015

    def point(du_, dv_, dw):
        return blade_root + u_axis * (u + du_) + v_axis * (v + dv_) + w_axis * dw

    spine_f = bm.verts.new(point(0, 0, -thick))
    spine_b = bm.verts.new(point(0, 0, thick))
    mid_b = bm.verts.new(point(down.x * width * 0.72, down.y * width * 0.72, thick * 0.55))
    edge = bm.verts.new(point(down.x * width, down.y * width, 0))
    mid_f = bm.verts.new(point(down.x * width * 0.72, down.y * width * 0.72, -thick * 0.55))
    stations.append([spine_f, spine_b, mid_b, edge, mid_f])
glow_pairs = {(2, 3), (3, 4)}
for i in range(N):
    a, b = stations[i], stations[i + 1]
    for k in range(5):
        k2 = (k + 1) % 5
        face = bm.faces.new((a[k], a[k2], b[k2], b[k]))
        face.material_index = 1 if (k, k2) in glow_pairs else 0
bm.faces.new(list(reversed(stations[0])))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
add_object("Blade", bm, [METAL, EDGE], smooth=False)
# Gold collar holding the blade, with a glowing gem.
tube("Collar", blade_root - staff_dir * 0.2, blade_root + staff_dir * 0.2, 0.14, 0.14, GOLD, segs=12)
sphere("Gem", blade_root + Vector((0, -0.15, 0)), 0.09, EYE, segs=12, rings=8)


# Bony hands: a palm and knobbly finger bones.
def hand(name, wrist, toward, curl_center=None):
    palm_center = wrist + toward * 0.16
    sphere(f"{name}Palm", palm_center, 0.2, BONE, scale=(1.0, 0.8, 1.1), segs=14, rings=10)
    return palm_center


# Right hand wraps the staff: knuckles stacked on the front of it, a thumb around the side.
grip = STAFF_BOTTOM.lerp(STAFF_TOP, (RIGHT_WRIST.z - 0.05 - STAFF_BOTTOM.z) / (STAFF_TOP.z - STAFF_BOTTOM.z))
hand("Right", RIGHT_WRIST, (grip - RIGHT_WRIST).normalized())
for i in range(4):
    p = grip + staff_dir * (0.15 - i * 0.1) + Vector((-0.03, -0.12, 0))
    sphere(f"RightKnuckle{i}", p, 0.07, BONE, segs=10, rings=6)
tube("RightThumb", grip + Vector((-0.1, -0.05, 0.1)), grip + Vector((0.04, -0.12, 0.16)), 0.04, 0.032, BONE, segs=8)

# Left hand holds up an hourglass.
left_dir = (LEFT_WRIST - Vector((-0.72, 0, 3.62))).normalized()
palm = hand("Left", LEFT_WRIST, left_dir)
HOURGLASS = palm + Vector((-0.06, -0.05, 0.08)) + Vector((0, 0, 0.32))
for i, angle in enumerate((-0.6, -0.2, 0.2, 0.6)):
    base = palm + Vector((math.sin(angle) * 0.13, -0.1, 0.02))
    tube(f"LeftFinger{i}", base, base + Vector((math.sin(angle) * 0.05, -0.04, 0.2)), 0.045, 0.038, BONE, segs=8)
top_disc = HOURGLASS + Vector((0, 0, 0.28))
bottom_disc = HOURGLASS - Vector((0, 0, 0.24))
tube("HourglassTop", top_disc, top_disc + Vector((0, 0, 0.05)), 0.19, 0.19, GOLD, segs=16)
tube("HourglassBottom", bottom_disc - Vector((0, 0, 0.05)), bottom_disc, 0.19, 0.19, GOLD, segs=16)
sphere("HourglassUpper", HOURGLASS + Vector((0, 0, 0.13)), 0.14, GLASS, scale=(1, 1, 1.05), segs=16, rings=10)
sphere("HourglassLower", HOURGLASS - Vector((0, 0, 0.1)), 0.14, SAND, scale=(1, 1, 1.0), segs=16, rings=10)
for angle in (0, 2.1, 4.2):
    offset = Vector((math.cos(angle) * 0.16, math.sin(angle) * 0.16, 0))
    tube(f"HourglassPost{angle}", bottom_disc + offset, top_disc + offset, 0.025, 0.025, GOLD, segs=6)

# ---------------------------------------------------------------------------
# Join, unwrap, bake colours + ambient occlusion into one texture
# ---------------------------------------------------------------------------

for obj in parts:
    apply_modifiers(obj)
bpy.ops.object.select_all(action="DESELECT")
for obj in parts:
    obj.select_set(True)
reaper = parts[0]
bpy.context.view_layer.objects.active = reaper
bpy.ops.object.join()
reaper.name = "GrimReaper"
# Keep it light for Roblox (other ghosts are a few thousand triangles; the limit is 20k).
tris = sum(len(p.vertices) - 2 for p in reaper.data.polygons)
TARGET_TRIS = 9000
if tris > TARGET_TRIS:
    decimate = reaper.modifiers.new("Decimate", "DECIMATE")
    decimate.ratio = TARGET_TRIS / tris
    apply_modifiers(reaper)
tris = sum(len(p.vertices) - 2 for p in reaper.data.polygons)
print(f"GRIM REAPER triangles: {tris}")

bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
bpy.ops.uv.pack_islands(margin=0.004)
bpy.ops.object.mode_set(mode="OBJECT")

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 64
scene.render.bake.margin = 8


def new_image(name):
    image = bpy.data.images.new(name, TEXTURE_SIZE, TEXTURE_SIZE, alpha=False)
    image.colorspace_settings.name = "sRGB"
    return image


def bake(kind, image, **kwargs):
    for mat in reaper.data.materials:
        nodes = mat.node_tree.nodes
        node = nodes.get("BakeTarget") or nodes.new("ShaderNodeTexImage")
        node.name = "BakeTarget"
        node.image = image
        nodes.active = node
    bpy.ops.object.bake(type=kind, **kwargs)
    return np.array(image.pixels[:]).reshape(TEXTURE_SIZE, TEXTURE_SIZE, 4)


color = bake("DIFFUSE", new_image("Color"), pass_filter={"COLOR"})
ao_image = new_image("AO")
ao_image.colorspace_settings.name = "Non-Color"
ao = bake("AO", ao_image)
glow = bake("EMIT", new_image("Glow"))

# Shade with the occlusion (crevices darker), but keep glowing parts at full brightness.
shade = 0.5 + 0.5 * ao[:, :, :1]
is_glow = glow[:, :, :3].max(axis=2, keepdims=True) > 0.05
final = color.copy()
final[:, :, :3] = np.where(is_glow, color[:, :, :3], color[:, :, :3] * shade)
final[:, :, 3] = 1.0
texture = new_image("GrimReaperTexture")
texture.pixels[:] = final.ravel()
texture.filepath_raw = os.path.join(OUT, "grim_reaper_texture.png")
texture.file_format = "PNG"
texture.save()

# One material showing the baked texture, for export and the previews.
reaper.data.materials.clear()
baked = bpy.data.materials.new("GrimReaper")
baked.use_nodes = True
tex_node = baked.node_tree.nodes.new("ShaderNodeTexImage")
tex_node.image = texture
baked.node_tree.links.new(tex_node.outputs["Color"], baked.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
baked.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.7
reaper.data.materials.append(baked)

# Origin at the centre of its bounding box.
bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
reaper.location = (0, 0, 0)

bpy.ops.object.select_all(action="DESELECT")
reaper.select_set(True)
bpy.ops.export_scene.fbx(
    filepath=os.path.join(OUT, "grim_reaper.fbx"),
    use_selection=True,
    object_types={"MESH"},
    mesh_smooth_type="FACE",
    path_mode="COPY",
    embed_textures=True,
)
bpy.ops.wm.obj_export(filepath=os.path.join(OUT, "grim_reaper.obj"), export_selected_objects=True)

# ---------------------------------------------------------------------------
# Preview renders (front, three-quarter, side)
# ---------------------------------------------------------------------------

scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 900
scene.render.resolution_y = 1100
world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = linear((70, 66, 90))
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.2
scene.world = world
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 8.0
scene.collection.objects.link(cam)
scene.camera = cam
for name, angle in (("front", 0), ("three_quarter", 35), ("side", 90)):
    a = math.radians(angle)
    cam.location = (12 * math.sin(a), -12 * math.cos(a), 0.3)
    cam.rotation_euler = (math.radians(90), 0, a)
    scene.render.filepath = os.path.join(OUT, f"preview_{name}.png")
    bpy.ops.render.render(write_still=True)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "grim_reaper.blend"))
print("GRIM REAPER done")
