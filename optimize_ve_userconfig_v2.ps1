# =========================================================
#  Otomatik Donanim Algilama + userconfig.cfg Olusturucu
#  + Input Lag Azaltma Sistem Ayarlari
#  Surum: 3.0 (Dogrulanmis cvar'lar + Donanim Profili + Ping Bazli Network)
#
#  Bu script:
#   - Sisteminizi otomatik Yonetici olarak yeniden baslatir (gerekliyse)
#   - Gercek/aktif GPU'yu sanal adaptorlerden ayirt ederek secer
#   - CPU cekirdek sayisi, RAM ve VRAM'e gore DUSUK/ORTA/YUKSEK donanim profili secer
#   - Internet gecikmesini (ping) olcup network cvar'larini otomatik ayarlar
#   - Guc plani, fare ivmesi, Game DVR ayarlarini degistirir
#   - Degisiklik yapmadan ONCE eski degerleri yedekler (restore.ps1 olusturur)
#
#  NOT (v3): Asagidaki cvar'lar gercek oyun testinde "Unknown command" verdigi
#  icin cfg'den CIKARILDI: gl_smoothmodel, gl_playermip, contrast, cl_downloadfilter,
#  cl_predict, cl_showpos, S_ENABLE_MMX (yerine dogrulanmis r_mmx kullanildi),
#  snd_mute_losefocus.
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
#  1) CPU bilgisi (isim + cekirdek sayisi)
# ---------------------------------------------------------
try {
    $cpuInfo = Get-CimInstance Win32_Processor -ErrorAction Stop
    if ($cpuInfo -is [array]) { $cpuInfo = $cpuInfo[0] }
    $cpu = $cpuInfo.Name
    $cpuCores = $cpuInfo.NumberOfCores
    if (-not $cpuCores -or $cpuCores -le 0) { $cpuCores = 2 }
} catch {
    Write-Host "[UYARI] CPU bilgisi okunamadi." -ForegroundColor Yellow
    $cpu = "Bilinmiyor"
    $cpuCores = 2
}

# ---------------------------------------------------------
#  2) RAM bilgisi (GB)
# ---------------------------------------------------------
try {
    $ramBytes = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory
    $ramGB = [math]::Round($ramBytes / 1GB, 1)
    if (-not $ramGB -or $ramGB -le 0) { $ramGB = 8 }
} catch {
    Write-Host "[UYARI] RAM bilgisi okunamadi, 8 GB varsayilan kullaniliyor." -ForegroundColor Yellow
    $ramGB = 8
}

# ---------------------------------------------------------
#  3) GPU bilgisi - sanal/hayali adaptorleri disla, VRAM oku
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
    $vramGB = 2
}
elseif ($activeGpus -is [array]) {
    $primary = $activeGpus | Sort-Object -Property AdapterRAM -Descending | Select-Object -First 1
    $gpu = $primary.Name
    $hz = $primary.CurrentRefreshRate
    $vramGB = if ($primary.AdapterRAM -gt 0) { [math]::Round($primary.AdapterRAM / 1GB, 1) } else { 2 }
    Write-Host "[BILGI] Birden fazla aktif GPU bulundu, ana GPU olarak '$gpu' secildi." -ForegroundColor Yellow
}
else {
    $gpu = $activeGpus.Name
    $hz = $activeGpus.CurrentRefreshRate
    $vramGB = if ($activeGpus.AdapterRAM -gt 0) { [math]::Round($activeGpus.AdapterRAM / 1GB, 1) } else { 2 }
}

# Not: Modern surucularde AdapterRAM 32-bit tasma nedeniyle yanlis/kucuk deger
# dondurebilir (ornegin 4GB+ kartlarda). Bu durumda VRAM'i guvenli tarafta (dusuk)
# varsayip profili buna gore secmek, gereginden fazla ayar acmaktan daha guvenlidir.
if ($vramGB -le 0 -or $vramGB -gt 64) { $vramGB = 2 }

# ---------------------------------------------------------
#  4) Hz guvenlik kontrolu + fps hesaplama
# ---------------------------------------------------------
if (-not $hz -or $hz -le 0 -or $hz -gt 1000) {
    Write-Host "[UYARI] Yenileme hizi guvenilir okunamadi (deger: $hz), 60 Hz varsayilan kullaniliyor." -ForegroundColor Yellow
    $hz = 60
}
$fps = [math]::Round(($hz - 0.5), 1)

# ---------------------------------------------------------
#  5) Donanim profili belirleme (DUSUK / ORTA / YUKSEK)
# ---------------------------------------------------------
# Puanlama: CPU cekirdek + RAM + VRAM uzerinden basit bir agirlikli skor
$score = 0
if ($cpuCores -ge 6) { $score += 2 } elseif ($cpuCores -ge 4) { $score += 1 }
if ($ramGB -ge 16) { $score += 2 } elseif ($ramGB -ge 8) { $score += 1 }
if ($vramGB -ge 6) { $score += 2 } elseif ($vramGB -ge 3) { $score += 1 }

if ($score -ge 5) {
    $tier = "YUKSEK"
} elseif ($score -ge 3) {
    $tier = "ORTA"
} else {
    $tier = "DUSUK"
}

switch ($tier) {
    "YUKSEK" {
        $t_texturemode = "GL_LINEAR_MIPMAP_LINEAR"
        $t_maxsize     = "2048"
        $t_rounddown   = "0"
        $t_maxshells   = "300"
        $t_smokepuffs  = "300"
        $t_decals      = "600"
        $t_corpsestay  = "3"
    }
    "ORTA" {
        $t_texturemode = "GL_LINEAR_MIPMAP_LINEAR"
        $t_maxsize     = "1024"
        $t_rounddown   = "1"
        $t_maxshells   = "60"
        $t_smokepuffs  = "60"
        $t_decals      = "150"
        $t_corpsestay  = "1"
    }
    "DUSUK" {
        $t_texturemode = "GL_NEAREST_MIPMAP_NEAREST"
        $t_maxsize     = "512"
        $t_rounddown   = "3"
        $t_maxshells   = "0"
        $t_smokepuffs  = "0"
        $t_decals      = "0"
        $t_corpsestay  = "0"
    }
}

Write-Host "CPU        : $cpu ($cpuCores cekirdek)"
Write-Host "RAM        : $ramGB GB"
Write-Host "GPU        : $gpu (~$vramGB GB VRAM)"
Write-Host "Hz         : $hz"
Write-Host "FPS Limiti : $fps"
Write-Host "Donanim Profili: $tier" -ForegroundColor Magenta

# ---------------------------------------------------------
#  6) Internet gecikmesi (ping) olcumu -> network profili
# ---------------------------------------------------------
Write-Host "`nInternet gecikmesi olculuyor..." -ForegroundColor Cyan

$pingTargets = @("8.8.8.8", "1.1.1.1")
$latencies = @()

foreach ($target in $pingTargets) {
    try {
        $result = Test-Connection -ComputerName $target -Count 3 -ErrorAction Stop
        $avg = ($result | Measure-Object -Property ResponseTime -Average).Average
        if ($avg) { $latencies += $avg }
    } catch {
        # hedef yanit vermedi, atla
    }
}

if ($latencies.Count -gt 0) {
    $avgPing = [math]::Round(($latencies | Measure-Object -Average).Average, 0)
} else {
    Write-Host "[UYARI] Ping olculemedi (baglanti/firewall engeli olabilir), orta seviye network ayari kullanilacak." -ForegroundColor Yellow
    $avgPing = 60
}

if ($avgPing -le 30) {
    $netTier = "IYI"
    $n_updaterate = "101"
    $n_cmdrate = "101"
    $n_interp = "0.01"
    $n_rate = "100000"
} elseif ($avgPing -le 80) {
    $netTier = "ORTA"
    $n_updaterate = "60"
    $n_cmdrate = "60"
    $n_interp = "0.02"
    $n_rate = "40000"
} else {
    $netTier = "ZAYIF"
    $n_updaterate = "30"
    $n_cmdrate = "30"
    $n_interp = "0.05"
    $n_rate = "25000"
}

Write-Host "Ortalama Ping: $avgPing ms -> Network Profili: $netTier" -ForegroundColor Magenta

# =========================================================
#  7) userconfig.cfg olustur
# =========================================================
$cfg = @"
// =========================================================
// Hardware: $cpu ($cpuCores cekirdek) | $ramGB GB RAM | $gpu (~$vramGB GB VRAM) | $hz Hz
// Donanim Profili: $tier | Network Profili: $netTier (ortalama ping: $avgPing ms)
// Olusturulma Tarihi: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
//
// NOT: Asagidaki tum ayarlar AKTIF durumdadir. Bazi degerler (sensitivity,
// gamma, brightness gibi) kisiye/monitore gore degisir - varsayilan bir deger
// atanmistir, kendine gore duzenlemekten cekinme (deger sadece degistir).
//
// NOT 2: Bircok cvar (rate, cl_updaterate, cl_cmdrate, fps_max vb.) sunucu
// tarafindan sv_ limitleriyle KISITLANABILIR. Client'ta yuksek deger yazman,
// sunucu izin vermiyorsa hicbir sey degistirmez.
// =========================================================

// --- FPS / Cekirdek ---
fps_max "$fps"
fps_override "1"

// --- Render / Grafik (donanim profiline gore: $tier) ---
gl_fog "0"
gl_spriteblend "0"
gl_polyoffset "0.1"
gl_flipmatrix "0"
r_mirroralpha "0"
r_dynamic "0"
r_mmx "1"
gl_texturemode "$t_texturemode"
gl_max_size "$t_maxsize"
gl_round_down "$t_rounddown"
gamma "3"                // ekran parlakligi, kisiye/monitore gore degistirebilirsin
brightness "2"           // ekran parlakligi, kisiye/monitore gore degistirebilirsin
// r_fullbright BILEREK EKLENMEDI: cogu sunucuda admin mod/antihile tarafindan
// tespit edilip banlanma riski tasir, bu bir "hile siniri" ayaridir.

// --- Mouse / Input ---
m_filter "0"
sensitivity "3.0"              // fare hassasiyeti - kisiye gore degistirebilirsin

// --- Network (ping bazli otomatik: $netTier, ~$avgPing ms) ---
rate "$n_rate"
cl_cmdrate "$n_cmdrate"
cl_updaterate "$n_updaterate"
ex_interp "$n_interp"
cl_cmdbackup "2"
cl_resend "1.5"
cl_allowdownload "0"
cl_allowupload "0"
cl_download_ingame "0"

// --- Lag Compensation (input lag icin KRITIK) ---
cl_lw "1"
cl_lc "1"

// --- HUD / Konsol ---
developer "0"
net_graph "0"
cl_showfps "1"           // ekranda FPS sayacini gosterir

// --- Gorsel gurultuyu azalt (donanim profiline gore: $tier) ---
hpk_maxsize "0"
cl_corpsestay "$t_corpsestay"
max_shells "$t_maxshells"
max_smokepuffs "$t_smokepuffs"
mp_decals "$t_decals"
r_decals "$t_decals"

// --- Ses ---
_snd_mixahead "0.05"
voice_enable "0"
MP3Volume "0"           // oyun ici radyo/muzik sesini kapatir
suitvolume "0"          // HEV suit uyari sesini kapatir

// --- Hareket ---
cl_vsmoothing "0"
cl_sidespeed "400"
cl_backspeed "400"
cl_forwardspeed "400"
cl_bob "0.01"            // view bobbing miktari - kisiye gore degistirebilirsin
cl_bobcycle "0.8"        // view bobbing hizi - kisiye gore degistirebilirsin

echo "=== USERCONFIG LOADED (v3 - donanim + ping bazli) ==="
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
#  8) Input Lag Azaltma - Sistem Seviyesi Ayarlar (Yonetici gerekir)
# =========================================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "`n[BILGI] Yonetici yetkisi yok, sistem seviyesi ayarlar atlaniyor." -ForegroundColor Yellow
}
else {
    Write-Host "`nSistem seviyesi ayarlar uygulaniyor (eski degerler once yedeklenecek)..." -ForegroundColor Cyan

    $restoreLines = @()
    $restoreLines += "# Bu script, optimize_ve_userconfig_v3.ps1 tarafindan degistirilen ayarlari geri alir."
    $restoreLines += "# Yonetici olarak calistirin."
    $restoreLines += ""

    # --- 8a) Guc plani ---
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

    # --- 8b) Fare hizlanmasini kapat ---
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

    # --- 8c) Game DVR / Game Bar kapat ---
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
