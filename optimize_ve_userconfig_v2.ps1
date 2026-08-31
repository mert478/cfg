# =========================================================
#  Otomatik Donanim + Dinamik Speedtest (Bandwidth) + CFG Olusturucu
#  + Input Lag Azaltma Sistem Ayarlari
#  Surum: 4.0 (Bandwidth Bazli Rate + Otomatik Steam Path + Cvar Dogrulama)
#
#  Bu script:
#   - Sisteminizi otomatik Yonetici olarak yeniden baslatir
#   - Gercek/aktif GPU'yu sanal adaptorlerden ayirt eder
#   - CPU, RAM ve VRAM'e gore DUSUK/ORTA/YUKSEK donanim profili secer
#   - Anlik Download ve Upload hizlarini test ederek CS 1.6 network 
#     cvar'larini (rate, cl_cmdrate, cl_updaterate) dinamik ayarlar
#   - Steam/CS 1.6 yolunu otomatik bulup cstrike klasorune cfg'yi yazar
#   - Guc plani, fare ivmesi, Game DVR ayarlarini optimize eder
#   - Degisiklik yapmadan ONCE eski degerleri yedekler (eski_ayarlara_don.ps1)
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
        Write-Host "[UYARI] Yonetici olarak yeniden baslatilamadi. Script kisitli modda devam edecek." -ForegroundColor Yellow
    }
}

Write-Host "=== SYSTEM & NETWORK OPTIMIZER V4.0 ===" -ForegroundColor Cyan
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
#  3) GPU bilgisi - sanal adaptorleri disla, VRAM oku
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
    Write-Host "[UYARI] Gercek/aktif ekran karti tespit edilemedi, varsayilanlar kullaniliyor." -ForegroundColor Yellow
    $gpu = "Bilinmiyor"
    $hz = 60
    $vramGB = 2
}
elseif ($activeGpus -is [array]) {
    $primary = $activeGpus | Sort-Object -Property AdapterRAM -Descending | Select-Object -First 1
    $gpu = $primary.Name
    $hz = $primary.CurrentRefreshRate
    $vramGB = if ($primary.AdapterRAM -gt 0) { [math]::Round($primary.AdapterRAM / 1GB, 1) } else { 2 }
    Write-Host "[BILGI] Birden fazla GPU bulundu, ana GPU '$gpu' secildi." -ForegroundColor Yellow
}
else {
    $gpu = $activeGpus.Name
    $hz = $activeGpus.CurrentRefreshRate
    $vramGB = if ($activeGpus.AdapterRAM -gt 0) { [math]::Round($activeGpus.AdapterRAM / 1GB, 1) } else { 2 }
}

if ($vramGB -le 0 -or $vramGB -gt 64) { $vramGB = 2 }

# ---------------------------------------------------------
#  4) Hz guvenlik kontrolu + fps hesaplama
# ---------------------------------------------------------
if (-not $hz -or $hz -le 0 -or $hz -gt 1000) {
    Write-Host "[UYARI] Yenileme hizi okunamadi, 60 Hz varsayilan kullaniliyor." -ForegroundColor Yellow
    $hz = 60
}
$fps = [math]::Round(($hz - 0.5), 1)

# ---------------------------------------------------------
#  5) Donanim profili belirleme (DUSUK / ORTA / YUKSEK)
# ---------------------------------------------------------
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

Write-Host "CPU            : $cpu ($cpuCores cekirdek)"
Write-Host "RAM            : $ramGB GB"
Write-Host "GPU            : $gpu (~$vramGB GB VRAM)"
Write-Host "Hz             : $hz"
Write-Host "FPS Limiti     : $fps"
Write-Host "Donanim Profili: $tier" -ForegroundColor Magenta

# ---------------------------------------------------------
#  6) ANLIK SPEEDTEST (Download & Upload Hizi Olcumu)
# ---------------------------------------------------------
Write-Host "`nAnlik Internet Band Genisligi (Speedtest) Olculuyor..." -ForegroundColor Cyan

function Measure-DownloadSpeed {
    try {
        $testUrl = "https://speed.cloudflare.com/__down?bytes=10485760" # 10MB Test Dosyasi
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $wc = New-Object System.Net.WebClient
        $data = $wc.DownloadData($testUrl)
        $sw.Stop()
        $seconds = $sw.Elapsed.TotalSeconds
        $downloadMbps = [math]::Round((($data.Length * 8) / 1000000) / $seconds, 2)
        return $downloadMbps
    } catch {
        return $null
    }
}

function Measure-UploadSpeed {
    try {
        $testUrl = "https://speed.cloudflare.com/__up"
        $dummyData = New-Object Byte[] (2048 * 1024) # 2MB Payload
        (New-Object System.Random).NextBytes($dummyData)
        
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $wc = New-Object System.Net.WebClient
        $null = $wc.UploadData($testUrl, "POST", $dummyData)
        $sw.Stop()
        
        $seconds = $sw.Elapsed.TotalSeconds
        $uploadMbps = [math]::Round((($dummyData.Length * 8) / 1000000) / $seconds, 2)
        return $uploadMbps
    } catch {
        return $null
    }
}

$downSpeed = Measure-DownloadSpeed
$upSpeed = Measure-UploadSpeed

if (-not $downSpeed) { $downSpeed = 10.0 }
if (-not $upSpeed) { $upSpeed = 2.0 }

Write-Host "Anlik Indirme (Download) Hizi : $downSpeed Mbps" -ForegroundColor Green
Write-Host "Anlik Yukleme (Upload) Hizi   : $upSpeed Mbps" -ForegroundColor Green

# --- Speedtest Verilerine Gore CS 1.6 Network Ayarlari ---
if ($downSpeed -ge 15.0 -and $upSpeed -ge 3.0) {
    # Yüksek Hızlı Bağlantı (Fiber / VDSL)
    $netTier = "FIBER_HIGH"
    $n_rate = "100000"
    $n_updaterate = "102"
    $n_cmdrate = "102"
    $n_interp = "0.01"
    $n_cmdbackup = "2"
} elseif ($downSpeed -ge 5.0 -and $upSpeed -ge 1.0) {
    # Orta Hızlı Standart Bağlantı
    $netTier = "MEDIUM_BROADBAND"
    $n_rate = "60000"
    $n_updaterate = "80"
    $n_cmdrate = "80"
    $n_interp = "0.015"
    $n_cmdbackup = "2"
} else {
    # Düşük / Mobil Bağlantı (Loss ve Choke önleme odaklı)
    $netTier = "LOW_BANDWIDTH"
    $n_rate = "30000"
    $n_updaterate = "60"
    $n_cmdrate = "60"
    $n_interp = "0.02"
    $n_cmdbackup = "3"
}

Write-Host "Dinamik Network Profili: $netTier (rate: $n_rate, cmdrate: $n_cmdrate)" -ForegroundColor Magenta

# =========================================================
#  7) userconfig.cfg Olusturma & Otomatik CS Yolu Tespiti
# =========================================================
$cfg = @"
// =========================================================
// Hardware: $cpu ($cpuCores cekirdek) | $ramGB GB RAM | $gpu (~$vramGB GB VRAM) | $hz Hz
// Donanim Profili: $tier | Network Profili: $netTier
// Test Edilen Hizlar: Down: $downSpeed Mbps | Up: $upSpeed Mbps
// Olusturulma Tarihi: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
// =========================================================

// --- FPS / Cekirdek ---
fps_max "$fps"
fps_override "1"

// --- Render / Grafik ---
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
gamma "3"
brightness "2"

// --- Mouse / Input ---
m_filter "0"
sensitivity "3.0"

// --- Network (Bandwidth Bazli Dinamik Ayarlar) ---
rate "$n_rate"
cl_cmdrate "$n_cmdrate"
cl_updaterate "$n_updaterate"
ex_interp "$n_interp"
cl_cmdbackup "$n_cmdbackup"
cl_resend "1.5"
cl_allowdownload "0"
cl_allowupload "0"
cl_download_ingame "0"

// --- Lag Compensation ---
cl_lw "1"
cl_lc "1"

// --- HUD / Konsol ---
developer "0"
net_graph "0"
cl_showfps "1"

// --- Gorsel Temizlik ---
hpk_maxsize "0"
cl_corpsestay "$t_corpsestay"
max_shells "$t_maxshells"
max_smokepuffs "$t_smokepuffs"
mp_decals "$t_decals"
r_decals "$t_decals"

// --- Ses ---
_snd_mixahead "0.05"
voice_enable "0"
MP3Volume "0"
suitvolume "0"

// --- Hareket ---
cl_vsmoothing "0"
cl_sidespeed "400"
cl_backspeed "400"
cl_forwardspeed "400"
cl_bob "0.01"
cl_bobcycle "0.8"

echo "=== USERCONFIG V4.0 LOADED (Bandwidth Optimized) ==="
"@

# Masaüstüne Yedek Kopyayı Yaz
$desktopPath = [Environment]::GetFolderPath('Desktop')
$desktopCfgPath = Join-Path $desktopPath "userconfig.cfg"
Set-Content -Path $desktopCfgPath -Value $cfg -Encoding Ascii
Write-Host "`n[OK] userconfig.cfg masaustune yazildi: $desktopCfgPath" -ForegroundColor Green

# Steam ve CS 1.6 Dizinini Kayıt Defterinden (Registry) Otomatik Bul
$csFound = $false
try {
    $steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue).SteamPath
    if ($steamPath) {
        $cstrikePath = Join-Path $steamPath "steamapps\common\Half-Life\cstrike"
        if (Test-Path $cstrikePath) {
            Set-Content -Path (Join-Path $cstrikePath "userconfig.cfg") -Value $cfg -Encoding Ascii
            Write-Host "[BASARILI] CS 1.6 klasoru otomatik bulundu ve CFG dogrudan aktarildi:" -ForegroundColor Green
            Write-Host " -> $cstrikePath\userconfig.cfg" -ForegroundColor Yellow
            $csFound = $true
        }
    }
} catch { }

if (-not $csFound) {
    Write-Host "[BILGI] Otomatik cstrike klasoru bulunamadi. Masaustundeki 'userconfig.cfg' dosyasini oyun klasorunuze manuel kopyalayabilirsiniz." -ForegroundColor Yellow
}

# =========================================================
#  8) Input Lag Azaltma - Sistem Seviyesi Ayarlar
# =========================================================
if ($isAdmin) {
    Write-Host "`nSistem seviyesi ayarlar uygulaniyor..." -ForegroundColor Cyan
    $restoreLines = @("# Restore Script V4.0", "")

    # Power Plan
    try {
        $currentScheme = (powercfg -getactivescheme) -replace '.*GUID: ([a-f0-9\-]+).*', '$1'
        $restoreLines += "powercfg -setactive $currentScheme"
        $null = powercfg -setactive SCHEME_MIN 2>&1
        Write-Host "[OK] Guc plani 'Yuksek Performans' yapildi." -ForegroundColor Green
    } catch {}

    # Fare İvmesi
    try {
        $mp = "HKCU:\Control Panel\Mouse"
        Set-ItemProperty -Path $mp -Name "MouseSpeed" -Value "0" -Force
        Set-ItemProperty -Path $mp -Name "MouseThreshold1" -Value "0" -Force
        Set-ItemProperty -Path $mp -Name "MouseThreshold2" -Value "0" -Force
        Write-Host "[OK] Windows fare ivmelenmesi tamamen kapatildi." -ForegroundColor Green
    } catch {}

    # Game DVR
    try {
        $gcs = "HKCU:\System\GameConfigStore"
        if (-not (Test-Path $gcs)) { New-Item -Path $gcs -Force | Out-Null }
        Set-ItemProperty -Path $gcs -Name "GameDVR_Enabled" -Value 0 -Force
        
        $gb = "HKCU:\Software\Microsoft\GameBar"
        if (-not (Test-Path $gb)) { New-Item -Path $gb -Force | Out-Null }
        Set-ItemProperty -Path $gb -Name "AutoGameModeEnabled" -Value 1 -Force
        Write-Host "[OK] Game DVR kapatildi, Oyun Modu aktif edildi." -ForegroundColor Green
    } catch {}

    # Geri Alma Dosyası
    try {
        $restorePath = Join-Path $desktopPath "eski_ayarlara_don.ps1"
        Set-Content -Path $restorePath -Value ($restoreLines -join "`r`n") -Encoding UTF8
        Write-Host "[BILGI] Geri alma dosyasi masaustune olusturuldu: eski_ayarlara_don.ps1" -ForegroundColor Cyan
    } catch {}
}

Write-Host "`n=== ISLEM TAMAMLANDI ===" -ForegroundColor Cyan
Write-Host "Kapatmak icin bir tusa basin..."
[void][System.Console]::ReadKey($true)
