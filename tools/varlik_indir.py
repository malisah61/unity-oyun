"""GitHub Actions üzerinde çalışır: ücretsiz (CC0) 3D varlıkları indirip assets/ altına koyar."""
import io, json, os, re, sys, urllib.request, zipfile

UA = {"User-Agent": "unity-oyun-asset-fetch/1.0"}
OUT = "assets"
report = []

def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r:
        return r.read()

# ---------- Kenney (CC0) ----------
KENNEY = sys.argv[1].split(",") if len(sys.argv) > 1 and sys.argv[1] else [
    "mini-characters", "animated-characters-2", "animated-characters-1",
    "blocky-characters", "mini-arena", "sports-pack", "nature-kit",
]
KEEP = (".glb", ".gltf", ".bin", ".png", ".txt")
for name in KENNEY:
    try:
        page = get(f"https://kenney.nl/assets/{name}").decode("utf-8", "ignore")
        links = re.findall(r'https://kenney\.nl/media/pages/assets/[^"\']+\.zip', page)
        if not links:
            report.append(f"kenney/{name}: zip linki yok"); continue
        z = zipfile.ZipFile(io.BytesIO(get(links[0])))
        names = z.namelist()
        glbs = [n for n in names if n.lower().endswith((".glb", ".gltf"))]
        report.append(f"kenney/{name}: {len(names)} dosya, {len(glbs)} glb/gltf; örnek: {glbs[:6]}")
        if not glbs:
            continue
        for n in names:
            low = n.lower()
            if not low.endswith(KEEP) or "/fbx" in low or "/obj" in low or "preview" in low or "sample" in low:
                continue
            if low.endswith(".png") and "texture" not in low and "colormap" not in low and "skin" not in low:
                continue
            dst = os.path.join(OUT, "kenney", name, n.split("/", 1)[-1] if "/" in n else n)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "wb") as f:
                f.write(z.read(n))
    except Exception as e:
        report.append(f"kenney/{name}: HATA {e}")

# ---------- Poly Haven (CC0) ----------
try:
    tex = json.loads(get("https://api.polyhaven.com/assets?t=textures&c=grass"))
    report.append("polyhaven çim dokuları: " + ", ".join(sorted(tex)[:40]))
    hdr = json.loads(get("https://api.polyhaven.com/assets?t=hdris&c=outdoor"))
    sky = [k for k in hdr if any(w in k for w in ("stadium", "pitch", "field", "sky", "meadow"))]
    report.append("polyhaven gökyüzü adayları: " + ", ".join(sorted(sky)[:40]))
    wanted_tex = os.environ.get("PH_TEX", "")
    wanted_hdr = os.environ.get("PH_HDR", "")
    for tid in filter(None, wanted_tex.split(",")):
        files = json.loads(get(f"https://api.polyhaven.com/files/{tid}"))
        for key in ("Diffuse", "nor_gl", "Rough"):
            if key in files:
                u = files[key]["1k"]["jpg"]["url"]
                dst = os.path.join(OUT, "polyhaven", tid, f"{key}.jpg")
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                open(dst, "wb").write(get(u))
        report.append(f"polyhaven doku indirildi: {tid}")
    for hid in filter(None, wanted_hdr.split(",")):
        files = json.loads(get(f"https://api.polyhaven.com/files/{hid}"))
        u = files["tonemapped"]["url"] if "tonemapped" in files else files["hdri"]["1k"]["hdr"]["url"]
        ext = u.rsplit(".", 1)[-1]
        dst = os.path.join(OUT, "polyhaven", hid, f"sky.{ext}")
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        open(dst, "wb").write(get(u))
        report.append(f"polyhaven gökyüzü indirildi: {hid}")
except Exception as e:
    report.append(f"polyhaven: HATA {e}")

os.makedirs(OUT, exist_ok=True)
open(os.path.join(OUT, "INDIRME_RAPORU.txt"), "w").write("\n".join(report) + "\n")
print("\n".join(report))
