# Penaltı Ustası 3D (Godot)

Telefonda oynanan 3D penaltı oyunu. Ekranda parmağını yukarı doğru kaydır:
yön sağ/sol, kaydırma uzunluğu yüksekliği, hızın da şut gücünü belirler.
5 şutta en çok golü atmaya çalış; her golde kaleci daha iyi tahmin eder.

## APK nasıl alınır
Her `main` gönderiminde GitHub Actions oyunu bulutta derler.
**Actions** sekmesi → son çalıştırma → en altta **PenaltiUstasi-APK** → indir, zip'i aç, APK'yı telefona kur.
(Bilinmeyen kaynaklardan yüklemeye izin vermen gerekebilir.)

Lisans ya da bilgisayara kurulum gerekmez.

## Dosyalar
- `main.gd` — oyunun tamamı (sahne kodla kuruluyor)
- `main.tscn`, `project.godot` — Godot proje dosyaları
- `export_presets.cfg` — Android dışa aktarma ayarı
- `.github/workflows/android.yml` — bulut derleme
