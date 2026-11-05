# Penaltı Ustası (Unity)

Bulutta derlenen basit bir Unity Android oyunu. Topu parmağınla kaleye doğru kaydır, kaleciyi geç. 5 şutta en çok golü at.

## Nasıl derlenir
Her `main` dalına gönderimde GitHub Actions projeyi derler. APK, Actions sekmesinde ilgili çalıştırmanın altında **PenaltiUstasi-APK** olarak indirilir.

## Bir kerelik kurulum (Unity lisansı)
Depo → Settings → Secrets and variables → Actions → New repository secret:
- `UNITY_EMAIL` — Unity hesabının e-postası
- `UNITY_PASSWORD` — Unity hesabının şifresi
- `UNITY_LICENSE` — Unity Hub ile ücretsiz Personal lisansı etkinleştirdikten sonra oluşan `Unity_lic.ulf` dosyasının içeriği
  (Windows: `C:\ProgramData\Unity\Unity_lic.ulf`)

## Dosyalar
- `Assets/Scripts/PenaltyGame.cs` — oyunun kendisi
- `Assets/Editor/BuildScript.cs` — sahneyi kodla kurup APK çıkaran derleme betiği
- `.github/workflows/android.yml` — bulut derleme ayarı
