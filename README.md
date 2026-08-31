# CS 1.6 Otomatik Sistem & userconfig.cfg Optimizasyon Aracı

Bu araç, **Counter-Strike 1.6 (GoldSrc motoru)** için bilgisayarınızın donanımına özel bir `userconfig.cfg` oluşturur ve Windows'ta **input lag'i azaltmaya yönelik** birkaç sistem ayarını otomatik uygular.

Elle yüzlerce satır konsol komutu girmek yerine, script donanımınızı (CPU, GPU, ekran yenileme hızı) otomatik algılar ve size özel bir cfg dosyasını masaüstünüze bırakır.

> ⚠️ **Sadece Windows içindir.** Script; donanım algılama (WMI), sistem ayarları (Windows Registry) ve güç planı (`powercfg`) için Windows'a özel bileşenler kullanır. Linux/macOS'ta çalışmaz.

---

## Bu Araç Ne Yapar?

### 1) `userconfig.cfg` oluşturur
Masaüstünüze, donanımınıza göre hesaplanmış bir `userconfig.cfg` dosyası yazar (ekran Hz'inize göre `fps_max` otomatik hesaplanır). İçerik kategorilere ayrılmıştır:

- **FPS / Çekirdek** — `fps_max`, `gl_vsync`
- **Render / Grafik** — doku kalitesi ve netlik ayarları (aşağıda detaylı açıklama var)
- **Mouse / Input** — ham fare girişi, ivme kapatma, hassasiyet
- **Network** — `rate`, `cl_updaterate`, `cl_cmdrate`, indirme engelleme
- **Prediction / Lag Compensation** — `cl_predict`, `cl_lw`, `cl_lc` (input lag için en kritik kısım)
- **HUD / Konsol** — FPS sayacı, konsol yükünü azaltma
- **Görsel gürültü azaltma** — decal, duman, kovan, kan/gib efektlerini kapatma (rakip görünürlüğü + performans)
- **Ses**
- **Hareket**

Neredeyse tüm ayarlar varsayılan olarak **aktif** gelir. `sensitivity`, `gamma`, `brightness`, `contrast` gibi kişiye/monitöre göre değişen değerler de aktif gelir ama makul varsayılan değerlerle — dosyayı Not Defteri ile açıp kendine göre düzenleyebilirsin.

### 2) Sistem seviyesi input lag ayarları (Yönetici izniyle)
- Güç planını **Yüksek Performans**'a alır
- Windows fare ivmesini (mouse acceleration) kapatır
- Game DVR / arka plan oyun kaydını kapatır

### 3) Geri alma (restore) desteği
Sistem ayarlarını değiştirmeden önce **eski değerleri yedekler** ve masaüstüne `eski_ayarlara_don.ps1` dosyası oluşturur. Bir sorun yaşarsanız bu dosyayı Yönetici olarak çalıştırarak her şeyi eski haline döndürebilirsiniz.

---

## Nasıl Çalıştırılır?

### Yöntem 1 — Tek satır (hızlı)

Yönetici olarak açılmış bir PowerShell penceresine şunu yapıştırıp Enter'a basın:

```powershell
irm https://raw.githubusercontent.com/mert478/cfg/main/optimize_ve_userconfig_v2.ps1 | iex
```

Bu, scripti indirip anında çalıştırır. `userconfig.cfg` dosyası her durumda oluşur.

⚠️ **Not:** Bu yöntemde script bir dosyadan değil doğrudan bellekten çalıştığı için, script kendini otomatik Yönetici izniyle yeniden başlatma adımını atlayabilir. PowerShell'i **baştan Yönetici olarak** açmadıysanız, sistem ayarları (güç planı, fare ivmesi, Game DVR) uygulanmayabilir — sadece cfg dosyası oluşur. Garantili sonuç için PowerShell'i Başlat menüsünden sağ tık → *Yönetici olarak çalıştır* ile açtıktan sonra yukarıdaki komutu çalıştırın.

### Yöntem 2 — İndirip çalıştırma (sistem ayarlarının garanti uygulanması için)

1. Yönetici olarak PowerShell açın.
2. Scripti indirin:
   ```powershell
   irm https://raw.githubusercontent.com/mert478/cfg/main/optimize_ve_userconfig_v2.ps1 -OutFile "$env:USERPROFILE\Desktop\optimize.ps1"
   ```
3. Çalıştırmaya izin verin (tek seferlik, kalıcı bir sistem değişikliği yapmaz):
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
4. Çalıştırın:
   ```powershell
   cd $env:USERPROFILE\Desktop
   .\optimize.ps1
   ```

---

## Oyun İçi Görüntüde Pixelleşme (Duvarlar/Dokular Köşeli Görünüyorsa)

Eğer duvarlar veya dokular bulanık değil de **kareli/bloklu** görünüyorsa, bu doku filtreleme ayarından kaynaklanır. Script varsayılan olarak dokuları **yumuşatan** ayarlarla gelir:

```
gl_texturemode "GL_LINEAR_MIPMAP_LINEAR"
gl_max_size "2048"
gl_round_down "0"
```

Eğer FPS'ten ödün verip daha da eski/düşük donanımlarda performans kazanmak isterseniz, bu üç değeri şu şekilde değiştirebilirsiniz (görüntü daha kareli/pixelli olur ama FPS artabilir):

```
gl_texturemode "GL_NEAREST_MIPMAP_NEAREST"
gl_max_size "512"
gl_round_down "2"
```

Modern bir GPU'nuz varsa (GTX 1060 ve üzeri gibi) bu değişikliğin FPS üzerindeki etkisi GoldSrc motorunda pratikte ihmal edilebilir düzeydedir, o yüzden varsayılan (yumuşatılmış) ayarları kullanmanız önerilir.

---

## Cfg Dosyasını Elle Düzenleme

Dosyayı masaüstünde bulup Not Defteri ile açabilirsiniz. Her satırın yanında `//` ile başlayan bir açıklama var; kişiye özgü değerleri (`sensitivity`, `gamma`, `brightness`, `contrast`, `cl_bob` vb.) kendinize göre değiştirebilirsiniz. Değişiklik sonrası oyunu yeniden başlatmanız gerekir.

---

## Önemli Uyarılar

- **Sadece GoldSrc motoru (CS 1.6 / Half-Life 1) için geçerlidir.** CS2, CS:GO gibi farklı motorlu oyunlarda bu cvar'lar işe yaramaz.
- **Sadece Windows'ta çalışır.** Linux/macOS desteklenmiyor.
- **Bazı ayarlar sunucu tarafından sınırlanabilir.** `rate`, `cl_updaterate`, `cl_cmdrate` gibi değerler sunucunun `sv_` limitlerini aşamaz; client'ta yüksek yazmanız sunucu izin vermiyorsa hiçbir şey değiştirmez.
- **`r_fullbright` bilerek cfg'ye eklenmedi** çünkü çoğu sunucuda admin mod/antihile tarafından tespit edilip yasaklanma riski taşır.
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
