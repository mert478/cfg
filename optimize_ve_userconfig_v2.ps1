# =========================================================
#  Otomatik Donanim Algilama + userconfig.cfg Olusturucu
#  + Input Lag Azaltma Sistem Ayarlari
#  Surum: 2.0 (Topluluk / Genel Dagitim Surumu)
#
#  Bu script:
#   - Sisteminizi otomatik Yonetici olarak yeniden baslatir (gerekliyse)
#   - Gercek/aktif GPU'yu sanal adaptorlerden ayirt ederek secer
#   - Guc plani, fare ivmesi, Game DVR ayarlarini degistirir
#   - Degisiklik yapmadan ONCE eski degerleri yedekler (restore.ps1 olusturur)
# =========================================================

# ---------------------------------------------------------
#  0) Kendini otomatik Yonetici olarak yeniden baslat
# ---------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Yonetici izni gerekiyor, script yeniden baslatiliyor..." -ForegroundColor Yellow
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        exit
    } catch {
        Write-Host "[UYARI] Yonetici olarak yeniden baslatilamadi. Script kisitli modda (sadece cfg dosyasi) devam edecek." -ForegroundColor Yellow
    }
}

Write-Host "Sistem bilgileri toplaniyor..." -ForegroundColor Cyan

# ---------------------------------------------------------
#  1) CPU bilgisi
# ---------------------------------------------------------
try {
    $cpuInfo = Get-CimInstance Win32_Processor -ErrorAction Stop
    $cpu = if ($cpuInfo -is [array]) { $cpuInfo[0].Name } else { $cpuInfo.Name }
} catch {
    Write-Host "[UYARI] CPU bilgisi okunamadi." -ForegroundColor Yellow
    $cpu = "Bilinmiyor"
}

# ---------------------------------------------------------
#  2) GPU bilgisi - sanal/hayali adaptorleri disla
# ---------------------------------------------------------
$virtualGpuPatterns = @(
    "Basic Render", "Basic Display", "Remote Desktop", "DisplayLink",
    "Virtual", "Meta Virtual Monitor", "IDD", "Parsec", "TeamViewer",
    "RDPUDD", "VNC", "Citrix", "Hyper-V"
)

try {
    $allGpus = Get-CimInstance Win32_VideoController -ErrorAction Stop
} catch {
    $allGpus = $null
}

$activeGpus = $allGpus | Where-Object {
    $gpuName = $_.Name
    $isVirtual = $false
    foreach ($pattern in $virtualGpuPatterns) {
        if ($gpuName -match [regex]::Escape($pattern)) { $isVirtual = $true; break }
    }
    ($_.CurrentRefreshRate -gt 0) -and ($_.CurrentHorizontalResolution -gt 0) -and (-not $isVirtual)
}

if (-not $activeGpus) {
    Write-Host "[UYARI] Gercek/aktif ekran karti tespit edilemedi, varsayilan degerler kullaniliyor." -ForegroundColor Yellow
    $gpu = "Bilinmiyor"
    $hz = 60
}
elseif ($activeGpus -is [array]) {
    $primary = $activeGpus | Sort-Object -Property AdapterRAM -Descending | Select-Object -First 1
    $gpu = $primary.Name
    $hz = $primary.CurrentRefreshRate
    Write-Host "[BILGI] Birden fazla aktif GPU bulundu, ana GPU olarak '$gpu' secildi." -ForegroundColor Yellow
}
else {
    $gpu = $activeGpus.Name
    $hz = $activeGpus.CurrentRefreshRate
}

# ---------------------------------------------------------
#  3) Hz guvenlik kontrolu + fps hesaplama (float hatasiz)
# ---------------------------------------------------------
if (-not $hz -or $hz -le 0 -or $hz -gt 1000) {
    Write-Host "[UYARI] Yenileme hizi guvenilir okunamadi (deger: $hz), 60 Hz varsayilan kullaniliyor." -ForegroundColor Yellow
    $hz = 60
}

$fps = [math]::Round(($hz - 0.5), 1)

Write-Host "CPU : $cpu"
Write-Host "GPU : $gpu"
Write-Host "Hz  : $hz"
Write-Host "FPS Limiti: $fps"

# =========================================================
#  4) userconfig.cfg olustur
# =========================================================
$cfg = @"
// =========================================================
// Hardware: $cpu | $gpu | $hz Hz
// Olusturulma Tarihi: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
//
// NOT: ## ile baslayan satirlar KISISEL TERCIH ayarlaridir
// (hassasiyet, crosshair, ekran parlakligi, kan/gore vb.)
// Bunlar bilinerek AKTIF EDILMEDI, cunku dogru "ortak" degerleri yok.
// Kullanmak icin basindaki ## isaretini silip degeri kendine gore ayarla.
//
// NOT 2: Bircok cvar (rate, cl_updaterate, cl_cmdrate, fps_max vb.)
// sunucu tarafindan sv_ limitleriyle KISITLANABILIR. Client'ta yuksek
// deger yazman, sunucu izin vermiyorsa hicbir sey degistirmez.
// =========================================================

// --- FPS / Cekirdek ---
fps_max "$fps"
fps_override "1"
gl_vsync "0"

// --- Render / Grafik ---
gl_ansio "0"
gl_fog "0"
gl_smoothmodel "0"
gl_spriteblend "0"
gl_polyoffset "0.1"
gl_flipmatrix "0"
gl_max_size "512"
gl_playermip "2"
gl_round_down "2"
r_mirroralpha "0"
r_dynamic "0"
## gl_texturemode "GL_NEAREST_MIPMAP_NEAREST"   // en hizli ama en dusuk kalite doku; "GL_LINEAR_MIPMAP_LINEAR" daha net ama daha yavas
## r_fullbright "1"        // haritayi tam aydinlatir, GORSEL AVANTAJ sayilabilir - COGU SUNUCUDA YASAK / admin mod tarafindan tespit edilir, ac RISK SENDE
## gamma "3"                // ekran parlakligi, kisiye/monitore gore degisir
## brightness "2"           // ekran parlakligi, kisiye/monitore gore degisir
## contrast "1"             // ekran kontrasti, kisiye/monitore gore degisir

// --- Mouse / Input ---
m_rawinput "1"
m_filter "0"
m_customaccel "0"
m_mousethread_sleep "0"
## sensitivity "3.0"              // fare hassasiyeti - TAMAMEN KISISEL, herkese ayni deger yanlis olur
## zoom_sensitivity_ratio "1.0"   // scope/zoom hassasiyet orani - kisisel

// --- Network ---
rate "100000"
cl_cmdrate "101"
cl_updaterate "101"
ex_interp "0.01"
cl_cmdbackup "2"
cl_resend "1.5"
cl_allowdownload "0"
cl_allowupload "0"
cl_download_ingame "0"
cl_downloadfilter "none"

// --- Prediction / Lag Compensation (input lag icin KRITIK) ---
cl_predict "1"
cl_lw "1"
cl_lc "1"

// --- HUD / Konsol ---
developer "0"
cl_showpos "0"
net_graph "0"
## cl_showfps "1"           // ekranda FPS sayacini gosterir, performans olcumu icin ac istersen

// --- Gorsel gurultuyu azalt (rakip gorunurlugu + performans) ---
hpk_maxsize "0"
cl_corpsestay "0"
max_shells "0"
max_smokepuffs "0"
mp_decals "0"
r_decals "0"
## violence_ablood "0"     // kan efekti kapatir, bazi oyuncular vurus geri bildirimi icin acik tutar - kisisel tercih
## violence_agibs "0"      // "gib" (parcalanma) efekti kapatir - kisisel tercih

// --- Ses ---
_snd_mixahead "0.05"
S_ENABLE_MMX "1"
voice_enable "0"
## snd_mute_losefocus "0"  // alt-tab yapinca sesi susturmaz, adim sesi takibi icin bazilari kullanir
## MP3Volume "0"           // oyun ici radyo/muzik sesi - kisisel tercih
## suitvolume "0"          // HEV suit uyari sesi seviyesi - kisisel tercih

// --- Hareket ---
cl_vsmoothing "0"
cl_sidespeed "999"
cl_backspeed "999"
cl_forwardspeed "999"
## cl_bob "0.01"            // view bobbing miktari - kisisel tercih, bazilari 0 yapar
## cl_bobcycle "0.8"        // view bobbing hizi - kisisel tercih

echo "=== FULL SYSTEM USERCONFIG LOADED (v2 - genisletilmis) ==="
"@

try {
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $cfgPath = Join-Path $desktopPath "userconfig.cfg"
    Set-Content -Path $cfgPath -Value $cfg -Encoding Ascii -ErrorAction Stop
    Write-Host "`n[BASARILI] userconfig.cfg olusturuldu: $cfgPath" -ForegroundColor Green
} catch {
    Write-Host "`n[HATA] userconfig.cfg yazilamadi (yazma izni sorunu olabilir): $_" -ForegroundColor Red
}

# =========================================================
#  5) Input Lag Azaltma - Sistem Seviyesi Ayarlar (Yonetici gerekir)
# =========================================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "`n[BILGI] Yonetici yetkisi yok, sistem seviyesi ayarlar atlanyor." -ForegroundColor Yellow
}
else {
    Write-Host "`nSistem seviyesi ayarlar uygulaniyor (eski degerler once yedeklenecek)..." -ForegroundColor Cyan

    $restoreLines = @()
    $restoreLines += "# Bu script, optimize_ve_userconfig_v2.ps1 tarafindan degistirilen ayarlari geri alir."
    $restoreLines += "# Yonetici olarak calistirin."
    $restoreLines += ""

    # --- 5a) Guc plani ---
    try {
        $currentScheme = (powercfg -getactivescheme) -replace '.*GUID: ([a-f0-9\-]+).*', '$1'
        $restoreLines += "powercfg -setactive $currentScheme"

        $result = powercfg -setactive SCHEME_MIN 2>&1
        if ($LASTEXITCODE -ne 0) {
            $highPerfScheme = powercfg -list | Select-String -Pattern "High performance|Yüksek Performans" | Select-Object -First 1
            if ($highPerfScheme) {
                $guid = ($highPerfScheme -replace '.*Power Scheme GUID: ([a-f0-9\-]+).*', '$1')
                powercfg -setactive $guid
                Write-Host "[OK] Guc plani 'Yuksek Performans' olarak ayarlandi (isimle bulundu)." -ForegroundColor Green
            } else {
                Write-Host "[UYARI] Bu sistemde 'Yuksek Performans' guc plani bulunamadi, atlaniyor." -ForegroundColor Yellow
            }
        } else {
            Write-Host "[OK] Guc plani 'Yuksek Performans' olarak ayarlandi." -ForegroundColor Green
        }
    } catch {
        Write-Host "[HATA] Guc plani ayarlanamadi: $_" -ForegroundColor Red
    }

    # --- 5b) Fare hizlanmasini kapat ---
    try {
        $mp = "HKCU:\Control Panel\Mouse"
        $oldSpeed = (Get-ItemProperty -Path $mp -Name MouseSpeed -ErrorAction SilentlyContinue).MouseSpeed
        $oldT1 = (Get-ItemProperty -Path $mp -Name MouseThreshold1 -ErrorAction SilentlyContinue).MouseThreshold1
        $oldT2 = (Get-ItemProperty -Path $mp -Name MouseThreshold2 -ErrorAction SilentlyContinue).MouseThreshold2

        $restoreLines += "Set-ItemProperty -Path '$mp' -Name MouseSpeed -Value '$oldSpeed'"
        $restoreLines += "Set-ItemProperty -Path '$mp' -Name MouseThreshold1 -Value '$oldT1'"
        $restoreLines += "Set-ItemProperty -Path '$mp' -Name MouseThreshold2 -Value '$oldT2'"

        Set-ItemProperty -Path $mp -Name "MouseSpeed" -Value "0" -Force
        Set-ItemProperty -Path $mp -Name "MouseThreshold1" -Value "0" -Force
        Set-ItemProperty -Path $mp -Name "MouseThreshold2" -Value "0" -Force
        Write-Host "[OK] Fare ivmelenmesi kapatildi." -ForegroundColor Green
    } catch {
        Write-Host "[HATA] Fare ayarlari degistirilemedi: $_" -ForegroundColor Red
    }

    # --- 5c) Game DVR / Game Bar kapat ---
    try {
        $gcs = "HKCU:\System\GameConfigStore"
        if (-not (Test-Path $gcs)) { New-Item -Path $gcs -Force | Out-Null }
        $oldDvr = (Get-ItemProperty -Path $gcs -Name GameDVR_Enabled -ErrorAction SilentlyContinue).GameDVR_Enabled
        if ($null -eq $oldDvr) { $oldDvr = 1 }
        $restoreLines += "if (-not (Test-Path '$gcs')) { New-Item -Path '$gcs' -Force | Out-Null }"
        $restoreLines += "Set-ItemProperty -Path '$gcs' -Name GameDVR_Enabled -Value $oldDvr -Force"
        Set-ItemProperty -Path $gcs -Name "GameDVR_Enabled" -Value 0 -Force

        $gb = "HKCU:\Software\Microsoft\GameBar"
        if (-not (Test-Path $gb)) { New-Item -Path $gb -Force | Out-Null }
        $oldAgm = (Get-ItemProperty -Path $gb -Name AutoGameModeEnabled -ErrorAction SilentlyContinue).AutoGameModeEnabled
        if ($null -eq $oldAgm) { $oldAgm = 1 }
        $restoreLines += "if (-not (Test-Path '$gb')) { New-Item -Path '$gb' -Force | Out-Null }"
        $restoreLines += "Set-ItemProperty -Path '$gb' -Name AutoGameModeEnabled -Value $oldAgm -Force"
        Set-ItemProperty -Path $gb -Name "AutoGameModeEnabled" -Value 1 -Force

        Write-Host "[OK] Game DVR arka plan kaydi kapatildi." -ForegroundColor Green
    } catch {
        Write-Host "[HATA] Game Bar ayarlari degistirilemedi: $_" -ForegroundColor Red
    }

    try {
        $restorePath = Join-Path ([Environment]::GetFolderPath('Desktop')) "eski_ayarlara_don.ps1"
        Set-Content -Path $restorePath -Value ($restoreLines -join "`r`n") -Encoding UTF8 -ErrorAction Stop
        Write-Host "[BILGI] Eski ayarlara donmek icin masaustundeki 'eski_ayarlara_don.ps1' dosyasini Yonetici olarak calistirabilirsiniz." -ForegroundColor Cyan
    } catch {
        Write-Host "[UYARI] Geri alma (restore) dosyasi olusturulamadi." -ForegroundColor Yellow
    }

    Write-Host "`n[TAMAMLANDI] Sistem seviyesi ayarlar uygulandi. Bazi degisiklikler icin yeniden baslatma onerilir." -ForegroundColor Green
}

Write-Host "`n=== ISLEM TAMAMLANDI ===" -ForegroundColor Cyan
Write-Host "Devam etmek icin bir tusa basin..."
[void][System.Console]::ReadKey($true)
