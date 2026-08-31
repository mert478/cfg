# =========================================================
#  CS 1.6 Kisisel Optimizasyon Araci - Surum 4.0
#  Donanim Bazli Otomatik Kalite + Sistem Optimizasyonu + Kaynak Denetimi
#
#  Gelistirici : Ay Yildiz | Silva
#  Topluluk    : www.ayyildizailesi.com
#
#  CMD veya PowerShell'den, Yonetici olsun olmasin calistirilabilir.
#  Script gerektiginde kendini otomatik Yonetici olarak yeniden baslatir.
# =========================================================

$ScriptSourceUrl = "https://raw.githubusercontent.com/mert478/cfg/main/optimize_ve_userconfig_v4.ps1"

# ---------------------------------------------------------
#  0) Kendini otomatik Yonetici olarak yeniden baslat
#     (Hem dosyadan hem "irm | iex" ile calistirildiginda calisir)
# ---------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Yonetici izni isteniyor (UAC penceresi acilacak)..." -ForegroundColor Yellow
    try {
        if ($PSCommandPath) {
            $targetPath = $PSCommandPath
        } else {
            # "irm ... | iex" ile calistirildiginda dosya yolu olmaz, gecici bir kopya indirilir
            $targetPath = Join-Path $env:TEMP "cs16_optimize_v4.ps1"
            Invoke-WebRequest -Uri $ScriptSourceUrl -OutFile $targetPath -UseBasicParsing -ErrorAction Stop
        }
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$targetPath`""
        exit
    } catch {
        Write-Host "[UYARI] Yonetici olarak yeniden baslatilamadi. Sistem ayarlari (guc plani, fare, AV) atlanacak, sadece cfg dosyasi olusturulacak." -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------
#  Yardimci: powercfg ciktisindan GUID cikar
# ---------------------------------------------------------
function Get-GuidFromPowercfgLine($line) {
    if ($line -match '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})') {
        return $matches[1]
    }
    return $null
}

# =========================================================
#  1) DONANIM ALGILAMA
# =========================================================
Write-Host "`n=========================================================" -ForegroundColor DarkCyan
Write-Host "   CS 1.6 KISISEL OPTIMIZASYON ARACI - v4.0" -ForegroundColor Cyan
Write-Host "   Gelistirici: Ay Yildiz | Silva" -ForegroundColor Cyan
Write-Host "   Topluluk   : www.ayyildizailesi.com" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor DarkCyan
Write-Host "`n=== DONANIM BILGILERI TOPLANIYOR ===" -ForegroundColor Cyan

try {
    $cpuInfo = Get-CimInstance Win32_Processor -ErrorAction Stop
    if ($cpuInfo -is [array]) { $cpuInfo = $cpuInfo[0] }
    $cpu = $cpuInfo.Name
    $cpuCores = $cpuInfo.NumberOfCores
    if (-not $cpuCores -or $cpuCores -le 0) { $cpuCores = 2 }
} catch {
    $cpu = "Bilinmiyor"; $cpuCores = 2
}

try {
    $ramBytes = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory
    $ramGB = [math]::Round($ramBytes / 1GB, 1)
    if (-not $ramGB -or $ramGB -le 0) { $ramGB = 8 }
} catch { $ramGB = 8 }

$virtualGpuPatterns = @("Basic Render","Basic Display","Remote Desktop","DisplayLink","Virtual","Meta Virtual Monitor","IDD","Parsec","TeamViewer","RDPUDD","VNC","Citrix","Hyper-V")
try { $allGpus = Get-CimInstance Win32_VideoController -ErrorAction Stop } catch { $allGpus = $null }

$activeGpus = $allGpus | Where-Object {
    $gpuName = $_.Name
    $isVirtual = $false
    foreach ($pattern in $virtualGpuPatterns) {
        if ($gpuName -match [regex]::Escape($pattern)) { $isVirtual = $true; break }
    }
    ($_.CurrentRefreshRate -gt 0) -and ($_.CurrentHorizontalResolution -gt 0) -and (-not $isVirtual)
}

if (-not $activeGpus) {
    $gpu = "Bilinmiyor"; $hz = 60; $vramGB = 2
}
elseif ($activeGpus -is [array]) {
    $primary = $activeGpus | Sort-Object -Property AdapterRAM -Descending | Select-Object -First 1
    $gpu = $primary.Name
    $hz = $primary.CurrentRefreshRate
    $vramGB = if ($primary.AdapterRAM -gt 0) { [math]::Round($primary.AdapterRAM / 1GB, 1) } else { 2 }
}
else {
    $gpu = $activeGpus.Name
    $hz = $activeGpus.CurrentRefreshRate
    $vramGB = if ($activeGpus.AdapterRAM -gt 0) { [math]::Round($activeGpus.AdapterRAM / 1GB, 1) } else { 2 }
}
if ($vramGB -le 0 -or $vramGB -gt 64) { $vramGB = 2 }
if (-not $hz -or $hz -le 0 -or $hz -gt 1000) { $hz = 60 }
$fps = [math]::Round(($hz - 0.5), 1)

$score = 0
if ($cpuCores -ge 6) { $score += 2 } elseif ($cpuCores -ge 4) { $score += 1 }
if ($ramGB -ge 16) { $score += 2 } elseif ($ramGB -ge 8) { $score += 1 }
if ($vramGB -ge 6) { $score += 2 } elseif ($vramGB -ge 3) { $score += 1 }
$hwTier = if ($score -ge 5) { "YUKSEK" } elseif ($score -ge 3) { "ORTA" } else { "DUSUK" }

Write-Host "CPU        : $cpu ($cpuCores cekirdek)"
Write-Host "RAM        : $ramGB GB"
Write-Host "GPU        : $gpu (~$vramGB GB VRAM)"
Write-Host "Hz         : $hz | FPS Limiti: $fps"
Write-Host "Donanim Seviyesi (otomatik mod icin): $hwTier" -ForegroundColor Magenta

# =========================================================
#  2) NETWORK ALGILAMA (ping + gercek indirme hizi)
# =========================================================
Write-Host "`n=== INTERNET BILGILERI OLCULUYOR ===" -ForegroundColor Cyan

$latencies = @()
foreach ($target in @("8.8.8.8","1.1.1.1")) {
    try {
        $result = Test-Connection -ComputerName $target -Count 3 -ErrorAction Stop
        $avg = ($result | Measure-Object -Property ResponseTime -Average).Average
        if ($avg) { $latencies += $avg }
    } catch {}
}
$avgPing = if ($latencies.Count -gt 0) { [math]::Round(($latencies | Measure-Object -Average).Average, 0) } else { 60 }

if ($avgPing -le 30) { $netTier="IYI"; $n_updaterate="101"; $n_cmdrate="101"; $n_interp="0.01" }
elseif ($avgPing -le 80) { $netTier="ORTA"; $n_updaterate="60"; $n_cmdrate="60"; $n_interp="0.02" }
else { $netTier="ZAYIF"; $n_updaterate="30"; $n_cmdrate="30"; $n_interp="0.05" }

Write-Host "Ortalama Ping: $avgPing ms -> Gecikme Profili: $netTier"

Write-Host "`nGercek internet hizi olculuyor..." -ForegroundColor Cyan

$downloadMbps = 0
$uploadMbps = 0
$speedSource = "OLCULEMEDI"

# ---------------------------------------------------------
#  6a) ONCELIKLI YONTEM: Resmi Ookla Speedtest CLI
#      speedtest.net'in KENDI sunucu agini kullanir (en yakin/en hizli
#      sunucuyu otomatik secer). Cloudflare gibi genel CDN testlerinden
#      farkli olarak, ISP'lerin cogu Ookla ile "hizli yol" (peering)
#      anlasmasi yaptigi icin sonuc genelde gercek hizinize cok daha yakin
#      cikar - tam olarak speedtest.net sitesinde gordugunuz sonuc gibi.
# ---------------------------------------------------------
try {
    $stDir = Join-Path $env:TEMP "cs16_speedtest_cli"
    $stExe = Join-Path $stDir "speedtest.exe"

    if (-not (Test-Path $stExe)) {
        if (-not (Test-Path $stDir)) { New-Item -Path $stDir -ItemType Directory -Force | Out-Null }
        $zipPath = Join-Path $stDir "speedtest.zip"
        Invoke-WebRequest -Uri "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win64.zip" -OutFile $zipPath -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
        Expand-Archive -Path $zipPath -DestinationPath $stDir -Force
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path $stExe) {
        $jsonRaw = & $stExe --accept-license --accept-gdpr --format=json 2>$null
        $result = $jsonRaw | ConvertFrom-Json -ErrorAction Stop
        if ($result.download.bandwidth -gt 0) {
            $downloadMbps = [math]::Round(($result.download.bandwidth * 8) / 1000000, 1)
        }
        if ($result.upload.bandwidth -gt 0) {
            $uploadMbps = [math]::Round(($result.upload.bandwidth * 8) / 1000000, 1)
        }
        if ($downloadMbps -gt 0) {
            $speedSource = "Ookla Speedtest CLI"
            Write-Host "[OK] Ookla Speedtest CLI: Indirme ~$downloadMbps Mbps, Yukleme ~$uploadMbps Mbps" -ForegroundColor Green
            if ($result.server.name) { Write-Host "     Sunucu: $($result.server.name) / $($result.server.location)" -ForegroundColor DarkGray }
        }
    }
} catch {
    Write-Host "[UYARI] Ookla Speedtest CLI kullanilamadi, yedek yonteme geciliyor..." -ForegroundColor Yellow
    $downloadMbps = 0
}

# ---------------------------------------------------------
#  6b) YEDEK YONTEM 1: Paralel HttpClient testi (Ookla basarisiz olursa)
# ---------------------------------------------------------
if ($downloadMbps -le 0) {
    try {
        Add-Type -AssemblyName System.Net.Http -ErrorAction Stop
        $handler = New-Object System.Net.Http.HttpClientHandler
        $client = New-Object System.Net.Http.HttpClient($handler)
        $client.Timeout = [TimeSpan]::FromSeconds(15)

        $parallelCount = 6
        $bytesPerConn = 6000000
        $testUrl = "https://speed.cloudflare.com/__down?bytes=$bytesPerConn"

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $tasks = for ($i = 0; $i -lt $parallelCount; $i++) { $client.GetByteArrayAsync($testUrl) }
        [System.Threading.Tasks.Task]::WaitAll($tasks, 15000) | Out-Null
        $sw.Stop()

        $totalBytes = 0
        foreach ($t in $tasks) {
            if ($t.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion) { $totalBytes += $t.Result.Length }
        }
        $seconds = $sw.Elapsed.TotalSeconds
        if ($totalBytes -gt 0 -and $seconds -gt 0) {
            $downloadMbps = [math]::Round((($totalBytes * 8) / $seconds) / 1MB, 1)
            if ($downloadMbps -gt 0) { $speedSource = "Yedek Test (Cloudflare, coklu baglanti)" }
        }
        $client.Dispose()
    } catch { $downloadMbps = 0 }
}

# ---------------------------------------------------------
#  6c) YEDEK YONTEM 2: Tek baglantili test (son care)
# ---------------------------------------------------------
if ($downloadMbps -le 0) {
    try {
        $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
        $resp2 = Invoke-WebRequest -Uri "https://speed.cloudflare.com/__down?bytes=4000000" -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
        $sw2.Stop()
        $b2 = $resp2.RawContentLength
        if (-not $b2 -or $b2 -le 0) { $b2 = 4000000 }
        $s2 = $sw2.Elapsed.TotalSeconds
        if ($s2 -gt 0) {
            $downloadMbps = [math]::Round((($b2 * 8) / $s2) / 1MB, 1)
            if ($downloadMbps -gt 0) { $speedSource = "Yedek Test (Cloudflare, tekil baglanti)" }
        }
    } catch { $downloadMbps = 0 }
}

if ($downloadMbps -ge 50) { $bwTier="YUKSEK"; $n_rate="100000" }
elseif ($downloadMbps -ge 10) { $bwTier="ORTA"; $n_rate="40000" }
elseif ($downloadMbps -gt 0) { $bwTier="DUSUK"; $n_rate="25000" }
else { $bwTier="OLCULEMEDI"; $n_rate="25000" }

if ($downloadMbps -gt 0) { Write-Host "Indirme Hizi: ~$downloadMbps Mbps ($speedSource) -> Bant Genisligi Profili: $bwTier" -ForegroundColor Magenta }
else { Write-Host "Indirme hizi olculemedi -> guvenli varsayilan rate kullanilacak" -ForegroundColor Yellow }

# =========================================================
#  3) MENU
# =========================================================
Write-Host "`n=== CFG KALITE MODU SECIMI ===" -ForegroundColor Cyan
Write-Host "1) OTOMATIK  - Donanimina gore (kotu PC = performans oncelikli, iyi PC = kalite)"
Write-Host "2) YUKSEK KALITE + REKABETCI - Donanimdan bagimsiz en iyi gorsel + en iyi isabet/netcode ayarlari"
$modeChoice = Read-Host "Seciminiz (1/2, bos birakirsan 1 secilir)"
if ($modeChoice -ne "2") { $modeChoice = "1" }

if ($modeChoice -eq "2") {
    Write-Host "[SECILDI] Yuksek Kalite + Rekabetci Mod" -ForegroundColor Green
    $qTier = "YUKSEK"
    $q_updaterate = "101"; $q_cmdrate = "101"; $q_interp = "0.01"
} else {
    Write-Host "[SECILDI] Otomatik Mod (Donanim Seviyesi: $hwTier)" -ForegroundColor Green
    $qTier = $hwTier
    $q_updaterate = $n_updaterate; $q_cmdrate = $n_cmdrate; $q_interp = $n_interp
}

switch ($qTier) {
    "YUKSEK" { $t_texturemode="GL_LINEAR_MIPMAP_LINEAR"; $t_maxsize="2048"; $t_rounddown="0"; $t_maxshells="300"; $t_smokepuffs="300"; $t_decals="600"; $t_corpsestay="3" }
    "ORTA"   { $t_texturemode="GL_LINEAR_MIPMAP_LINEAR"; $t_maxsize="1024"; $t_rounddown="1"; $t_maxshells="60";  $t_smokepuffs="60";  $t_decals="150"; $t_corpsestay="1" }
    "DUSUK"  { $t_texturemode="GL_NEAREST_MIPMAP_NEAREST"; $t_maxsize="512"; $t_rounddown="3"; $t_maxshells="0"; $t_smokepuffs="0"; $t_decals="0"; $t_corpsestay="0" }
}

Write-Host "`n=== SISTEM OPTIMIZASYONU ===" -ForegroundColor Cyan
$doSystemOpt = Read-Host "Guc plani, fare ivmesi, Game Mode/DVR gibi input lag ayarlari uygulansin mi? (E/H)"

# =========================================================
#  4) userconfig.cfg OLUSTUR
# =========================================================
$cfg = @"
// =========================================================
// CS 1.6 Kisisel Optimizasyon Araci - Ay Yildiz | Silva
// Topluluk: www.ayyildizailesi.com
// =========================================================
// Hardware: $cpu ($cpuCores cekirdek) | $ramGB GB RAM | $gpu (~$vramGB GB VRAM) | $hz Hz
// Secilen Mod: $(if ($modeChoice -eq "2") { "YUKSEK KALITE + REKABETCI" } else { "OTOMATIK ($hwTier)" })
// Gecikme: $netTier ($avgPing ms) | Bant Genisligi: $bwTier (~$downloadMbps Mbps, kaynak: $speedSource)
// Olusturulma Tarihi: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
//
// NOT: rate/cl_updaterate/cl_cmdrate gibi degerler sunucunun sv_ limitleriyle
// KISITLANABILIR. Client'ta yuksek yazman, sunucu izin vermiyorsa etkisiz kalir.
// =========================================================

// --- FPS / Cekirdek ---
fps_max "$fps"
fps_override "1"
gl_vsync "0"

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
// r_fullbright BILEREK EKLENMEDI: cogu sunucuda admin mod/antihile tarafindan
// tespit edilip banlanma riski tasir.

// --- Mouse / Input (Raw Input input lag icin kritik) ---
m_rawinput "1"
m_filter "0"
m_customaccel "0"
m_mousethread_sleep "0"
sensitivity "3.0"

// --- Network ---
rate "$n_rate"
cl_cmdrate "$q_cmdrate"
cl_updaterate "$q_updaterate"
ex_interp "$q_interp"
cl_cmdbackup "2"
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

// --- Gorsel gurultuyu azalt ---
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

echo "=== Ayarlar  Hazir -Silva ^^ ==="
"@

try {
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $cfgPath = Join-Path $desktopPath "userconfig.cfg"
    Set-Content -Path $cfgPath -Value $cfg -Encoding Ascii -ErrorAction Stop
    Write-Host "`n[BASARILI] userconfig.cfg olusturuldu: $cfgPath" -ForegroundColor Green
} catch {
    Write-Host "`n[HATA] userconfig.cfg yazilamadi: $_" -ForegroundColor Red
}

# =========================================================
#  5) SISTEM OPTIMIZASYONU (Yonetici gerekir)
# =========================================================
$isAdminNow = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$restoreLines = @("# eski_ayarlara_don.ps1 - Yonetici olarak calistirin", "")

if ($doSystemOpt -match '^[EeYy]') {
    if (-not $isAdminNow) {
        Write-Host "`n[UYARI] Yonetici yetkisi yok, sistem ayarlari atlaniyor." -ForegroundColor Yellow
    } else {
        Write-Host "`n=== SISTEM AYARLARI UYGULANIYOR ===" -ForegroundColor Cyan

        # --- Guc plani: once Nihai Performans dene, sonra Yuksek Performans ---
        try {
            $currentSchemeLine = powercfg -getactivescheme
            $currentGuid = Get-GuidFromPowercfgLine $currentSchemeLine
            if ($currentGuid) { $restoreLines += "powercfg -setactive $currentGuid" }

            $ultimateTemplate = "e9a42b02-d5df-448d-aa00-03f14749eb61"
            $dupOutput = powercfg -duplicatescheme $ultimateTemplate 2>&1
            $newGuid = Get-GuidFromPowercfgLine ($dupOutput | Out-String)
            if ($LASTEXITCODE -eq 0 -and $newGuid) {
                powercfg -setactive $newGuid
                Write-Host "[OK] Guc plani 'Nihai Performans' (Ultimate Performance) olarak ayarlandi." -ForegroundColor Green
            } else {
                $result = powercfg -setactive SCHEME_MIN 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] Guc plani 'Yuksek Performans' olarak ayarlandi." -ForegroundColor Green
                } else {
                    $hp = powercfg -list | Select-String -Pattern "High performance|Yüksek Performans" | Select-Object -First 1
                    if ($hp) {
                        $guid = Get-GuidFromPowercfgLine $hp
                        if ($guid) { powercfg -setactive $guid; Write-Host "[OK] Guc plani 'Yuksek Performans' olarak ayarlandi." -ForegroundColor Green }
                    } else {
                        Write-Host "[UYARI] Yuksek performans plani bulunamadi, atlaniyor." -ForegroundColor Yellow
                    }
                }
            }
        } catch { Write-Host "[HATA] Guc plani ayarlanamadi: $_" -ForegroundColor Red }

        # --- Fare ivmesi kapat ---
        try {
            $mp = "HKCU:\Control Panel\Mouse"
            $oldSpeed = (Get-ItemProperty -Path $mp -Name MouseSpeed -EA SilentlyContinue).MouseSpeed
            $oldT1 = (Get-ItemProperty -Path $mp -Name MouseThreshold1 -EA SilentlyContinue).MouseThreshold1
            $oldT2 = (Get-ItemProperty -Path $mp -Name MouseThreshold2 -EA SilentlyContinue).MouseThreshold2
            $restoreLines += "Set-ItemProperty -Path '$mp' -Name MouseSpeed -Value '$oldSpeed'"
            $restoreLines += "Set-ItemProperty -Path '$mp' -Name MouseThreshold1 -Value '$oldT1'"
            $restoreLines += "Set-ItemProperty -Path '$mp' -Name MouseThreshold2 -Value '$oldT2'"
            Set-ItemProperty -Path $mp -Name MouseSpeed -Value "0" -Force
            Set-ItemProperty -Path $mp -Name MouseThreshold1 -Value "0" -Force
            Set-ItemProperty -Path $mp -Name MouseThreshold2 -Value "0" -Force
            Write-Host "[OK] Fare ivmelenmesi (mouse acceleration) kapatildi." -ForegroundColor Green
        } catch { Write-Host "[HATA] Fare ayarlari degistirilemedi: $_" -ForegroundColor Red }

        # --- Game Mode ac, Game DVR kapat ---
        try {
            $gcs = "HKCU:\System\GameConfigStore"
            if (-not (Test-Path $gcs)) { New-Item -Path $gcs -Force | Out-Null }
            $oldDvr = (Get-ItemProperty -Path $gcs -Name GameDVR_Enabled -EA SilentlyContinue).GameDVR_Enabled
            if ($null -eq $oldDvr) { $oldDvr = 1 }
            $restoreLines += "if (-not (Test-Path '$gcs')) { New-Item -Path '$gcs' -Force | Out-Null }"
            $restoreLines += "Set-ItemProperty -Path '$gcs' -Name GameDVR_Enabled -Value $oldDvr -Force"
            Set-ItemProperty -Path $gcs -Name GameDVR_Enabled -Value 0 -Force

            $gb = "HKCU:\Software\Microsoft\GameBar"
            if (-not (Test-Path $gb)) { New-Item -Path $gb -Force | Out-Null }
            $oldAgm = (Get-ItemProperty -Path $gb -Name AutoGameModeEnabled -EA SilentlyContinue).AutoGameModeEnabled
            if ($null -eq $oldAgm) { $oldAgm = 1 }
            $restoreLines += "if (-not (Test-Path '$gb')) { New-Item -Path '$gb' -Force | Out-Null }"
            $restoreLines += "Set-ItemProperty -Path '$gb' -Name AutoGameModeEnabled -Value $oldAgm -Force"
            Set-ItemProperty -Path $gb -Name AutoGameModeEnabled -Value 1 -Force

            Write-Host "[OK] Windows Oyun Modu acildi, Game DVR arka plan kaydi kapatildi." -ForegroundColor Green
        } catch { Write-Host "[HATA] Game Bar ayarlari degistirilemedi: $_" -ForegroundColor Red }

        # --- Scriptleyemedigimiz ama etkili oldugu bilinen ayarlar icin bilgilendirme ---
        Write-Host "`n--- Elle Yapman Gereken Ek Ayarlar (Script Bunlari Otomatik Yapamiyor) ---" -ForegroundColor Yellow
        Write-Host "  * V-Sync: cfg icinde kapatildi (gl_vsync 0), ekstra islem gerekmez."
        Write-Host "  * Oyunu Tam Ekran (Fullscreen) modda calistir - Pencereli/Sinirsiz Pencereli DWM gecikmesi ekler."
        Write-Host "  * NVIDIA/AMD kontrol panelinden Dusuk Gecikme Modu / Anti-Lag'i actigindan emin ol (bu, surucu ayaridir, script degistiremez)."
        Write-Host "  * Farenin USB polling rate'ini (varsa) uretici yazilimindan (Razer Synapse, Logitech G HUB vb.) 1000Hz+ yap."
        Write-Host "  * Mumkunse kablosuz yerine kablolu fare/klavye kullan (Bluetooth ozellikle onerilmez)."
        Write-Host "  * Yuksek pingin 'arkadan vurulma' hissi yaratmasi bufferbloat kaynakli olabilir; router'inda QoS/SQM ayari varsa acmayi dusun (bu Windows'tan degil, router panelinden yapilir)."
    }
} else {
    Write-Host "[BILGI] Sistem optimizasyonu atlandi." -ForegroundColor Yellow
}

# =========================================================
#  6) GERI ALMA DOSYASI
# =========================================================
if ($isAdminNow -and ($doSystemOpt -match '^[EeYy]')) {
    try {
        $restorePath = Join-Path ([Environment]::GetFolderPath('Desktop')) "eski_ayarlara_don.ps1"
        Set-Content -Path $restorePath -Value ($restoreLines -join "`r`n") -Encoding UTF8 -ErrorAction Stop
        Write-Host "`n[BILGI] Eski ayarlara donmek icin masaustundeki 'eski_ayarlara_don.ps1' dosyasini Yonetici olarak calistirin." -ForegroundColor Cyan
    } catch { Write-Host "[UYARI] Geri alma dosyasi olusturulamadi." -ForegroundColor Yellow }
}

Write-Host "`n=========================================================" -ForegroundColor DarkCyan
Write-Host "   SON ADIM: userconfig.cfg DOSYASINI OYUN KLASORUNE TASI" -ForegroundColor Yellow
Write-Host "=========================================================" -ForegroundColor DarkCyan
Write-Host "Masaustunde olusturulan 'userconfig.cfg' dosyasini kopyalayip"
Write-Host "CS 1.6 kurulumunuzdaki 'cstrike' klasorune yapistirin, ornegin:"
Write-Host "  C:\...\Counter-Strike 1.6\cstrike\userconfig.cfg" -ForegroundColor Green
Write-Host "Ardindan oyunu (yeniden) baslatin, ayarlar otomatik yuklenecektir."

Write-Host "`n=== ISLEM TAMAMLANDI ===" -ForegroundColor Cyan
Write-Host "Bol fraglar, iyi hs'ler! -Ay Yildiz | Silva" -ForegroundColor Magenta
Write-Host "Devam etmek icin bir tusa basin..."
[void][System.Console]::ReadKey($true)
