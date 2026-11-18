param(
    [string]$GameExePath,
    [switch]$PrepareOnly,
    [switch]$MonitorOnly
)

# OMORI Rumble Auto-Updater & Launcher
#
# ========================================================
# CONFIGURATION (Optional)
# ========================================================
# To customize the launcher, create a file named "config.txt" 
# in the same folder as this script. See the config.txt file
# for a full list of options, custom themes, and presets!
# ========================================================

# Force TLS 1.2 for GitHub connections
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Define current directory FIRST so the quote reader can use it
 $currentDir = Split-Path -Path $PSCommandPath -Parent

# ========================================================
#      C O N F I G   R E A D E R
# ========================================================
 $configFile = Join-Path $currentDir 'config.txt'
 $isDebug = $false
 $isAuto = $false
 $selectedTheme = "random"
 $aprilFools = $false
 $customThemeStr = $null
 $overrideOmoriPath = $null
 $launchMethod = "steam"

if (Test-Path $configFile) {
    $configContent = Get-Content $configFile -ErrorAction SilentlyContinue
    foreach ($line in $configContent) {
        $line = $line.Trim()
        if ($line -match '^Debug\s*=\s*(.+)$') {
            $val = $matches[1].Trim()
            if ($val -match '^(true|1|yes)$') { $isDebug = $true }
        }
        elseif ($line -match '^Auto\s*=\s*(.+)$') {
            $val = $matches[1].Trim()
            if ($val -match '^(true|1|yes)$') { $isAuto = $true }
        }
        elseif ($line -match '^Theme\s*=\s*(.+)$') {
            $selectedTheme = $matches[1].Trim().ToLower()
        }
        elseif ($line -match '^CustomTheme\s*=\s*(.+)$') {
            $customThemeStr = $matches[1].Trim()
        }
        elseif ($line -match '^AprilFools\s*=\s*(.+)$') {
            $val = $matches[1].Trim()
            if ($val -match '^(true|1|yes)$') { $aprilFools = $true }
        }
        elseif ($line -match '^OmoriPath\s*=\s*(.+)$') {
            $val = $matches[1].Trim().Trim('"')
            if ($val -ne '') { $overrideOmoriPath = $val }
        }
        elseif ($line -match '^LaunchMethod\s*=\s*(.+)$') {
            $val = $matches[1].Trim().ToLower()
            if ($val -match '^(direct|steam)$') {
                $launchMethod = $val
            } else {
                $launchMethod = "steam"
            }
        }
    }
}

function Write-DebugMsg {
    param([string]$Message)
    if ($isDebug) {
        Write-Host "  [DBG] $Message" -ForegroundColor DarkMagenta
    }
}

# ========================================================
#            G L O B A L   V A R I A B L E S
# ========================================================
 $repoOwner = 'uniseth'
 $repoName = 'OMORI-Controller-Rumble'
 $steamAppId = '1150690'
 $tempDir = $env:TEMP
 $extractDir = Join-Path $tempDir 'RumbleBridge_Extract'
 $bridgeExe = Join-Path $currentDir 'RumbleBridge.exe'
 $bridgeDll = Join-Path $currentDir 'ViGEmClient.dll'
 $localModDir = Join-Path $currentDir 'rumble'
 $logFile = Join-Path $currentDir 'bridge_log.txt'
 $bridgeReady = $false
 $modReady = $false

# =========================================================================
# PRE-STEP: KILL STALE BRIDGE PROCESSES (Skip if we are just monitoring)
# =========================================================================
if (-not $MonitorOnly) {
    try {
        $existingBridges = Get-Process -Name "RumbleBridge" -ErrorAction SilentlyContinue
        if ($existingBridges) {
            Write-Host "[INFO] " -ForegroundColor Blue -NoNewline
            Write-Host "Found $($existingBridges.Count) leftover RumbleBridge process(es). Killing them..." -ForegroundColor DarkYellow
            Write-DebugMsg "Pre-Step: Killing existing RumbleBridge processes. PIDs: $($existingBridges.Id -join ', ')"
            $existingBridges | Stop-Process -Force
            Start-Sleep -Seconds 2
        }
    } catch {
        Write-DebugMsg "Pre-Step: Error checking/killing processes: $($_.Exception.Message)"
    }
    
    # Safely attempt to clear old log without throwing errors if C++ still has it locked
    try { Remove-Item $logFile -Force -ErrorAction Stop } catch { }
}

# ========================================================
#                  A S C I I   A R T
# ========================================================
# Skip drawing the UI if we are running in silent PrepareOnly mode
if (-not $PrepareOnly) {
    $normalArt = @(
        '__________________________________________________/\\\_________/\\\\\\___________________        ',
        ' _________________________________________________\/\\\________\////\\\___________________       ',
        '  _________________________________________________\/\\\___________\/\\\___________________      ',
        '   __/\\/\\\\\\\___/\\\____/\\\____/\\\\\__/\\\\\___\/\\\___________\/\\\________/\\\\\\\\__     ',
        '    _\/\\\/////\\\_\/\\\___\/\\\__/\\\///\\\\\///\\\_\/\\\\\\\\\_____\/\\\______/\\\/////\\\_    ',
        '     _\/\\\___\///__\/\\\___\/\\\_\/\\\_\//\\\__\/\\\_\/\\\////\\\____\/\\\_____/\\\\\\\\\\\__   ',
        '      _\/\\\_________\/\\\___\/\\\_\/\\\__\/\\\__\/\\\_\/\\\__\/\\\____\/\\\____\//\\///////___  ',
        '       _\/\\\_________\//\\\\\\\\\__\/\\\__\/\\\__\/\\\_\/\\\\\\\\\___/\\\\\\\\\__\//\\\\\\\\\\_ ',
        '        _\///___________\/////////___\///___\///___\///__\/////////___\/////////____\//////////__'
    )
    $aprilFoolsArt = @(
        '_________________/\\\\\\_____/\\\________________________________________________________        ',
        ' ________________\////\\\____\/\\\________________________________________________________       ',
        '  ___________________\/\\\____\/\\\________________________________________________________      ',
        '   _____/\\\\\\\\_____\/\\\____\/\\\___________/\\\\\__/\\\\\____/\\\____/\\\__/\\/\\\\\\\__     ',
        '    ___/\\\/////\\\____\/\\\____\/\\\\\\\\\___/\\\///\\\\\///\\\_\/\\\___\/\\\_\/\\\/////\\\_    ',
        '     __/\\\\\\\\\\\_____\/\\\____\/\\\////\\\_\/\\\_\//\\\__\/\\\_\/\\\___\/\\\_\/\\\___\///__   ',
        '      _\//\\///////______\/\\\____\/\\\__\/\\\_\/\\\__\/\\\__\/\\\_\/\\\___\/\\\_\/\\\_________  ',
        '       __\//\\\\\\\\\\__/\\\\\\\\\_\/\\\\\\\\\__\/\\\__\/\\\__\/\\\_\//\\\\\\\\\__\/\\\_________ ',
        '        ___\//////////__\/////////__\/////////___\///___\///___\///___\/////////___\///__________ '
    )

    $themeMap = @{fass
        'og'          = "DarkCyan,DarkCyan,Cyan,Cyan,White,Magenta,White,Cyan,DarkCyan"
        'trans'       = "Cyan,Cyan,Magenta,Magenta,White,Magenta,Magenta,Cyan,Cyan"
        'nonbinary'   = "Yellow,Yellow,White,White,Magenta,Magenta,Magenta,DarkGray,DarkGray"
        'pan'         = "Magenta,Magenta,Magenta,Yellow,Yellow,Yellow,Cyan,Cyan,Cyan"
        'bi'          = "Magenta,Magenta,Magenta,DarkMagenta,Blue,Blue,Blue,DarkBlue,DarkBlue"
        'lesbian'     = "DarkRed,DarkRed,Red,Red,White,Magenta,Magenta,DarkMagenta,DarkMagenta"
        'gay'         = "Green,Green,Green,Green,Blue,Blue,Magenta,Magenta,DarkMagenta"
        'ace'         = "DarkGray,DarkGray,Gray,Gray,White,White,Magenta,Magenta,Magenta"
        'aro'         = "DarkGreen,DarkGreen,Green,Green,White,Gray,Gray,DarkGray,DarkGray"
        'genderfluid' = "Magenta,Magenta,White,White,Magenta,Magenta,DarkGray,DarkGray,Blue"
        'progress'    = "DarkRed,Red,DarkYellow,Yellow,Green,Blue,DarkMagenta,White,Magenta"
        'white'       = "White,White,White,White,White,White,White,White,White"
        'cyan'        = "Cyan,Cyan,Cyan,Cyan,Cyan,Cyan,Cyan,Cyan,Cyan"
        'magenta'     = "Magenta,Magenta,Magenta,Magenta,Magenta,Magenta,Magenta,Magenta,Magenta"
        'red'         = "Red,Red,Red,Red,Red,Red,Red,Red,Red"
        'green'       = "Green,Green,Green,Green,Green,Green,Green,Green,Green"
        'yellow'      = "Yellow,Yellow,Yellow,Yellow,Yellow,Yellow,Yellow,Yellow,Yellow"
        'gray'        = "Gray,Gray,Gray,Gray,Gray,Gray,Gray,Gray,Gray"
        'matrix'      = "DarkGreen,DarkGreen,Green,Green,Green,Green,Green,DarkGreen,DarkGreen"
        'amber'       = "DarkYellow,DarkYellow,Yellow,Yellow,Yellow,Yellow,Yellow,DarkYellow,DarkYellow"
        'dos'         = "DarkBlue,DarkBlue,Blue,Blue,White,Blue,Blue,DarkBlue,DarkBlue"
        'retro'       = "Cyan,Magenta,Yellow,Blue,White,Blue,Yellow,Magenta,Cyan"
        'bloodmoon'   = "Red,Red,Yellow,Yellow,White,Gray,Gray,DarkGray,DarkGray"
        'gradientblue'= "DarkBlue,DarkBlue,Blue,Blue,Cyan,Cyan,White,White,White"
        'gradientred' = "DarkGray,DarkRed,Red,Red,Magenta,Magenta,White,White,White"
        'gradientpink'= "DarkMagenta,DarkMagenta,Magenta,Magenta,Magenta,White,White,Gray,Gray"
        'gradientcyan'= "White,White,Cyan,Cyan,Blue,Blue,DarkBlue,DarkBlue,DarkBlue"
        'gradientyellow' = "White,White,Yellow,Yellow,Red,Red,DarkRed,DarkRed,DarkRed"
        'heart'       = "DarkRed,DarkRed,Red,White,White,White,Red,DarkRed,DarkRed"
        'monochrome'  = "DarkGray,DarkGray,DarkGray,Gray,White,Gray,DarkGray,DarkGray,DarkGray"
        'xmas'        = "Red,Green,Red,Green,White,Green,Red,Green,Red"
        'halloween'   = "DarkYellow,DarkYellow,Red,Red,White,Red,Red,DarkYellow,DarkYellow"
        'valentine'   = "Magenta,Magenta,Red,Red,White,Red,Red,Magenta,Magenta"
        'easter'      = "Cyan,Yellow,Magenta,Green,White,Green,Magenta,Yellow,Cyan"
        'stpatricks'  = "Green,Green,Green,White,Yellow,White,Green,Green,Green"
        'july4'       = "Red,Red,White,White,Blue,Blue,White,White,Red"
    }

    $validColors = @("Black","DarkBlue","DarkGreen","DarkCyan","DarkRed","DarkMagenta","DarkYellow","Gray","DarkGray","Blue","Green","Cyan","Red","Magenta","Yellow","White")
    $chosenScheme = $null

    if ($selectedTheme -eq "random") {
        $today = Get-Date; $m = $today.Month; $d = $today.Day; $autoHoliday = $null
        if ($m -eq 2 -and $d -eq 14) { $autoHoliday = "valentine" } elseif ($m -eq 3 -and $d -eq 17) { $autoHoliday = "stpatricks" } elseif ($m -eq 7 -and $d -eq 4) { $autoHoliday = "july4" } elseif ($m -eq 10 -and $d -eq 31) { $autoHoliday = "halloween" } elseif ($m -eq 12 -and $d -eq 25) { $autoHoliday = "xmas" }
        if ($autoHoliday) { $selectedTheme = $autoHoliday }
    }
    if ($selectedTheme -match ',') { $chosenScheme = $selectedTheme -split ',' }
    elseif ($selectedTheme -eq 'custom') { if ($customThemeStr) { $chosenScheme = $customThemeStr -split ',' } }
    elseif ($themeMap.ContainsKey($selectedTheme)) { $chosenScheme = $themeMap[$selectedTheme] -split ',' }

    if ($null -eq $chosenScheme) {
        $randomSchemes = $themeMap.Values | Get-Random
        $chosenScheme = $randomSchemes -split ','
    }

    if ($aprilFools) { $displayArt = $aprilFoolsArt } else { $displayArt = $normalArt }
    Write-Host ''
    for ($i = 0; $i -lt $displayArt.Count; $i++) { Write-Host $displayArt[$i] -ForegroundColor $chosenScheme[$i] }
    Write-Host ''
    Write-Host '                    >> O M O R I   C O N T R O L L E R <<' -ForegroundColor DarkGray
    Write-Host '============================================================' -ForegroundColor DarkGray

    $quotesFile = Join-Path $currentDir 'quotes.txt'
    $quoteToDisplay = "Waiting for something to happen?"
    if (Test-Path $quotesFile) { $quotes = Get-Content $quotesFile -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne '' }; if ($quotes.Count -gt 0) { $quoteToDisplay = $quotes | Get-Random } }
    Write-Host "   $quoteToDisplay" -ForegroundColor DarkYellow
    Write-Host '============================================================' -ForegroundColor DarkGray
    Write-Host ''
}

# =========================================================================
# M O D E   B R A N C H I N G
# =========================================================================

if ($MonitorOnly) {
    # ==========================================
    # PHASE 3: MONITOR MODE
    # ==========================================
    Write-Host '====================================================================' -ForegroundColor Cyan
    Write-Host ' Rumble Bridge is running. OMORI is launching...' -ForegroundColor Cyan
    Write-Host ' Window closes automatically when you exit OMORI.' -ForegroundColor DarkGray
    Write-Host '====================================================================' -ForegroundColor Cyan

    try {
        Start-Sleep -Seconds 3 
        $lastLineCount = 0
        $lastDebugTick = Get-Date

        while ($true) {
            $bridgeRunning = [bool](Get-Process -Name "RumbleBridge" -ErrorAction SilentlyContinue)
            $omoriRunning = [bool](Get-Process -Name "OMORI*" -ErrorAction SilentlyContinue)

            if ($isDebug -and ((Get-Date) - $lastDebugTick).TotalSeconds -ge 5) {
                Write-DebugMsg "Loop Tick -> Bridge: $bridgeRunning | OMORI: $omoriRunning | LogExists: $(Test-Path $logFile) | Lines Read: $lastLineCount"
                $lastDebugTick = Get-Date
            }

            if (-not $bridgeRunning -and -not $omoriRunning) {
                Write-DebugMsg "Both processes exited. Breaking loop."
                Write-Host ''
                Write-Host '====================================================================' -ForegroundColor Red
                Write-Host ' OMORI and Rumble Bridge have closed. Exiting...' -ForegroundColor Red
                Write-Host '====================================================================' -ForegroundColor Red
                break
            }

            if (Test-Path $logFile) {
                try {
                    $lines = Get-Content $logFile -ErrorAction Stop
                    if ($lines -and $lines.Count -gt $lastLineCount) {
                        $newLines = $lines[$lastLineCount..($lines.Count - 1)]
                        Write-DebugMsg "Read $($newLines.Count) new lines from bridge_log.txt"
                        foreach ($line in $newLines) {
                            if ($line -match '^\s*=+\s*$' -or $line -match 'OMORI RUNTIME CONTROLLER BRIDGE') { continue }
                            if ($line -match 'Intensity:\s*([0-9.]+)') {
                                $intensity = [float]$matches[1]
                                if ($intensity -lt 0.35) { $color = "Green" } elseif ($intensity -le 0.70) { $color = "Yellow" } else { $color = "Red" }
                                Write-Host "  $line" -ForegroundColor $color
                            } elseif ($line -match '\[ERROR\]') { Write-Host "  $line" -ForegroundColor Red }
                            elseif ($line -match '\[HARDWARE\]') { Write-Host "  $line" -ForegroundColor Green }
                            elseif ($line -match '\[NETWORK\] Connected') { Write-Host "  $line" -ForegroundColor Green }
                            elseif ($line -match '\[NETWORK\]') { Write-Host "  $line" -ForegroundColor Cyan }
                            else { Write-Host "  $line" -ForegroundColor DarkGray }
                        }
                        $lastLineCount = $lines.Count
                    }
                } catch { Write-DebugMsg "EXCEPTION reading log file: $($_.Exception.Message)" }
            }
            Start-Sleep -Milliseconds 100
        }
    }
    finally {
        Write-Host "[INFO] " -ForegroundColor Blue -NoNewline; Write-Host "Cleaning up residual processes..." -ForegroundColor DarkYellow
        $leftoverBridges = Get-Process -Name "RumbleBridge" -ErrorAction SilentlyContinue
        if ($leftoverBridges) {
            Write-DebugMsg "Cleanup: Killing leftover PIDs: $($leftoverBridges.Id -join ', ')"
            $leftoverBridges | Stop-Process -Force
            Start-Sleep -Milliseconds 500 # Give C++ time to release file handle
            Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host "Successfully killed all RumbleBridge processes." -ForegroundColor White
        }
        try { Remove-Item $logFile -Force -ErrorAction Stop } catch { }
        Start-Sleep -Seconds 1
    }
    exit 0
}

elseif ($PrepareOnly) {
    # ==========================================
    # PHASE 1: PREPARE MODE
    # ==========================================
    
    # (STEP 1: Locate OMORI)
    Write-DebugMsg "Beginning Step 1: Locating OMORI installation..."
    Write-Host "[1/4] " -ForegroundColor Cyan -NoNewline; Write-Host "Locating OMORI installation..." -ForegroundColor White
    $omoriPath = $null; $steamPath = $null

    if ($overrideOmoriPath) {
        $testPath = Join-Path $overrideOmoriPath 'OMORI.exe'
        if (Test-Path $testPath) { $omoriPath = (Resolve-Path $overrideOmoriPath).Path } else { Write-Host "[ERROR] Could not locate OMORI." -ForegroundColor Red; exit 1 }
    } else {
        $steamRegPaths = @('HKLM:\SOFTWARE\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKCU:\SOFTWARE\Valve\Steam','HKCU:\SOFTWARE\WOW6432Node\Valve\Steam')
        foreach ($regPath in $steamRegPaths) { $p = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).InstallPath; if ($p) { $steamPath = $p; break } }
        if (-not $steamPath) { Write-Host "[ERROR] Steam is not installed." -ForegroundColor Red; exit 1 }
        $vdfPath = Join-Path $steamPath 'steamapps\libraryfolders.vdf'; $libraryPaths = @()
        if (Test-Path $vdfPath) { $vdfContent = Get-Content $vdfPath; foreach ($line in $vdfContent) { if ($line -match '^\s*"[^"]+"\s+"([A-Za-z]:\\[^"]+)"') { $extractedPath = $matches[1]; if ($extractedPath -notmatch 'steamapps\\common$') { $libraryPaths += Join-Path $extractedPath 'steamapps\common' } else { $libraryPaths += $extractedPath } } } }
        $defaultPath = Join-Path $steamPath 'steamapps\common'; if ($libraryPaths -notcontains $defaultPath) { $libraryPaths += $defaultPath }
        foreach ($libPath in $libraryPaths) { $testPath = Join-Path $libPath 'OMORI'; if (Test-Path (Join-Path $testPath 'OMORI.exe')) { $omoriPath = $testPath; break } }
        if (-not $omoriPath) { Write-Host "[ERROR] Could not locate OMORI." -ForegroundColor Red; exit 1 }
    }
    Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host "Found OMORI at: " -ForegroundColor White -NoNewline; Write-Host $omoriPath -ForegroundColor Gray; Write-Host ''

    # (STEP 2: Download)
    Write-Host "[2/4] " -ForegroundColor Cyan -NoNewline; Write-Host "Checking for latest Rumble Bridge update..." -ForegroundColor White
    $ErrorActionPreference = 'Continue'
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/releases/latest" -Headers @{'User-Agent'='RumbleBridgeUpdate'}
        $zipAssets = $release.assets | Where-Object { $_.name -like '*.zip' -and $_.name -notlike '*Source*' }
        if ($zipAssets) {
            Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host "Found $($zipAssets.Count) release file(s) to download..." -ForegroundColor White
            if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
            New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
            foreach ($zip in $zipAssets) {
                $zipPath = Join-Path $tempDir $zip.name
                Write-Host "[INFO] " -ForegroundColor Blue -NoNewline; Write-Host "Downloading: $($zip.name)" -ForegroundColor Gray
                Invoke-WebRequest -Uri $zip.browser_download_url -OutFile $zipPath
                Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
            }
            $foundExe = Get-ChildItem -Path $extractDir -Filter "RumbleBridge*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            $foundDll = Get-ChildItem -Path $extractDir -Filter "ViGEmClient.dll" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            
            $localExeExists = Test-Path $bridgeExe
            $localDllExists = Test-Path $bridgeDll
            if (($foundExe -or $foundDll) -and ($localExeExists -or $localDllExists)) {
                $doUpdate = $false; if ($isAuto) { $doUpdate = $true } else { Write-Host ''; $reply = Read-Host "Update available. Overwrite local executable files? [Y/N]"; Write-Host ''; if ($reply -match '^[Yy]') { $doUpdate = $true } }
                if ($doUpdate) { if ($foundExe) { Copy-Item $foundExe.FullName -Destination $bridgeExe -Force }; if ($foundDll) { Copy-Item $foundDll.FullName -Destination $bridgeDll -Force }; Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host "Updated executable files." -ForegroundColor White } else { Write-Host "[INFO] Keeping local files." -ForegroundColor DarkYellow }
            } elseif ($foundExe -or $foundDll) { if ($foundExe) { Copy-Item $foundExe.FullName -Destination $bridgeExe -Force }; if ($foundDll) { Copy-Item $foundDll.FullName -Destination $bridgeDll -Force } }

            $foundModJson = Get-ChildItem -Path $extractDir -Filter "mod.json" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            $localModExists = (Test-Path $localModDir) -and (Test-Path (Join-Path $localModDir 'mod.json'))
            if ($foundModJson -and $localModExists) {
                $doUpdateMod = $false; if ($isAuto) { $doUpdateMod = $true } else { $modReply = Read-Host "Update available. Overwrite local mod cache? [Y/N]"; Write-Host ''; if ($modReply -match '^[Yy]') { $doUpdateMod = $true } }
                if ($doUpdateMod) { if (Test-Path $localModDir) { Remove-Item $localModDir -Recurse -Force }; Copy-Item -Path $foundModJson.Directory.FullName -Destination $localModDir -Recurse -Force; Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host "Updated mod cache." -ForegroundColor White } else { Write-Host "[INFO] Keeping mod files." -ForegroundColor DarkYellow }
            } elseif ($foundModJson -and -not $localModExists) { if (Test-Path $localModDir) { Remove-Item $localModDir -Recurse -Force }; Copy-Item -Path $foundModJson.Directory.FullName -Destination $localModDir -Recurse -Force }
        }
    } catch { Write-Host "[ERROR] Download failed: $($_.Exception.Message)" -ForegroundColor Red }
    $ErrorActionPreference = 'SilentlyContinue'

    # (STEP 3: Mod)
    Write-Host "[3/4] " -ForegroundColor Cyan -NoNewline; Write-Host "Checking OMORI mod installation..." -ForegroundColor White
    $modDest = Join-Path $omoriPath 'www\mods\rumble'
    if (Test-Path (Join-Path $modDest 'mod.json')) { Write-Host "[OK] Mod already installed." -ForegroundColor Green; $modReady = $true }
    elseif ((Test-Path $localModDir) -and (Test-Path (Join-Path $localModDir 'mod.json'))) {
        $modsParentDir = Split-Path $modDest; if (-not (Test-Path $modsParentDir)) { New-Item -ItemType Directory -Path $modsParentDir -Force | Out-Null }
        Copy-Item -Path $localModDir -Destination $modDest -Recurse -Force; Write-Host "[OK] Installed mod." -ForegroundColor Green; $modReady = $true
    } else { Write-Host "[ERROR] Mod not found!" -ForegroundColor Red }
    Write-Host ''

    # (STEP 4: Start Bridge ONLY)
    Write-Host "[4/4] " -ForegroundColor Cyan -NoNewline; Write-Host "Starting Rumble Bridge..." -ForegroundColor White
    if (-not $bridgeReady) { if (Test-Path $bridgeExe) { $bridgeReady = $true } else { $versionedExe = Get-ChildItem -Path $currentDir -Filter "RumbleBridge*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1; if ($versionedExe) { Copy-Item $versionedExe.FullName -Destination $bridgeExe -Force; $bridgeReady = $true } } }

    if ($bridgeReady -and $modReady) {
        try {
            Write-DebugMsg "Executing: Start-Process -FilePath '$bridgeExe' -WindowStyle Hidden"
            Start-Process -FilePath $bridgeExe -WindowStyle Hidden
            Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host "Rumble Bridge started. Handing off to Steam..." -ForegroundColor White
        } catch { Write-Host "[ERROR] Failed to start bridge." -ForegroundColor Red; exit 1 }
    } else {
        Write-Host "[ERROR] Missing files." -ForegroundColor Red; exit 1
    }
    exit 0
}

else {
    # ==========================================
    # STANDALONE MODE (Double-clicked start.bat)
    # ==========================================
    Write-DebugMsg "Beginning Step 1: Locating OMORI installation..."
    Write-Host "[1/4] " -ForegroundColor Cyan -NoNewline; Write-Host "Locating OMORI installation..." -ForegroundColor White
    $omoriPath = $null; $steamPath = $null

    if ($overrideOmoriPath) {
        $testPath = Join-Path $overrideOmoriPath 'OMORI.exe'
        if (Test-Path $testPath) { $omoriPath = (Resolve-Path $overrideOmoriPath).Path } else { Write-Host "[ERROR] Could not locate OMORI." -ForegroundColor Red; if($isDebug){Read-Host}; exit 1 }
    } else {
        $steamRegPaths = @('HKLM:\SOFTWARE\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKCU:\SOFTWARE\Valve\Steam','HKCU:\SOFTWARE\WOW6432Node\Valve\Steam')
        foreach ($regPath in $steamRegPaths) { $p = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).InstallPath; if ($p) { $steamPath = $p; break } }
        if (-not $steamPath) { Write-Host "[ERROR] Steam is not installed." -ForegroundColor Red; if($isDebug){Read-Host}; exit 1 }
        $vdfPath = Join-Path $steamPath 'steamapps\libraryfolders.vdf'; $libraryPaths = @()
        if (Test-Path $vdfPath) { $vdfContent = Get-Content $vdfPath; foreach ($line in $vdfContent) { if ($line -match '^\s*"[^"]+"\s+"([A-Za-z]:\\[^"]+)"') { $extractedPath = $matches[1]; if ($extractedPath -notmatch 'steamapps\\common$') { $libraryPaths += Join-Path $extractedPath 'steamapps\common' } else { $libraryPaths += $extractedPath } } } }
        $defaultPath = Join-Path $steamPath 'steamapps\common'; if ($libraryPaths -notcontains $defaultPath) { $libraryPaths += $defaultPath }
        foreach ($libPath in $libraryPaths) { $testPath = Join-Path $libPath 'OMORI'; if (Test-Path (Join-Path $testPath 'OMORI.exe')) { $omoriPath = $testPath; break } }
        if (-not $omoriPath) { Write-Host "[ERROR] Could not locate OMORI." -ForegroundColor Red; if($isDebug){Read-Host}; exit 1 }
    }
    Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host "Found OMORI at: " -ForegroundColor White -NoNewline; Write-Host $omoriPath -ForegroundColor Gray; Write-Host ''

    Write-Host "[2/4] " -ForegroundColor Cyan -NoNewline; Write-Host "Checking for updates..." -ForegroundColor White
    $ErrorActionPreference = 'Continue'
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/releases/latest" -Headers @{'User-Agent'='RumbleBridgeUpdate'}
        $zipAssets = $release.assets | Where-Object { $_.name -like '*.zip' -and $_.name -notlike '*Source*' }
        if ($zipAssets) {
            Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host "Found updates..." -ForegroundColor White
            if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }; New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
            foreach ($zip in $zipAssets) { $zipPath = Join-Path $tempDir $zip.name; Invoke-WebRequest -Uri $zip.browser_download_url -OutFile $zipPath; Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force }
            $foundExe = Get-ChildItem -Path $extractDir -Filter "RumbleBridge*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            $foundDll = Get-ChildItem -Path $extractDir -Filter "ViGEmClient.dll" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($foundExe) { Copy-Item $foundExe.FullName -Destination $bridgeExe -Force }; if ($foundDll) { Copy-Item $foundDll.FullName -Destination $bridgeDll -Force }
            $foundModJson = Get-ChildItem -Path $extractDir -Filter "mod.json" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($foundModJson) { if (Test-Path $localModDir) { Remove-Item $localModDir -Recurse -Force }; Copy-Item -Path $foundModJson.Directory.FullName -Destination $localModDir -Recurse -Force }
        }
    } catch { Write-Host "[WARN] Update check failed." -ForegroundColor Yellow }
    $ErrorActionPreference = 'SilentlyContinue'

    Write-Host "[3/4] " -ForegroundColor Cyan -NoNewline; Write-Host "Checking OMORI mod..." -ForegroundColor White
    $modDest = Join-Path $omoriPath 'www\mods\rumble'
    if (-not (Test-Path (Join-Path $modDest 'mod.json')) -and (Test-Path $localModDir)) {
        $modsParentDir = Split-Path $modDest; if (-not (Test-Path $modsParentDir)) { New-Item -ItemType Directory -Path $modsParentDir -Force | Out-Null }
        Copy-Item -Path $localModDir -Destination $modDest -Recurse -Force
    }
    Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host "Mod ready." -ForegroundColor White; Write-Host ''

    Write-Host "[4/4] " -ForegroundColor Cyan -NoNewline; Write-Host "Launching..." -ForegroundColor White
    if (-not $bridgeReady) { if (Test-Path $bridgeExe) { $bridgeReady = $true } else { $versionedExe = Get-ChildItem -Path $currentDir -Filter "RumbleBridge*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1; if ($versionedExe) { Copy-Item $versionedExe.FullName -Destination $bridgeExe -Force; $bridgeReady = $true } } }
    
    if ($bridgeReady -and $modReady) {
        try {
            Start-Process -FilePath $bridgeExe -WindowStyle Hidden
            Write-Host '====================================================================' -ForegroundColor Cyan
            Write-Host ' Rumble Bridge is running. OMORI is launching...' -ForegroundColor Cyan
            Write-Host '====================================================================' -ForegroundColor Cyan
            
            if ($launchMethod -eq "direct") { Start-Process -FilePath (Join-Path $omoriPath 'OMORI.exe') -WorkingDirectory $omoriPath }
            else { Start-Process "steam://rungameid/$steamAppId" }

            Start-Sleep -Seconds 3 
            $lastLineCount = 0
            while ($true) {
                $bridgeRunning = [bool](Get-Process -Name "RumbleBridge" -ErrorAction SilentlyContinue)
                $omoriRunning = [bool](Get-Process -Name "OMORI*" -ErrorAction SilentlyContinue)
                if (-not $bridgeRunning -and -not $omoriRunning) { Write-Host ' OMORI and Rumble Bridge have closed.' -ForegroundColor Red; break }
                if (Test-Path $logFile) {
                    try {
                        $lines = Get-Content $logFile -ErrorAction Stop
                        if ($lines -and $lines.Count -gt $lastLineCount) {
                            $newLines = $lines[$lastLineCount..($lines.Count - 1)]
                            foreach ($line in $newLines) {
                                if ($line -match 'Intensity:\s*([0-9.]+)') { $intensity = [float]$matches[1]; if ($intensity -lt 0.35) { $color = "Green" } elseif ($intensity -le 0.70) { $color = "Yellow" } else { $color = "Red" }; Write-Host "  $line" -ForegroundColor $color }
                                elseif ($line -match '\[ERROR\]') { Write-Host "  $line" -ForegroundColor Red }
                                elseif ($line -match '\[HARDWARE\]') { Write-Host "  $line" -ForegroundColor Green }
                                elseif ($line -match '\[NETWORK\] Connected') { Write-Host "  $line" -ForegroundColor Green }
                                else { Write-Host "  $line" -ForegroundColor DarkGray }
                            }
                            $lastLineCount = $lines.Count
                        }
                    } catch {}
                }
                Start-Sleep -Milliseconds 100
            }
        }
        finally {
            $leftoverBridges = Get-Process -Name "RumbleBridge" -ErrorAction SilentlyContinue
            if ($leftoverBridges) { $leftoverBridges | Stop-Process -Force; Start-Sleep -Milliseconds 500 }
            try { Remove-Item $logFile -Force -ErrorAction Stop } catch { }
            if ($isDebug) { Read-Host "Press Enter to close..." }
        }
    }
}