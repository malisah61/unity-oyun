# Penaltı Ustası 3D (Godot)

Telefonda oynanan 3D penaltı oyunu. Parmağını yukarı doğru kaydır: sağa/sola çekmek yönü,
kaydırma uzunluğu yüksekliği, kaydırma hızı şutun gücünü belirler. Kaydırırken nişan noktaları
topun gideceği yolu gösterir. 5 şutluk seride kaleciyi geç; her golde kaleci daha iyi tahmin eder.

**APK:** https://github.com/malisah61/unity-oyun/releases/download/son-surum/PenaltiUstasi.apk

## Nasıl çalışıyor
- `main.gd` — oyunun tamamı
- `tools/blender/` — Blender betikleri: futbolcu/kaleci dönüştürme, top, kale, tribün, köşe bayrağı
- `assets/modeller/` — Blender'ın ürettiği glb modeller
- `.github/workflows/blender.yml` — Blender'ı bulutta çalıştırıp modelleri üretir
- `.github/workflows/android.yml` — APK'yı derleyip yukarıdaki linke yükler
- `.github/workflows/onizleme.yml` — oyunu bulutta açıp `onizleme/oyun/` ekran görüntülerini alır

## Emeği geçenler (hepsi CC0)
- Karakterler: KayKit Adventurers — Kay Lousberg (kaylousberg.com)
- Çim dokusu ve gökyüzü: Poly Haven (polyhaven.com)
