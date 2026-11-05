"""Blender betiklerinin ortak yardımcıları (önizleme render, malzeme, temizlik)."""
import math
import bpy
from mathutils import Vector


def sahneyi_temizle():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def malzeme(ad, renk, puruz=0.65, metal=0.0):
    m = bpy.data.materials.get(ad) or bpy.data.materials.new(ad)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*renk, 1.0)
    bsdf.inputs["Roughness"].default_value = puruz
    bsdf.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*renk, 1.0)
    return m


def hex_renk(h):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    # sRGB -> doğrusal (Blender malzemeleri doğrusal renk ister)
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)


def render_ayarla(gen=420, yuk=420, ornek=24):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = ornek
    sc.cycles.use_denoising = False
    sc.render.resolution_x = gen
    sc.render.resolution_y = yuk
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    if sc.world is None:
        sc.world = bpy.data.worlds.new("Dunya")
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.55, 0.7, 0.85, 1)
    bg.inputs["Strength"].default_value = 0.8
    if "Gunes" not in bpy.data.objects:
        isik = bpy.data.lights.new("Gunes", "SUN")
        isik.energy = 3.5
        o = bpy.data.objects.new("Gunes", isik)
        o.rotation_euler = (math.radians(50), math.radians(10), math.radians(30))
        sc.collection.objects.link(o)


def kamera(konum, hedef, lens=50):
    sc = bpy.context.scene
    cam = sc.camera
    if cam is None:
        cam = bpy.data.objects.new("Kamera", bpy.data.cameras.new("Kamera"))
        sc.collection.objects.link(cam)
        sc.camera = cam
    cam.data.lens = lens
    cam.data.clip_end = 500
    cam.location = Vector(konum)
    yon = Vector(hedef) - cam.location
    cam.rotation_euler = yon.to_track_quat("-Z", "Y").to_euler()


def render(yol):
    bpy.context.scene.render.filepath = yol
    bpy.ops.render.render(write_still=True)
    print("render ->", yol)
