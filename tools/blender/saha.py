"""Sahadaki nesneleri sıfırdan modeller ve ayrı glb dosyaları olarak dışa aktarır.

Kullanım: blender -b --python tools/blender/saha.py -- <cikti_klasoru> <onizleme_klasoru>

Eksen notu: Blender'da +Y "kalenin arkası" yönüdür. glTF/Godot'a çıkınca bu -Z olur,
yani oyunda kale z = KALE_Z'ye konunca ağ ve tribün otomatik olarak arkada kalır.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import ortak  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
CIKTI, ONIZLEME = argv[0], argv[1]
os.makedirs(CIKTI, exist_ok=True)
os.makedirs(ONIZLEME, exist_ok=True)
random.seed(61)

KALE_YARI = 3.66
KALE_H = 2.44
DIREK_R = 0.06


def nesne(ad, bm, malzemeler, duz=False):
    me = bpy.data.meshes.new(ad)
    bm.to_mesh(me)
    bm.free()
    for m in malzemeler:
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = not duz
    o = bpy.data.objects.new(ad, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def disa_aktar(nesneler, dosya):
    bpy.ops.object.select_all(action="DESELECT")
    for o in nesneler:
        o.select_set(True)
    bpy.context.view_layer.objects.active = nesneler[0]
    yol = os.path.join(CIKTI, dosya)
    bpy.ops.export_scene.gltf(filepath=yol, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True)
    print("dışa aktarıldı:", yol, os.path.getsize(yol) // 1024, "KB")


def silindir(bm, a, b, r, seg=12, mat=0):
    a, b = Vector(a), Vector(b)
    yon = b - a
    uz = yon.length
    sonuc = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=uz)
    q = yon.to_track_quat("Z", "Y")
    bmesh.ops.rotate(bm, verts=sonuc["verts"], cent=(0, 0, 0), matrix=q.to_matrix())
    bmesh.ops.translate(bm, verts=sonuc["verts"], vec=(a + b) / 2)
    for f in {f for v in sonuc["verts"] for f in v.link_faces}:
        f.material_index = mat


def kutu(bm, merkez, boyut, mat=0):
    sonuc = bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, verts=sonuc["verts"], vec=boyut)
    bmesh.ops.translate(bm, verts=sonuc["verts"], vec=merkez)
    for f in {f for v in sonuc["verts"] for f in v.link_faces}:
        f.material_index = mat


# ---------------------------------------------------------------- TOP
ortak.sahneyi_temizle()
beyaz = ortak.malzeme("TopBeyaz", ortak.hex_renk("#f4f4f4"), 0.35)
siyah = ortak.malzeme("TopSiyah", ortak.hex_renk("#151515"), 0.35)
bm = bmesh.new()
bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
bmesh.ops.bevel(bm, geom=list(bm.verts), offset=33.333, offset_type="PERCENT", affect="VERTICES", segments=1)
for f in bm.faces:
    f.material_index = 1 if len(f.verts) == 5 else 0
bmesh.ops.poke(bm, faces=list(bm.faces))
bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=2, use_grid_fill=True)
for v in bm.verts:
    v.co = v.co.normalized() * 0.11
print("top: beşgen + altıgen", len(bm.faces), "üçgen")
top = nesne("Top", bm, [beyaz, siyah])
disa_aktar([top], "top.glb")

ortak.render_ayarla(360, 360, 24)
ortak.kamera((0.35, -0.45, 0.25), (0, 0, 0), lens=60)
ortak.render(os.path.join(ONIZLEME, "top.png"))

# ---------------------------------------------------------------- KALE
ortak.sahneyi_temizle()
m_direk = ortak.malzeme("Direk", ortak.hex_renk("#ffffff"), 0.3)
m_ag = ortak.malzeme("Ag", ortak.hex_renk("#e9e9e9"), 0.8)
m_demir = ortak.malzeme("ArkaDemir", ortak.hex_renk("#bdbdbd"), 0.5, 0.6)

bm = bmesh.new()
silindir(bm, (-KALE_YARI - DIREK_R, 0, 0), (-KALE_YARI - DIREK_R, 0, KALE_H + DIREK_R), DIREK_R, 16, 0)
silindir(bm, (KALE_YARI + DIREK_R, 0, 0), (KALE_YARI + DIREK_R, 0, KALE_H + DIREK_R), DIREK_R, 16, 0)
silindir(bm, (-KALE_YARI - 2 * DIREK_R, 0, KALE_H + DIREK_R), (KALE_YARI + 2 * DIREK_R, 0, KALE_H + DIREK_R), DIREK_R, 16, 0)
# Ağı taşıyan arka çerçeve
UST_D, ALT_D = 1.0, 2.0
for x in (-KALE_YARI, KALE_YARI):
    silindir(bm, (x, 0, KALE_H), (x, UST_D, KALE_H), 0.02, 8, 1)
    silindir(bm, (x, UST_D, KALE_H), (x, ALT_D, 0.02), 0.02, 8, 1)
    silindir(bm, (x, 0, 0.02), (x, ALT_D, 0.02), 0.02, 8, 1)
silindir(bm, (-KALE_YARI, ALT_D, 0.02), (KALE_YARI, ALT_D, 0.02), 0.02, 8, 1)
silindir(bm, (-KALE_YARI, UST_D, KALE_H), (KALE_YARI, UST_D, KALE_H), 0.02, 8, 1)
cerceve = nesne("KaleCerceve", bm, [m_direk, m_demir])


def ag_paneli(bm, k00, k10, k11, k01, nu, nv):
    k00, k10, k11, k01 = map(Vector, (k00, k10, k11, k01))
    izgara = []
    for j in range(nv + 1):
        satir = []
        for i in range(nu + 1):
            u, v = i / nu, j / nv
            p = k00 * (1 - u) * (1 - v) + k10 * u * (1 - v) + k11 * u * v + k01 * (1 - u) * v
            satir.append(bm.verts.new(p))
        izgara.append(satir)
    for j in range(nv):
        for i in range(nu):
            bm.faces.new((izgara[j][i], izgara[j][i + 1], izgara[j + 1][i + 1], izgara[j + 1][i]))


GOZ = 0.14
bm = bmesh.new()
W = KALE_YARI
ag_paneli(bm, (-W, ALT_D, 0), (W, ALT_D, 0), (W, UST_D, KALE_H), (-W, UST_D, KALE_H), int(2 * W / GOZ), int(2.65 / GOZ))
ag_paneli(bm, (-W, 0, KALE_H), (W, 0, KALE_H), (W, UST_D, KALE_H), (-W, UST_D, KALE_H), int(2 * W / GOZ), int(UST_D / GOZ))
for x in (-W, W):
    ag_paneli(bm, (x, 0, 0), (x, ALT_D, 0), (x, UST_D, KALE_H), (x, 0, KALE_H), int(ALT_D / GOZ), int(KALE_H / GOZ))
ag = nesne("Ag", bm, [m_ag], duz=True)
tel = ag.modifiers.new("Tel", "WIREFRAME")
tel.thickness = 0.012
tel.use_replace = True
tel.use_even_offset = True
disa_aktar([cerceve, ag], "kale.glb")

ortak.render_ayarla(560, 360, 24)
z = bpy.data.meshes.new("Zemin")
z.from_pydata([(-8, -6, 0), (8, -6, 0), (8, 6, 0), (-8, 6, 0)], [], [(0, 1, 2, 3)])
zo = bpy.data.objects.new("Zemin", z)
zo.data.materials.append(ortak.malzeme("Cim", ortak.hex_renk("#3f8f3a"), 0.9))
bpy.context.scene.collection.objects.link(zo)
ortak.kamera((3.5, -8.5, 1.8), (0, 0.6, 1.1), lens=35)
ortak.render(os.path.join(ONIZLEME, "kale.png"))

# ---------------------------------------------------------------- TRİBÜN + REKLAM PANOLARI
ortak.sahneyi_temizle()
m_beton = ortak.malzeme("Beton", ortak.hex_renk("#8a8d92"), 0.9)
m_koltuk = ortak.malzeme("Koltuk", ortak.hex_renk("#b3202a"), 0.6)
m_cati = ortak.malzeme("Cati", ortak.hex_renk("#3c4048"), 0.6, 0.3)
seyirci_renk = ["#c8102e", "#c8102e", "#c8102e", "#ffffff", "#ffffff", "#1d3f8f", "#f2c500", "#222222"]
m_seyirci = [ortak.malzeme(f"Seyirci{i}", ortak.hex_renk(h), 0.8) for i, h in enumerate(seyirci_renk)]
m_yuz = ortak.malzeme("SeyirciTen", ortak.hex_renk("#d9a27c"), 0.7)
MALZ = [m_beton, m_koltuk, m_cati, m_yuz] + m_seyirci

SIRA, BASAMAK_H, BASAMAK_D = 14, 0.42, 0.8


def tribun(bm, x0, x1, y0, yon_y=1, dolu=0.82):
    """x0..x1 boyunca, y0'dan yon_y yönüne yükselen basamaklı tribün + seyirciler."""
    for s in range(SIRA):
        y = y0 + yon_y * (s * BASAMAK_D + BASAMAK_D / 2)
        z = s * BASAMAK_H
        kutu(bm, ((x0 + x1) / 2, y, z / 2 + 0.25), (x1 - x0, BASAMAK_D, z + 0.5), 0)
        x = x0 + 0.3
        while x < x1 - 0.3:
            if random.random() < dolu:
                renk = 4 + random.randrange(len(m_seyirci))
                h = random.uniform(0.0, 0.08)
                kutu(bm, (x, y, z + 0.5 + 0.32 + h / 2), (0.36, 0.26, 0.62 + h), renk)
                kutu(bm, (x, y, z + 0.5 + 0.72 + h), (0.2, 0.2, 0.22), 3)
            else:
                kutu(bm, (x, y + yon_y * 0.1, z + 0.5 + 0.22), (0.42, 0.36, 0.42), 1)
            x += 0.55
    arka_y = y0 + yon_y * SIRA * BASAMAK_D
    ust = SIRA * BASAMAK_H + 0.5
    kutu(bm, ((x0 + x1) / 2, arka_y + yon_y * 0.3, ust / 2 + 1.6), (x1 - x0, 0.6, ust + 3.2), 0)
    kutu(bm, ((x0 + x1) / 2, y0 + yon_y * SIRA * BASAMAK_D * 0.55, ust + 4.2), (x1 - x0, SIRA * BASAMAK_D * 1.1, 0.25), 2)


bm = bmesh.new()
tribun(bm, -30, 30, 7.0, 1)
tri = nesne("Tribun", bm, MALZ, duz=True)

# Reklam panoları (kale arkası)
m_pano = [ortak.malzeme(f"Pano{i}", ortak.hex_renk(h), 0.5) for i, h in enumerate(["#0d2c6c", "#c8102e"])]
m_yazi = ortak.malzeme("PanoYazi", ortak.hex_renk("#ffffff"), 0.5)
bm = bmesh.new()
for i in range(10):
    x = -27 + i * 6
    kutu(bm, (x, 4.5, 0.5), (5.9, 0.15, 1.0), i % 2)
pano = nesne("Pano", bm, m_pano, duz=True)
yazilar = []
for i in range(10):
    x = -27 + i * 6
    yz = bpy.data.curves.new(f"Yazi{i}", "FONT")
    yz.body = "PENALTI USTASI" if i % 2 == 0 else "GOL!"
    yz.align_x = "CENTER"
    yz.align_y = "CENTER"
    yz.size = 0.55
    yz.extrude = 0.01
    o = bpy.data.objects.new(f"Yazi{i}", yz)
    o.location = (x, 4.42, 0.5)
    o.rotation_euler = (math.radians(90), 0, 0)
    o.data.materials.append(m_yazi)
    bpy.context.scene.collection.objects.link(o)
    yazilar.append(o)
bpy.ops.object.select_all(action="DESELECT")
for o in yazilar:
    o.select_set(True)
bpy.context.view_layer.objects.active = yazilar[0]
bpy.ops.object.convert(target="MESH")
bpy.ops.object.join()
yazi = bpy.context.view_layer.objects.active
yazi.name = "PanoYazilari"
disa_aktar([tri, pano, yazi], "tribun.glb")

ortak.render_ayarla(640, 360, 20)
ortak.kamera((0, -14, 3.0), (0, 10, 4.5), lens=28)
ortak.render(os.path.join(ONIZLEME, "tribun.png"))

# ---------------------------------------------------------------- KÖŞE BAYRAĞI
ortak.sahneyi_temizle()
m_sopa = ortak.malzeme("Sopa", ortak.hex_renk("#f2f2f2"), 0.4)
m_bayrak = ortak.malzeme("Bayrak", ortak.hex_renk("#f2c500"), 0.7)
bm = bmesh.new()
silindir(bm, (0, 0, 0), (0, 0, 1.5), 0.02, 10, 0)
v = [bm.verts.new(p) for p in ((0, 0, 1.48), (0.42, 0.0, 1.3), (0, 0, 1.1))]
f = bm.faces.new(v)
f.material_index = 1
bm.faces.new(list(reversed([bm.verts.new(p.co.copy()) for p in v]))).material_index = 1
bayrak = nesne("KoseBayragi", bm, [m_sopa, m_bayrak], duz=True)
disa_aktar([bayrak], "bayrak.glb")

print("SAHA TAMAM")
