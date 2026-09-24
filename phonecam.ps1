<#
  ANDROID.webcam.OBS - use any Android phone as a webcam for OBS on Windows (via scrcpy).

  Commands:
    setup                       install scrcpy if needed, detect phones, write config.json
    start  [-Phone N] [-Light]  start camera(s) in the background (auto-reconnect)
    stop   [-Phone N]           stop camera(s) (and the flashlight)
    status                      show phones, connection and what is running
    wifi   [-Phone N]           switch a USB-connected phone to Wi-Fi (then unplug the cable)
    rotate [-Phone N]           rotate the picture by 90 degrees and restart
    run    -Phone N [-Light]    (internal) the reconnect loop for one phone

  -Phone 0 (default) means "all phones in config.json".
  Built at REAILISM.DEV - MIT license.
#>
param(
    [Parameter(Position = 0)]
    [ValidateSet('setup', 'start', 'stop', 'status', 'wifi', 'rotate', 'run')]
    [string]$Command = 'status',
    [int]$Phone = 0,
    [switch]$Light
)

# 'Continue': in Windows PowerShell 5.1 native stderr (adb/scrcpy log lines) would otherwise become terminating errors
$ErrorActionPreference = 'Continue'
$Root = $PSScriptRoot
$ConfigPath = Join-Path $Root 'config.json'
$ScriptPath = $MyInvocation.MyCommand.Path

# ---------------------------------------------------------------- helpers

function Say([string]$Text, [string]$Color = 'Gray') { Write-Host $Text -ForegroundColor $Color }

function Find-Scrcpy {
    # 1) portable copy next to this script, 2) PATH / winget alias, 3) newest winget package folder
    $local = Get-ChildItem -Path (Join-Path $Root 'scrcpy') -Filter scrcpy.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($local) { return $local.FullName }
    $cmd = Get-Command scrcpy.exe -ErrorAction SilentlyContinue
    if ($cmd -and (Test-Path (Join-Path (Split-Path $cmd.Source) 'adb.exe'))) { return $cmd.Source }
    $pkgs = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    $found = Get-ChildItem -Path $pkgs -Filter scrcpy.exe -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -like '*Genymobile.scrcpy*' } |
        Sort-Object { [version](($_.Directory.Name -replace '^.*-v', '') -replace '[^0-9.]', '') } -Descending |
        Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}

function Get-Tools {
    $scrcpy = Find-Scrcpy
    if (-not $scrcpy) { throw 'scrcpy not found. Run SETUP first.' }
    $adb = Join-Path (Split-Path $scrcpy) 'adb.exe'
    return @{ Scrcpy = $scrcpy; Adb = $adb }
}

function Invoke-Adb([string]$Adb, [string[]]$AdbArgs) {
    $out = & $Adb @AdbArgs 2>&1 | ForEach-Object { "$_" }
    return ($out -join "`n").Trim()
}

function Get-AdbDevices([string]$Adb) {
    # returns objects: Id (usb serial or ip:port), State, Transport (usb/wifi), HwSerial
    $lines = (Invoke-Adb $Adb @('devices')) -split "`n" | Select-Object -Skip 1
    $list = @()
    foreach ($l in $lines) {
        if ($l -match '^(\S+)\s+(device|unauthorized|offline)') {
            $id = $Matches[1]; $state = $Matches[2]
            $hw = if ($state -eq 'device') { Invoke-Adb $Adb @('-s', $id, 'shell', 'getprop', 'ro.serialno') } else { '' }
            $list += [pscustomobject]@{ Id = $id; State = $state; Transport = $(if ($id -match ':\d+$') { 'wifi' } else { 'usb' }); HwSerial = $hw }
        }
    }
    return $list
}

function Read-Config {
    if (-not (Test-Path $ConfigPath)) { throw 'config.json not found. Run SETUP first.' }
    $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    return $cfg
}

function Save-Config($Cfg) {
    $Cfg | ConvertTo-Json -Depth 6 | Set-Content -Path $ConfigPath -Encoding UTF8
}

function Select-Phones($Cfg, [int]$N) {
    if ($N -eq 0) { return @($Cfg.phones) }
    $p = @($Cfg.phones | Where-Object { $_.index -eq $N })
    if (-not $p) { throw "Phone $N is not in config.json. Run SETUP." }
    return $p
}

function Resolve-DeviceId([string]$Adb, $P) {
    # find the current adb id of a configured phone (USB serial or Wi-Fi address)
    $devs = Get-AdbDevices $Adb | Where-Object { $_.State -eq 'device' }
    $hit = $devs | Where-Object { $_.HwSerial -eq $P.hwSerial } | Sort-Object { $_.Transport -ne 'usb' } | Select-Object -First 1
    if ($hit) { return $hit.Id }
    if ($P.wifiAddress) {
        Invoke-Adb $Adb @('connect', $P.wifiAddress) | Out-Null
        $devs = Get-AdbDevices $Adb | Where-Object { $_.State -eq 'device' -and $_.HwSerial -eq $P.hwSerial }
        if ($devs) { return ($devs | Select-Object -First 1).Id }
    }
    return $null
}

function Get-LoopProcesses([int]$N) {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" | Where-Object {
        $_.CommandLine -like '*phonecam.ps1*' -and $_.CommandLine -match '\brun\b' -and
        ($N -eq 0 -or $_.CommandLine -match "-Phone $N(\s|$)") -and $_.ProcessId -ne $PID
    }
}

function Get-ScrcpyProcesses([int]$N) {
    Get-CimInstance Win32_Process -Filter "Name='scrcpy.exe'" | Where-Object {
        $_.CommandLine -like '*PHONECAM*' -and ($N -eq 0 -or $_.CommandLine -like "*PHONECAM $N`"*" -or $_.CommandLine -like "*PHONECAM $N *")
    }
}

function Stop-Phone([int]$N) {
    Get-LoopProcesses $N | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Get-ScrcpyProcesses $N | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Build-ScrcpyArgs($P, [string]$DeviceId, [bool]$Torch) {
    $a = @('-s', $DeviceId, '--video-codec=h264', "--video-bit-rate=$($P.bitRate)")
    if ($P.mode -eq 'camera') {
        $a += @('--video-source=camera', "--camera-id=$($P.cameraId)", "--camera-size=$($P.cameraSize)", "--camera-fps=$($P.cameraFps)")
        if ($Torch) { $a += '--camera-torch' }
    } else {
        # --keep-active (scrcpy 4.0+) works over Wi-Fi too and writes no settings (unlike --stay-awake)
        $a += @("--max-size=$($P.maxSize)", '--keep-active')
        if ($P.screenOff) { $a += '--turn-screen-off' }
    }
    if ($P.audio -eq 'mic') { $a += '--audio-source=mic' } else { $a += '--no-audio' }
    if ($P.orientation -ne 0) { $a += "--orientation=$($P.orientation)" }
    $a += @("--window-title=PHONECAM $($P.index)", '--window-borderless', "--window-x=$($P.windowX)", "--window-y=$($P.windowY)")
    if ($P.mode -eq 'camera') {
        $w, $h = $P.cameraSize -split 'x'
        if ($P.orientation -in 90, 270) { $w, $h = $h, $w }
        $a += @("--window-width=$w", "--window-height=$h")
    }
    return $a
}

# ---------------------------------------------------------------- setup

function Get-ScrcpyVersion([string]$Scrcpy) {
    $v = (& $Scrcpy --version 2>&1 | Select-Object -First 1) -replace '^scrcpy\s+(\S+).*$', '$1'
    try { return [version]$v } catch { return [version]'0.0' }
}

function Install-Scrcpy {
    $s = Find-Scrcpy
    if ($s) {
        # 4.0 added --camera-torch; 4.1 fixed "Camera configuration error" on some Galaxy A / POCO phones
        $v = Get-ScrcpyVersion $s
        if ($v -lt [version]'4.1') {
            Say "scrcpy $v is too old (need 4.1+ for camera mode and the flashlight)." Yellow
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                $ans = Read-Host 'Upgrade scrcpy with winget now? [Y/n]'
                if ($ans -notmatch '^[nN]') { & winget upgrade --id Genymobile.scrcpy -e --accept-source-agreements --accept-package-agreements }
            }
        }
        return
    }
    Say 'scrcpy is not installed. Installing it with winget (Genymobile.scrcpy)...' Yellow
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget is not available. Download scrcpy for Windows from https://github.com/Genymobile/scrcpy/releases and unzip it into a "scrcpy" folder next to this script.'
    }
    & winget install --id Genymobile.scrcpy -e --accept-source-agreements --accept-package-agreements
    if (-not (Find-Scrcpy)) { throw 'scrcpy install failed. See the message above.' }
}

function Get-Prop([string]$Adb, [string]$Id, [string]$Name) { Invoke-Adb $Adb @('-s', $Id, 'shell', 'getprop', $Name) }

function Pick-Camera([string]$Scrcpy, [string]$Id) {
    # choose the first back camera and the best 16:9 size up to 1920x1080
    $list = & $Scrcpy -s $Id --list-cameras 2>&1 | ForEach-Object { "$_" }
    $cams = @()
    foreach ($l in $list) {
        if ($l -match '--camera-id=(\S+)\s+\((back|front|external)[^)]*fps=\{([^}]*)\}') {
            $cams += [pscustomobject]@{ Id = $Matches[1]; Facing = $Matches[2]; Fps = ($Matches[3] -split ',\s*' | ForEach-Object { [int]$_ }) }
        }
    }
    if (-not $cams) { return $null }
    $cam = ($cams | Where-Object Facing -eq 'back' | Select-Object -First 1)
    if (-not $cam) { $cam = $cams[0] }

    $sizesOut = & $Scrcpy -s $Id --list-camera-sizes 2>&1 | ForEach-Object { "$_" }
    $sizes = @(); $inCam = $false
    foreach ($l in $sizesOut) {
        if ($l -match '--camera-id=(\S+)') { $inCam = ($Matches[1] -eq $cam.Id); continue }
        if ($l -match 'High speed') { $inCam = $false; continue }
        if ($inCam -and $l -match '^\s*-\s*(\d+)x(\d+)') { $sizes += [pscustomobject]@{ W = [int]$Matches[1]; H = [int]$Matches[2] } }
    }
    $pref = @('1920x1080', '1280x720', '1600x900', '2560x1440', '3840x2160')
    $size = $null
    foreach ($s in $pref) { if ($sizes | Where-Object { "$($_.W)x$($_.H)" -eq $s }) { $size = $s; break } }
    if (-not $size) {
        $wide = $sizes | Where-Object { [math]::Abs($_.W / $_.H - 16 / 9) -lt 0.02 -and $_.W -le 1920 } | Sort-Object W -Descending | Select-Object -First 1
        if (-not $wide) { $wide = $sizes | Where-Object { $_.W -le 1920 } | Sort-Object W -Descending | Select-Object -First 1 }
        if ($wide) { $size = "$($wide.W)x$($wide.H)" } else { $size = '1280x720' }
    }
    $fps = if ($cam.Fps -contains 30) { 30 } else { ($cam.Fps | Measure-Object -Maximum).Maximum }
    return [pscustomobject]@{ Id = $cam.Id; Facing = $cam.Facing; Size = $size; Fps = $fps; All = $cams }
}

$BrandTips = [ordered]@{
    # ro.product.brand pattern = where the "uses the front camera" features live (see docs/COMPATIBILITY.md)
    'samsung'           = 'Settings > Advanced features > Motions and gestures > Keep screen on while viewing: OFF. One UI 6+: Security and privacy > Auto Blocker: OFF (it blocks USB debugging).'
    'google'            = 'Settings > Display > Screen timeout > Screen attention / Adaptive timeout: OFF; Auto-rotate > Face Detection: OFF.'
    'motorola'          = 'Settings > Display > Screen timeout > Attentive Display: OFF.'
    'oppo|realme|oneplus' = 'Settings > Display & brightness > Adaptive Sleep (Screen attention): OFF; Smart notification hiding: OFF.'
    'vivo|iqoo'         = 'Settings > Smart motion > Smart turn on/off screen > Smart keep bright: OFF.'
    'huawei'            = 'Settings > Accessibility features > Smart Sensing: turn everything OFF. Developer options: "Allow ADB debugging in charge only mode": ON.'
    'honor'             = 'Settings > HONOR AI (or Assistant) > Smart Sensing: OFF, Eye Tracking: OFF. Developer options: "Allow ADB debugging in charge only mode": ON.'
    'xiaomi|redmi|poco' = 'HyperOS: turn off "Gaze detection" if your model has it. Taps from the PC need Developer options > "USB debugging (Security settings)" (video does not).'
    'nothing|cmf'       = 'Settings > Display > Screen timeout > Screen attention: OFF.'
    'asus'              = 'Older ZenUI: Display > Smart Screen On: OFF.'
}

function Show-BrandTip([string]$Brand) {
    foreach ($k in $BrandTips.Keys) { if ($Brand -match "^($k)") { Say "  tip ($Brand): $($BrandTips[$k])" DarkYellow; return } }
}

function Fix-CameraThieves([string]$Adb, [string]$Id, [string]$Brand) {
    # background features that open the front camera and kick scrcpy's camera out
    Show-BrandTip $Brand
    $known = @(
        @{ Brand = 'samsung'; Ns = 'system'; Key = 'intelligent_sleep_mode'; Name = 'Smart stay / Keep screen on while viewing' },
        @{ Brand = 'google';  Ns = 'secure'; Key = 'adaptive_sleep';         Name = 'Screen attention' }
    )
    foreach ($k in $known | Where-Object { $Brand -like "*$($_.Brand)*" }) {
        $v = Invoke-Adb $Adb @('-s', $Id, 'shell', 'settings', 'get', $k.Ns, $k.Key)
        if ($v -eq '1') {
            Say "  '$($k.Name)' is ON - it uses the front camera and can cut the webcam every few seconds." Yellow
            $ans = Read-Host '  Turn it OFF on the phone now? [Y/n]'
            if ($ans -notmatch '^[nN]') {
                Invoke-Adb $Adb @('-s', $Id, 'shell', 'settings', 'put', $k.Ns, $k.Key, '0') | Out-Null
                Say "  '$($k.Name)' turned OFF." Green
            }
        }
    }
}

function Get-PrimaryMonitorId {
    # OBS "Display Capture" identifies a monitor by its device interface path, e.g. \\?\DISPLAY#ABC1234#...#{e6f07b5f-...}
    Add-Type -AssemblyName System.Windows.Forms
    if (-not ('PhonecamMon' -as [type])) {
        Add-Type @'
using System; using System.Runtime.InteropServices;
public class PhonecamMon {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DD {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
    }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern bool EnumDisplayDevices(string device, int index, ref DD dd, int flags);
    public static string MonitorId(string adapter) {
        var d = new DD(); d.cb = Marshal.SizeOf(d);
        return EnumDisplayDevices(adapter, 0, ref d, 1) ? d.DeviceID : null;   // 1 = EDD_GET_DEVICE_INTERFACE_NAME
    }
}
'@
    }
    return [PhonecamMon]::MonitorId([System.Windows.Forms.Screen]::PrimaryScreen.DeviceName)
}

function Write-ObsScenes {
    # obs\ANDROID.webcam.OBS.json is a template; write obs\my-scenes.json with this PC's primary monitor filled in
    $tpl = Join-Path $Root 'obs\ANDROID.webcam.OBS.json'
    if (-not (Test-Path $tpl)) { return }
    $json = Get-Content $tpl -Raw
    $mon = Get-PrimaryMonitorId
    if ($mon) { $json = $json.Replace('"__PRIMARY_MONITOR__"', ($mon | ConvertTo-Json)) }
    $out = Join-Path $Root 'obs\my-scenes.json'
    [IO.File]::WriteAllText($out, $json, (New-Object Text.UTF8Encoding $false))
    Say "OBS scenes for this PC: $out  (OBS > Scene Collection > Import)" Green
}

function Do-Setup {
    Say "`n=== ANDROID.webcam.OBS setup ===`n" Cyan
    Install-Scrcpy
    $t = Get-Tools
    Say "scrcpy: $($t.Scrcpy)" DarkGray
    Invoke-Adb $t.Adb @('start-server') | Out-Null

    $devs = Get-AdbDevices $t.Adb
    if ($devs | Where-Object State -eq 'unauthorized') {
        Say 'A phone is waiting for permission: unlock it and tap "Allow USB debugging" (tick "Always allow").' Yellow
        Read-Host 'Press Enter when done'
        $devs = Get-AdbDevices $t.Adb
    }
    $ready = @($devs | Where-Object State -eq 'device')
    if (-not $ready) {
        Say 'No phone found. Check: USB debugging is ON, the cable carries data, the phone is unlocked.' Red
        Say 'See docs/COMPATIBILITY.md for your brand.' Red
        return
    }

    $old = if (Test-Path $ConfigPath) { Read-Config } else { $null }
    $phones = @(); $i = 0
    foreach ($d in ($ready | Sort-Object Transport, Id | Group-Object HwSerial | ForEach-Object { $_.Group[0] })) {
        $i++
        $brand = (Get-Prop $t.Adb $d.Id 'ro.product.brand').ToLower()
        $model = Get-Prop $t.Adb $d.Id 'ro.product.model'
        $rel = Get-Prop $t.Adb $d.Id 'ro.build.version.release'
        $sdk = [int](Get-Prop $t.Adb $d.Id 'ro.build.version.sdk')
        Say "Phone $i : $brand $model - Android $rel (API $sdk) via $($d.Transport)" White

        $prev = if ($old) { $old.phones | Where-Object hwSerial -eq $d.HwSerial | Select-Object -First 1 } else { $null }
        $p = [ordered]@{
            index = $i; name = "$brand $model"; hwSerial = $d.HwSerial; android = $rel; sdk = $sdk
            mode = 'screen'; cameraId = ''; cameraSize = ''; cameraFps = 30; maxSize = 1920
            audio = $(if ($sdk -ge 30) { 'mic' } else { 'none' }); orientation = 0; bitRate = '12M'
            screenOff = $false; light = $false; cameraApp = ''; wifiAddress = $(if ($d.Transport -eq 'wifi') { $d.Id } else { '' })
            windowX = -5000; windowY = ($i - 1) * 1300
        }
        if ($sdk -ge 31) {
            $cam = Pick-Camera $t.Scrcpy $d.Id
            if ($cam) {
                $p.mode = 'camera'; $p.cameraId = $cam.Id; $p.cameraSize = $cam.Size; $p.cameraFps = $cam.Fps; $p.bitRate = '16M'
                Say "  mode: CAMERA (native) - camera $($cam.Id) ($($cam.Facing)), $($cam.Size) @ $($cam.Fps) fps" Green
            } else {
                Say '  Android 12+, but the phone exposes no camera to scrcpy - falling back to SCREEN mode.' Yellow
            }
        }
        if ($p.mode -eq 'screen') {
            Say '  mode: SCREEN - the phone shows a camera app, scrcpy mirrors the screen.' Yellow
            $oc = Invoke-Adb $t.Adb @('-s', $d.Id, 'shell', 'pm', 'list', 'packages', 'net.sourceforge.opencamera')
            if ($oc -match 'opencamera') {
                $p.cameraApp = 'net.sourceforge.opencamera'
                Say '  Open Camera found - it will be opened automatically. In its settings: On screen GUI > Immersive mode > "Hide everything", "Keep display on": ON.' Green
            } else {
                Say '  Recommended: install "Open Camera" (Play Store / F-Droid; Android 5 needs version 1.55), then run SETUP again.' Yellow
            }
            if ($sdk -lt 30) { Say '  audio: not available below Android 11 - use a PC microphone in OBS.' Yellow }
        }
        if ($sdk -eq 30) { Say '  Android 11: keep the phone UNLOCKED when the camera starts, or phone audio will not start.' Yellow }
        if ($prev) { foreach ($k in 'orientation', 'light', 'screenOff', 'bitRate', 'cameraApp') { if ($null -ne $prev.$k -and "$($prev.$k)" -ne '') { $p[$k] = $prev.$k } } }
        if ($p.mode -eq 'camera') { Fix-CameraThieves $t.Adb $d.Id $brand } else { Show-BrandTip $brand }
        $phones += [pscustomobject]$p
    }
    Save-Config ([pscustomobject]@{ version = 1; phones = $phones })
    Say "`nSaved: $ConfigPath" Green
    Write-ObsScenes
    Say 'Next: run CAMERA-ON.bat, then import obs\my-scenes.json in OBS (or add a Window Capture of "[scrcpy.exe]: PHONECAM 1").' Cyan
}

# ---------------------------------------------------------------- run loop

function Do-Run([int]$N, [bool]$Torch) {
    $t = Get-Tools
    $cfg = Read-Config
    $p = Select-Phones $cfg $N | Select-Object -First 1
    $Host.UI.RawUI.WindowTitle = "PHONECAM $N loop"
    Say "PHONECAM $N - $($p.name) - $($p.mode) mode. Close this window to stop the camera." Cyan
    while ($true) {
        $id = Resolve-DeviceId $t.Adb $p
        if (-not $id) { Say "$(Get-Date -f HH:mm:ss) waiting for the phone..." DarkGray; Start-Sleep 3; continue }
        if ($p.mode -eq 'screen' -and $p.cameraApp) {
            # bring the camera app to the front (Android 9+ lets only the foreground app use the camera)
            Invoke-Adb $t.Adb @('-s', $id, 'shell', 'monkey', '-p', $p.cameraApp, '-c', 'android.intent.category.LAUNCHER', '1') | Out-Null
            Start-Sleep 2
        }
        $a = Build-ScrcpyArgs $p $id $Torch
        Say "$(Get-Date -f HH:mm:ss) starting: scrcpy $($a -join ' ')" DarkGray
        & $t.Scrcpy @a 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -match 'ERROR|WARN' } | ForEach-Object { Say "  $_" Yellow }
        Say "$(Get-Date -f HH:mm:ss) camera stopped - reconnecting in 3 s" Yellow
        Start-Sleep 3
    }
}

# ---------------------------------------------------------------- commands

switch ($Command) {
    'setup' { Do-Setup }

    'run' { if ($Phone -lt 1) { throw 'run needs -Phone N' }; Do-Run $Phone $Light.IsPresent }

    'start' {
        $cfg = Read-Config
        foreach ($p in (Select-Phones $cfg $Phone)) {
            Stop-Phone $p.index
            $torch = $Light.IsPresent -and $p.mode -eq 'camera'
            $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" run -Phone $($p.index)" + $(if ($torch) { ' -Light' } else { '' })
            Start-Process powershell.exe -ArgumentList $argList -WindowStyle Minimized
            $lightTxt = if ($torch) { ', flashlight ON' } elseif ($Light -and $p.mode -ne 'camera') { ' (flashlight needs CAMERA mode)' } else { '' }
            Say "Phone $($p.index) ($($p.name)): camera ON$lightTxt" Green
        }
    }

    'stop' {
        Stop-Phone $Phone
        Say $(if ($Phone -eq 0) { 'All cameras OFF.' } else { "Phone $Phone camera OFF." }) Green
    }

    'status' {
        $t = Get-Tools
        $cfg = Read-Config
        $devs = Get-AdbDevices $t.Adb
        foreach ($p in $cfg.phones) {
            $conn = ($devs | Where-Object { $_.HwSerial -eq $p.hwSerial -and $_.State -eq 'device' } | ForEach-Object Transport) -join '+'
            $run = [bool](Get-ScrcpyProcesses $p.index)
            $loop = [bool](Get-LoopProcesses $p.index)
            Say ("Phone {0}: {1,-28} Android {2,-4} mode={3,-6} connected={4,-8} camera={5}" -f $p.index, $p.name, $p.android, $p.mode, $(if ($conn) { $conn } else { 'no' }), $(if ($run) { 'ON' } elseif ($loop) { 'waiting' } else { 'off' }))
        }
    }

    'wifi' {
        $t = Get-Tools
        $cfg = Read-Config
        foreach ($p in (Select-Phones $cfg $Phone)) {
            $usb = Get-AdbDevices $t.Adb | Where-Object { $_.HwSerial -eq $p.hwSerial -and $_.Transport -eq 'usb' -and $_.State -eq 'device' } | Select-Object -First 1
            if (-not $usb) { Say "Phone $($p.index): connect it by USB first (only needed once per phone reboot)." Yellow; continue }
            $ipLine = Invoke-Adb $t.Adb @('-s', $usb.Id, 'shell', 'ip', '-f', 'inet', 'addr', 'show', 'wlan0')
            if ($ipLine -notmatch 'inet (\d+\.\d+\.\d+\.\d+)') { Say "Phone $($p.index): Wi-Fi is off or not connected." Yellow; continue }
            $ip = $Matches[1]
            $net = ($ip -split '\.')[0..2] -join '.'
            $pcIps = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object IPAddress)
            if (-not ($pcIps | Where-Object { $_ -like "$net.*" })) {
                $lan = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4DefaultGateway } | ForEach-Object { "$($_.IPv4Address.IPAddress) ($($_.InterfaceAlias))" })
                Say "Phone $($p.index): the phone is on $net.x but this PC is on $($lan -join ', ') - connect both to the same Wi-Fi network." Yellow
                continue
            }
            Invoke-Adb $t.Adb @('-s', $usb.Id, 'tcpip', '5555') | Out-Null
            Start-Sleep 2
            $r = Invoke-Adb $t.Adb @('connect', "${ip}:5555")
            if ($r -match 'connected') {
                $p.wifiAddress = "${ip}:5555"
                Say "Phone $($p.index): Wi-Fi ready at ${ip}:5555 - you can unplug the cable." Green
            } else { Say "Phone $($p.index): Wi-Fi connect failed: $r" Red }
        }
        Save-Config $cfg
    }

    'rotate' {
        $cfg = Read-Config
        foreach ($p in (Select-Phones $cfg $Phone)) {
            $p.orientation = ($p.orientation + 90) % 360
            Say "Phone $($p.index): picture rotation = $($p.orientation) degrees" Green
        }
        Save-Config $cfg
        foreach ($p in (Select-Phones $cfg $Phone)) {
            $wasTorch = [bool](Get-ScrcpyProcesses $p.index | Where-Object { $_.CommandLine -like '*--camera-torch*' })
            if (Get-LoopProcesses $p.index) {
                & $ScriptPath start -Phone $p.index -Light:$wasTorch
            }
        }
    }
}
