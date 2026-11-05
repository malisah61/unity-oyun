"""KayKit karakterini futbolcuya / kaleciye çevirir.

Kullanım:
  blender -b --python tools/blender/futbolcu.py -- <girdi.glb> <cikti.glb> <onizleme_on_ek> <forma> <sort> <tozluk> <krampon> <kaleci:0/1>

- Silah, pelerin, şapka gibi deri bağlı olmayan parçaları siler.
- Gövde, kol ve bacak yüzlerini yüksekliğe göre forma / şort / ten / tozluk / krampon / eldiven olarak boyar.
- Futbolda kullanılan animasyonları tutar, gerisini atar (dosya küçülür).
"""
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import ortak  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
GIRDI, CIKTI, ONIZLEME = argv[0], argv[1], argv[2]
FORMA, SORT, TOZLUK, KRAMPON = (ortak.hex_renk(x) for x in argv[3:7])
KALECI = argv[7] == "1"
BAS_KAYNAGI = argv[8] if len(argv) > 8 else ""

TUT = {
    "Idle", "Unarmed_Idle", "Running_A", "Walking_A", "Unarmed_Melee_Attack_Kick",
    "Dodge_Left", "Dodge_Right", "Cheer", "Hit_A", "Jump_Full_Short", "Block", "Blocking",
    "Death_A", "Lie_StandUp", "Interact",
}

ortak.sahneyi_temizle()
bpy.ops.import_scene.gltf(filepath=GIRDI)

# --- Aksesuarları sil ---
sil = [o for o in bpy.data.objects if o.type == "MESH" and not any(m.type == "ARMATURE" for m in o.modifiers)]
for o in sil:
    print("siliniyor:", o.name)
    bpy.data.objects.remove(o, do_unlink=True)

arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
print("tüm animasyon adları:", [a.name for a in bpy.data.actions][:12], "...")

# --- İsteğe bağlı: başı başka karakterden al (aynı iskelet) ---
if BAS_KAYNAGI:
    once_nesne = set(bpy.data.objects)
    once_anim = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=BAS_KAYNAGI)
    yeni = [o for o in bpy.data.objects if o not in once_nesne]
    yeni_bas = next(o for o in yeni if o.type == "MESH" and o.name.endswith("_Head")
                    and any(m.type == "ARMATURE" for m in o.modifiers))
    eski_bas = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.endswith("_Head") and o not in yeni)
    yeni_bas.parent = arm
    yeni_bas.matrix_parent_inverse = eski_bas.matrix_parent_inverse.copy()
    yeni_bas.matrix_basis = eski_bas.matrix_basis.copy()
    for m in yeni_bas.modifiers:
        if m.type == "ARMATURE":
            m.object = arm
    bpy.data.objects.remove(eski_bas, do_unlink=True)
    for o in yeni:
        if o is not yeni_bas:
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        if a not in once_anim:
            bpy.data.actions.remove(a)
    print("baş değiştirildi:", yeni_bas.name)
parcalar = {o.name.split("_", 1)[-1]: o for o in bpy.data.objects if o.type == "MESH"}
print("parçalar:", list(parcalar))

# --- Malzemeler ---
TEN = ortak.hex_renk("#e0ac86")
m_forma = ortak.malzeme("Forma", FORMA, 0.75)
m_sort = ortak.malzeme("Sort", SORT, 0.75)
m_tozluk = ortak.malzeme("Tozluk", TOZLUK, 0.8)
m_krampon = ortak.malzeme("Krampon", KRAMPON, 0.45)
m_ten = ortak.malzeme("Ten", TEN, 0.6)
m_eldiven = ortak.malzeme("Eldiven", ortak.hex_renk("#f2f2f2"), 0.5)
m_serit = ortak.malzeme("Serit", ortak.hex_renk("#ffffff"), 0.7)


def dunya_noktalari(o):
    mw = o.matrix_world
    return [mw @ v.co for v in o.data.vertices]


def boya(o, secici):
    """secici(merkez_dunya, t_bilgisi) -> malzeme. Malzemeyi yüzlere atar."""
    me = o.data
    me.materials.clear()
    liste = []
    noktalar = dunya_noktalari(o)
    for p in me.polygons:
        merkez = sum((noktalar[i] for i in p.vertices), Vector()) / len(p.vertices)
        m = secici(merkez)
        if m.name not in [x.name for x in liste]:
            liste.append(m)
            me.materials.append(m)
        p.material_index = [x.name for x in liste].index(m.name)


def kapsam(o):
    n = dunya_noktalari(o)
    mn = Vector((min(v.x for v in n), min(v.y for v in n), min(v.z for v in n)))
    mx = Vector((max(v.x for v in n), max(v.y for v in n), max(v.z for v in n)))
    return mn, mx


# Gövde: alt kısım şort, üst kısım forma
if "Body" in parcalar:
    o = parcalar["Body"]
    mn, mx = kapsam(o)
    h = mx.z - mn.z

    def govde(c):
        t = (c.z - mn.z) / h
        if t < 0.26:
            return m_sort
        return m_forma
    boya(o, govde)

# Kollar: omuzdan ele doğru
for ad in ("ArmLeft", "ArmRight"):
    if ad not in parcalar:
        continue
    o = parcalar[ad]
    mn, mx = kapsam(o)
    boyut = mx - mn
    eksen = max(range(3), key=lambda i: boyut[i])

    def kol(c, mn=mn, mx=mx, eksen=eksen):
        if eksen == 2:  # kollar aşağı sarkıyorsa
            t = (mx.z - c.z) / (mx.z - mn.z)
        else:  # T-poz: merkezden dışa
            uc_a, uc_b = abs(mn[eksen]), abs(mx[eksen])
            ic, dis = min(uc_a, uc_b), max(uc_a, uc_b)
            t = (abs(c[eksen]) - ic) / max(dis - ic, 1e-4)
        if KALECI:
            return m_forma if t < 0.62 else m_eldiven
        if t < 0.38:
            return m_forma
        return m_ten
    boya(o, kol)

# Bacaklar: aşağıdan yukarı
for ad in ("LegLeft", "LegRight"):
    if ad not in parcalar:
        continue
    o = parcalar[ad]
    mn, mx = kapsam(o)

    def bacak(c, mn=mn, mx=mx):
        t = (c.z - mn.z) / (mx.z - mn.z)
        if t < 0.17:
            return m_krampon
        if t < 0.55:
            return m_tozluk
        if t < 0.66:
            return m_ten
        return m_sort
    boya(o, bacak)

# --- Animasyonları ayıkla ---
def taban_ad(ad):
    """'Cheer', 'Rig|Cheer', 'Cheer_Rig', 'Cheer.001' gibi adlardan temel animasyon adını bulur."""
    temiz = ad.split("|")[-1].split(".")[0]
    for k in sorted(TUT, key=len, reverse=True):
        if temiz == k:
            return k
    for k in sorted(TUT, key=len, reverse=True):
        if temiz.startswith(k + "_") and not any(temiz.startswith(k2) for k2 in TUT if len(k2) > len(k)):
            return k
    return None


gorulen = set()
for a in list(bpy.data.actions):
    k = taban_ad(a.name)
    if k is None or k in gorulen:
        bpy.data.actions.remove(a)
    else:
        gorulen.add(k)
for a in bpy.data.actions:
    a.name = taban_ad(a.name)
print("kalan animasyonlar:", [a.name for a in bpy.data.actions])
if arm.animation_data:
    for tr in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(tr)

# --- Dışa aktar ---
os.makedirs(os.path.dirname(CIKTI), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=CIKTI, export_format="GLB", export_animation_mode="ACTIONS",
    export_yup=True, export_apply=False,
)
print("dışa aktarıldı:", CIKTI, os.path.getsize(CIKTI) // 1024, "KB")

# --- Önizleme ---
ortak.render_ayarla()
zemin = bpy.data.meshes.new("Zemin")
zemin.from_pydata([(-5, -5, 0), (5, -5, 0), (5, 5, 0), (-5, 5, 0)], [], [(0, 1, 2, 3)])
zo = bpy.data.objects.new("Zemin", zemin)
zo.data.materials.append(ortak.malzeme("Cim", ortak.hex_renk("#3f8f3a"), 0.9))
bpy.context.scene.collection.objects.link(zo)

tum_mn = Vector((min(kapsam(o)[0].x for o in parcalar.values()), 0, min(kapsam(o)[0].z for o in parcalar.values())))
tum_mx = Vector((0, 0, max(kapsam(o)[1].z for o in parcalar.values())))
boy = tum_mx.z - tum_mn.z
hedef = (0, 0, tum_mn.z + boy * 0.5)
print("karakter boyu:", round(boy, 3))

if not arm.animation_data:
    arm.animation_data_create()
for i, (anim, oran, konum) in enumerate([
    (None, 0, (boy * 1.4, -boy * 2.6, boy * 0.75)),
    (None, 0, (-boy * 1.2, boy * 2.6, boy * 0.75)),
    ("Unarmed_Melee_Attack_Kick", 0.45, (boy * 2.6, -boy * 1.2, boy * 0.7)),
    ("Dodge_Left", 0.45, (0, -boy * 3.0, boy * 0.7)),
    ("Cheer", 0.5, (boy * 1.0, -boy * 2.8, boy * 0.7)),
]):
    act = next((a for a in bpy.data.actions if taban_ad(a.name) == (anim or "Idle")), None)
    arm.animation_data.action = act
    if act:
        s, e = act.frame_range
        bpy.context.scene.frame_set(int(s + (e - s) * oran))
    ortak.kamera(konum, hedef, lens=50)
    ortak.render(f"{ONIZLEME}_{i}_{anim or 'duz'}.png")

for a in bpy.data.actions:
    print("anim", a.name, tuple(a.frame_range))
