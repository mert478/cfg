# CS 1.6 Otomatik Sistem & userconfig.cfg Optimizasyon Aracı

Bu araç, **Counter-Strike 1.6 (GoldSrc motoru)** için bilgisayarınızın donanımına özel bir `userconfig.cfg` oluşturur ve Windows'ta **input lag'i azaltmaya yönelik** birkaç sistem ayarını otomatik uygular.

Elle yüzlerce satır konsol komutu girmek yerine, script donanımınızı (CPU, GPU, ekran yenileme hızı) otomatik algılar ve size özel bir cfg dosyasını masaüstünüze bırakır.

---

## Bu Araç Ne Yapar?

### 1) `userconfig.cfg` oluşturur
Masaüstünüze, donanımınıza göre hesaplanmış bir `userconfig.cfg` dosyası yazar. İçerik kategorilere ayrılmıştır:

- **FPS / Çekirdek** — `fps_max`, `gl_vsync` (ekran Hz'inize göre otomatik hesaplanır)
- **Render / Grafik** — gereksiz görsel yükü azaltan ayarlar (`gl_smoothmodel`, `gl_spriteblend`, `gl_playermip` vb.)
- **Mouse / Input** — ham fare girişi, ivme kapatma
- **Network** — `rate`, `cl_updaterate`, `cl_cmdrate`, indirme engelleme
- **Prediction / Lag Compensation** — `cl_predict`, `cl_lw`, `cl_lc` (input lag için en kritik kısım)
- **HUD / Konsol** — gereksiz konsol/HUD yükünü azaltma
- **Görsel gürültü azaltma** — decal, duman, kovan efektlerini kapatma (rakip görünürlüğü + performans)
- **Ses**
- **Hareket**

### 2) Sistem seviyesi input lag ayarları (Yönetici izniyle)
- Güç planını **Yüksek Performans**'a alır
- Windows fare ivmesini (mouse acceleration) kapatır
- Game DVR / arka plan oyun kaydını kapatır

### 3) Geri alma (restore) desteği
Sistem ayarlarını değiştirmeden önce **eski değerleri yedekler** ve masaüstüne `eski_ayarlara_don.ps1` dosyası oluşturur. Bir sorun yaşarsanız bu dosyayı Yönetici olarak çalıştırarak her şeyi eski haline döndürebilirsiniz.

---

## Nasıl Çalıştırılır?

### Yöntem 1 — İndirip çalıştırma (ÖNERİLEN)

1. Yönetici olarak PowerShell açın (Başlat menüsüne "PowerShell" yazın, sağ tık → *Yönetici olarak çalıştır*).
2. Şu komutla scripti indirin:
   ```powershell
   irm https://raw.githubusercontent.com/mert478/cfg/main/optimize_ve_userconfig_v2.ps1 -OutFile "$env:USERPROFILE\Desktop\optimize.ps1"
   ```
3. Script'in çalışmasına izin verin (tek seferlik, kalıcı bir sistem değişikliği yapmaz):
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
4. Çalıştırın:
   ```powershell
   cd $env:USERPROFILE\Desktop
   .\optimize.ps1
   ```

> **Not:** Script kendini otomatik olarak Yönetici izniyle yeniden başlatmaya çalışır, bu yüzden normal (yönetici olmayan) bir PowerShell'den de çalıştırabilirsiniz — bir UAC penceresi açılıp onay isteyecektir.

### Yöntem 2 — Tek satırlık hızlı çalıştırma

```powershell
irm https://raw.githubusercontent.com/mert478/cfg/main/optimize_ve_userconfig_v2.ps1 | iex
```

⚠️ Bu yöntemde script bir dosyadan değil doğrudan bellekten çalıştığı için **otomatik Yönetici yeniden başlatma özelliği çalışmayabilir**. Bu durumda script sadece `userconfig.cfg` dosyasını oluşturur, sistem ayarlarını (güç planı, fare ivmesi, Game DVR) atlar. Sistem ayarlarının da uygulanmasını istiyorsanız **Yöntem 1**'i kullanın ve PowerShell'i baştan Yönetici olarak açın.

---

## Cfg Dosyasını Elle Düzenleme

`userconfig.cfg` içinde `##` ile başlayan satırlar **kişisel tercih** ayarlarıdır (fare hassasiyeti, ekran parlaklığı, kan efekti gibi). Bunlar bilerek kapalı bırakıldı çünkü herkese uyan "doğru" bir değerleri yok. Kullanmak isterseniz dosyayı bir metin editörüyle açıp başındaki `##` işaretini silip değeri kendinize göre ayarlayın.

---

## Önemli Uyarılar

- **Sadece GoldSrc motoru (CS 1.6 / Half-Life 1) için geçerlidir.** CS2, CS:GO gibi farklı motorlu oyunlarda bu cvar'lar işe yaramaz.
- **Bazı ayarlar sunucu tarafından sınırlanabilir.** `rate`, `cl_updaterate`, `cl_cmdrate` gibi değerler sunucunun `sv_` limitlerini aşamaz; client'ta yüksek yazmanız sunucu izin vermiyorsa hiçbir şey değiştirmez.
- **`r_fullbright` gibi bazı cvar'lar cfg'de bilerek yorum satırına alındı** çünkü çoğu sunucuda admin mod/античит tarafından tespit edilip yasaklanma riski taşır. Kendi sorumluluğunuzdadır.
- Script, Windows registry'sinde (fare, güç planı, Game DVR) değişiklik yapar. Kurumsal/okul bilgisayarlarında Grup İlkesi (GPO) bu değişiklikleri engelleyebilir; bu durumda script hatasız şekilde o adımı atlar.
- Kod tamamen açık ve okunabilir durumda — çalıştırmadan önce içeriğini incelemeniz önerilir.

---

## Geri Alma

Sistem ayarlarını eski haline döndürmek için:
1. Masaüstünüzdeki `eski_ayarlara_don.ps1` dosyasını bulun.
2. Sağ tık → *Yönetici olarak çalıştır*.

Bu dosya yalnızca script çalıştırıldıktan **sonra** oluşur (script çalışmadan önceki değerlerinizi yedekler).

---

## Katkıda Bulunma

Sorun bildirmek veya öneri paylaşmak için [Issues](../../issues) sekmesini kullanabilirsiniz.

## Sorumluluk Reddi

Bu araç eğitim ve topluluk paylaşımı amaçlıdır. Sistem ayarlarında yapılan her değişiklik gibi, kullanmadan önce ne yaptığını anlamanız önerilir. Geliştirici, scriptin kullanımından doğabilecek sorunlardan sorumlu tutulamaz.
