# CS 1.6 Kişisel Optimizasyon Aracı (v4)

**Geliştirici:** Ay Yıldız | Silva
**Topluluk:** [www.ayyildizailesi.com](https://www.ayyildizailesi.com/)

---

**Counter-Strike 1.6 (GoldSrc motoru)** için bilgisayarınıza özel bir `userconfig.cfg` oluşturan ve Windows'ta input lag'i azaltmaya yönelik sistem ayarlarını uygulayan interaktif bir araç.

Her kullanıcının donanımı, interneti ve tercihleri farklı olduğu için bu araç **tek tip bir cfg dosyası dayatmaz** — donanımınızı ölçer, internet hızınızı test eder ve size soru sorarak **kendi bilgisayarınıza özel** bir yapılandırma oluşturur.

> ⚠️ **Sadece Windows içindir.** WMI, Windows Registry ve `powercfg` kullanır; Linux/macOS'ta çalışmaz.

---

## Bu Araç Ne Yapar?

### 1) Donanım Algılama
CPU çekirdek sayısı, RAM miktarı, GPU ve VRAM miktarını otomatik algılar; bunlara göre bir **DÜŞÜK / ORTA / YÜKSEK** donanım seviyesi belirler.

### 2) İnternet Ölçümü
- **Ping testi** (8.8.8.8 ve 1.1.1.1'e) → gecikme profilini belirler, bu `cl_updaterate`/`cl_cmdrate`/`ex_interp` değerlerine yansır.
- **Gerçek indirme hızı testi** (4MB test dosyası indirilip süresi ölçülür) → `rate` değerini gerçek bant genişliğinize göre ayarlar. Ping ile hız (Mbps) birbirinden farklı şeylerdir, bu yüzden ikisi ayrı ayrı ölçülür.

### 3) Kalite Modu Seçimi (Menü)
Script çalışınca size sorar:

- **1) OTOMATİK** — Donanımınıza göre görüntü kalitesi ayarlanır. Zayıf bir bilgisayarda dokular basitleştirilir (pixelleşme normal ve performans için gereklidir), güçlü bir bilgisayarda dokular tam kalitede kalır.
- **2) YÜKSEK KALİTE + REKABETÇİ** — Donanımdan bağımsız olarak en iyi görsel kalite + en iyi isabet/netcode ayarları (`cl_updaterate`/`cl_cmdrate` maksimumda, `ex_interp` minimumda) zorlanır. `rate` yine gerçek internet hızınıza göre otomatik kalır.

### 4) Sistem Optimizasyonu (Onaylı, Yönetici gerekir)
Evet derseniz:
- Güç planını önce **Nihai Performans (Ultimate Performance)** yapmayı dener, bulunamazsa **Yüksek Performans**'a geçer.
- Windows fare ivmesini (mouse acceleration) kapatır.
- Windows Oyun Modu'nu (Game Mode) açar, Game DVR arka plan kaydını kapatır.
- **Scriptleyemediğimiz ama etkili olduğu bilinen ayarlar için ekranda bilgilendirme gösterir** (aşağıda tam liste var).

### 5) Performans Denetimi (Onaylı, Yönetici gerekir)
Evet derseniz:
- En çok CPU/RAM tüketen 8 programı listeler, isterseniz seçtiklerinizi kapatabilirsiniz.
- Windows Defender gerçek zamanlı koruması açıksa üç seçenek sunar:
  1. **Güvenli (önerilen):** Sadece CS 1.6 klasörünü tarama dışı bırakır (koruma açık kalır, sadece oyun dosyaları taranmaz).
  2. **Riskli:** Gerçek zamanlı korumayı tamamen geçici kapatır (açıkça onay ister, "EVET" yazmanız gerekir).
  3. Hiçbir şey yapma.

### 6) Geri Alma (Restore)
Sistem/AV ayarlarında değişiklik yapıldıysa, script masaüstüne **`eski_ayarlara_don.ps1`** dosyası bırakır. Bu dosyayı Yönetici olarak çalıştırarak güç planı, fare, Game DVR ve Defender ayarlarını **eski haline** döndürebilirsiniz.

---

## Nasıl Çalıştırılır?

### CMD veya PowerShell — fark etmez, ikisinde de çalışır

Aşağıdaki tek satırı **CMD'ye** veya **PowerShell'e** yapıştırıp Enter'a basmanız yeterli. Yönetici olarak açık olmasa bile script kendi kendine bir UAC (Yönetici İzni) penceresi açar:

```
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/mert478/cfg/main/optimize_ve_userconfig_v4.ps1 | iex"
```

Bu komut:
1. Scripti indirir ve çalıştırır.
2. Yönetici izniniz yoksa otomatik bir UAC penceresi açar (siz "Evet" derseniz script yönetici olarak devam eder).
3. Size donanım/internet bilgilerinizi gösterir, ardından menüden seçim yapmanızı ister.

### Sadece PowerShell'den (alternatif)

```powershell
irm https://raw.githubusercontent.com/mert478/cfg/main/optimize_ve_userconfig_v4.ps1 | iex
```

---

## Script Neleri OTOMATİKLEŞTİREMEZ? (Dürüst Liste)

Araştırdığınız input lag faktörlerinin bir kısmı Windows/PowerShell'den güvenilir şekilde scriptlenemiyor. Bunlar **script çalışırken ekranda bilgi olarak gösterilir**, ama elle yapmanız gerekir:

| Ayar | Neden Otomatikleştirilemiyor |
|---|---|
| **NVIDIA Reflex** | CS2/Source 2 motoruna özel bir özellik; **CS 1.6 (GoldSrc) bunu hiç desteklemiyor.** Cfg'ye eklemek anlamsız olurdu. |
| **AMD Anti-Lag / NVIDIA Düşük Gecikme Modu** | Sürücü kontrol panelinde bir ayar, resmi bir komut satırı arayüzü yok. |
| **Fare Polling Rate (1000Hz+)** | Üretici yazılımına (Razer Synapse, Logitech G HUB vb.) bağlı, evrensel bir Windows komutu yok. |
| **Tam Ekran / Pencereli Mod** | Bu bir oyun içi grafik ayarı, `userconfig.cfg` üzerinden değil oyunun video menüsünden seçilir. |
| **G-Sync/FreeSync yapılandırması** | Monitör + GPU sürücü ayarı, uygulamaya özel API gerektirir. |
| **Kablolu/Kablosuz fare seçimi** | Donanımsal bir tercih, yazılımla değiştirilemez. |
| **Bufferbloat / QoS (SQM)** | Router seviyesinde bir ayar, Windows'tan yapılamaz. |

V-Sync kapatma tek istisna — bu `userconfig.cfg` içinde `gl_vsync "0"` ile otomatik yapılıyor.

---

## Cfg Dosyasını Elle Düzenleme

Dosya masaüstünde. Not Defteri ile açıp `sensitivity`, `gamma`, `brightness` gibi kişiye özgü değerleri kendinize göre değiştirebilirsiniz. Değişiklik sonrası oyunu yeniden başlatın.

---

## Önemli Uyarılar

- **Sadece GoldSrc motoru (CS 1.6 / Half-Life 1) için geçerlidir.** CS2, CS:GO'da bu cvar'lar işe yaramaz.
- **Sadece Windows'ta çalışır.**
- **`rate`, `cl_updaterate`, `cl_cmdrate` gibi değerler sunucu tarafından sınırlanabilir** (`sv_` limitleri). Client'ta yüksek yazmanız sunucu izin vermiyorsa etkisiz kalır.
- **`r_fullbright` bilerek cfg'ye eklenmedi** — çoğu sunucuda admin mod/antihile tarafından tespit edilip yasaklanma riski taşır.
- **Windows Defender'ı tamamen kapatma seçeneği (Seçenek 2) risklidir.** Sadece geçici olarak, oyun oynarken kullanmanız ve sonrasında `eski_ayarlara_don.ps1` ile geri açmanız önerilir. Mümkünse "Güvenli" seçeneği (sadece oyun klasörünü muaf tutma) kullanın.
- Kurumsal/okul bilgisayarlarında Grup İlkesi (GPO) bazı registry değişikliklerini engelleyebilir; script hatasız şekilde o adımı atlar.
- Kod tamamen açık ve okunabilir durumda — çalıştırmadan önce içeriğini incelemeniz önerilir.

---

## Geri Alma

1. Masaüstünüzdeki `eski_ayarlara_don.ps1` dosyasını bulun.
2. Sağ tık → *Yönetici olarak çalıştır*.

Bu dosya yalnızca sistem optimizasyonu veya performans denetimi adımlarından en az biri **"Evet"** seçildiyse oluşur.

---

## Katkıda Bulunma

Sorun bildirmek veya öneri paylaşmak için [Issues](../../issues) sekmesini kullanabilirsiniz.

## Sorumluluk Reddi

Bu araç eğitim ve topluluk paylaşımı amaçlıdır. Sistem ayarlarında ve güvenlik yazılımında yapılan her değişiklik gibi, kullanmadan önce ne yaptığını anlamanız önerilir. Geliştirici, scriptin kullanımından doğabilecek sorunlardan sorumlu tutulamaz.

---

## Hakkında

Bu araç, **Ay Yıldız | Silva** tarafından **[Ay Yıldız Ailesi](https://www.ayyildizailesi.com/)** topluluğu için geliştirilmiştir. Topluluğumuz hakkında daha fazla bilgi almak, geri bildirim paylaşmak veya bize katılmak için sitemizi ziyaret edebilirsiniz.
