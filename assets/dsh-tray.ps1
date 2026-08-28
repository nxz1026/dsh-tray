# DSH Web system-tray launcher (standalone, download-and-run).
# Keeps the server running HEADLESS (no console window) and uses the tray
# icon as the control surface: start / stop / restart / open UI / show logs,
# plus a launch-at-login toggle.
#
# Usage: edit the CONFIG block below, then run:
#   powershell -File dsh-tray.ps1
# (or double-click it). To load the functions without showing the tray
# (used by tests), run from PowerShell:  $NoTray = $true; . .\dsh-tray.ps1
#
# NOTE: ASCII-only. PowerShell 5.1 reads .ps1 as the system codepage and
# non-ASCII breaks string parsing.

# $NoTray defaults to false; a caller that dot-sources the script may set it
# first to load the functions without launching the tray.
if (-not (Test-Path variable:NoTray)) { $NoTray = $false }

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ===== CONFIG (edit here) =====
$port = 3080
# Root of the DeepSeek Harness repo. The server is started from here, because
# `apps/cli/src/bin.ts` is a relative path and `tsx` must resolve from this
# repo's node_modules. Change this to your harness checkout.
$workDir = 'E:\2026Workplace\Code\deepseek-harness'
# Command to start the DSH Web server when it is not running. The first
# element is resolved via PATH (including .cmd/.ps1 via PATHEXT); the rest are
# its arguments. Examples (run from $workDir):
#   @('node', '--import', 'tsx/esm', 'apps/cli/src/bin.ts', 'web', '--port', $port)
#   @('pnpm', 'dsh', 'web', '--port', $port)
#   @('dsh', 'web', '--port', $port)              # if `dsh` is on PATH
$startCommand = @('node', '--import', 'tsx/esm', 'apps/cli/src/bin.ts', 'web', '--port', $port)
# Log files for the server output (used by "Show Logs").
$logOut = Join-Path $env:TEMP 'dsh-tray.out.log'
$logErr = Join-Path $env:TEMP 'dsh-tray.err.log'
# Start the server automatically on launch if it is not already running.
$autoStart = $true
# How often (ms) the tray re-checks the server port to refresh icon/menu state.
$pollIntervalMs = 3000
# Backend mode: 'local' runs the server on this machine; 'remote' launches it on a
# cloud host over SSH and opens a local tunnel so the Web UI is at 127.0.0.1:$port.
$mode = 'remote'
# --- remote mode config (only used when $mode = 'remote') ---
$sshHost = 'ubuntu@ec2-16-16-138-7.eu-north-1.compute.amazonaws.com'  # user@host
$sshKey  = Join-Path $env:USERPROFILE '.ssh\DSH.pem'                   # identity file
# Remote command that starts the server (must bind 127.0.0.1 so the tunnel reaches it).
$remoteStartCommand = 'dsh web --port ' + $port
# Also kill the server on the cloud host when stopping (otherwise it keeps running).
$stopRemoteServer = $true
# ============================

$wt = Get-Command wt.exe -ErrorAction SilentlyContinue

$runKeyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runValueName = 'DSH Tray'

# --- Script-scope runtime state ---
$script:trackedPid = 0          # root PID of the server THIS tray instance started
$script:lastRunning = $null     # last known running state (for transitions)
$script:suppressUntil = [datetime]::MinValue  # skip crash/exit balloons until here

function Get-PortOwnerPids {
    $c = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    @($c.OwningProcess | Where-Object { $_ -ne 0 } | Sort-Object -Unique)
}

function Get-DshRunning {
    (Get-PortOwnerPids).Count -gt 0
}

function Start-Dsh {
    if ($mode -eq 'remote') { Start-RemoteDsh; return }
    Start-LocalDsh
}

function Start-LocalDsh {
    $exe = Get-Command $startCommand[0] -CommandType Application -ErrorAction SilentlyContinue
    if (-not $exe) {
        [System.Windows.Forms.MessageBox]::Show(
            "Cannot find launcher '$($startCommand[0])' on PATH.`nEdit `$startCommand in dsh-tray.ps1.",
            'DSH Tray') | Out-Null
        return
    }
    $proc = Start-Process -FilePath $exe.Path -WindowStyle Hidden `
        -WorkingDirectory $workDir `
        -ArgumentList $startCommand[1..($startCommand.Count - 1)] `
        -RedirectStandardOutput $logOut -RedirectStandardError $logErr -PassThru
    if ($proc) { $script:trackedPid = $proc.Id }
}

function Start-RemoteDsh {
    $ssh = Get-Command ssh.exe -ErrorAction SilentlyContinue
    if (-not $ssh) {
        [System.Windows.Forms.MessageBox]::Show(
            "Cannot find ssh.exe on PATH.`nWindows 10+ ships OpenSSH; enable it or add it to PATH.",
            'DSH Tray') | Out-Null
        return
    }
    if (-not (Test-Path -LiteralPath $sshKey)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Cannot find SSH key at '$sshKey'.`nEdit `$sshKey in dsh-tray.ps1.",
            'DSH Tray') | Out-Null
        return
    }
    # Start the server on the cloud host in the background, then keep this ssh
    # process alive as the local tunnel (-f backgrounds after the remote command).
    $remoteCmd = "nohup $remoteStartCommand >/tmp/dsh-tray.out.log 2>&1 &"
    $args = @('-f', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ExitOnForwardFailure=yes',
              '-i', "$sshKey", '-L', ('{0}:127.0.0.1:{0}' -f $port), $sshHost, $remoteCmd)
    $proc = Start-Process -FilePath $ssh.Path -WindowStyle Hidden -ArgumentList $args -PassThru
    if ($proc) { $script:trackedPid = $proc.Id }
}

function Stop-ProcessTree([int]$processId) {
    # taskkill /T kills the whole tree; hidden window avoids a console flash.
    try {
        Start-Process -FilePath 'taskkill.exe' -WindowStyle Hidden -Wait `
            -ArgumentList @('/PID', "$processId", '/T', '/F')
    } catch { }
}

function Stop-Dsh {
    param([switch]$Quiet)
    if ($mode -eq 'remote') { Stop-RemoteDsh $Quiet; return }
    Stop-LocalDsh $Quiet
}

function Stop-LocalDsh {
    param([switch]$Quiet)

    # A user-initiated stop/restart must not trigger the crash balloon.
    $script:suppressUntil = (Get-Date).AddSeconds(15)

    # Prefer the exact tree this tray started; never blindly kill strangers.
    if ($script:trackedPid -and (Get-Process -Id $script:trackedPid -ErrorAction SilentlyContinue)) {
        Stop-ProcessTree $script:trackedPid
        $script:trackedPid = 0
        return
    }
    $script:trackedPid = 0

    $ownerPids = Get-PortOwnerPids
    if (-not $ownerPids.Count) { return }
    if ($Quiet) { return }   # exiting the tray leaves unknown servers untouched

    $names = ($ownerPids | ForEach-Object {
            $p = Get-Process -Id $_ -ErrorAction SilentlyContinue
            if ($p) { '{0} (PID {1})' -f $p.ProcessName, $p.Id } else { "PID $_" }
        }) -join ', '
    $answer = [System.Windows.Forms.MessageBox]::Show(
        "Port $port is held by $names, which was NOT started by DSH Tray.`n`nForce-stop it anyway?",
        'DSH Tray', 'YesNo', 'Warning')
    if ($answer -eq 'Yes') {
        foreach ($opid in $ownerPids) { Stop-ProcessTree $opid }
    }
}

function Stop-RemoteDsh {
    param([switch]$Quiet)

    # A user-initiated stop/restart must not trigger the crash balloon.
    $script:suppressUntil = (Get-Date).AddSeconds(15)

    # 1) Kill the local tunnel (the ssh.exe that owns local port $port).
    foreach ($p in Get-PortOwnerPids) {
        $proc = Get-Process -Id $p -ErrorAction SilentlyContinue
        if ($proc -and $proc.Name -eq 'ssh') { Stop-ProcessTree $p }
    }
    # 2) Optionally kill the server on the cloud host too.
    if ($stopRemoteServer) {
        $ssh = Get-Command ssh.exe -ErrorAction SilentlyContinue
        if ($ssh -and (Test-Path -LiteralPath $sshKey)) {
            $pattern = (($remoteStartCommand -split ' ')[0..1] -join ' ')
            $kargs = @('-o', 'StrictHostKeyChecking=accept-new', '-i', "$sshKey",
                       $sshHost, "pkill -f '$pattern'")
            try { Start-Process -FilePath $ssh.Path -WindowStyle Hidden -ArgumentList $kargs } catch { }
        }
    }
    $script:trackedPid = 0
}

function ShowLogs {
    if ($wt) {
        Start-Process -FilePath $wt.Path -ArgumentList @(
            'powershell', '-NoProfile', '-Command', "Get-Content -LiteralPath '$logOut' -Wait -Tail 50"
        )
    } else {
        Start-Process -FilePath 'powershell' -ArgumentList @(
            '-NoProfile', '-Command', "Get-Content -LiteralPath '$logOut' -Wait -Tail 50"
        )
    }
}

function Restart-Dsh {
    Stop-Dsh
    Start-Sleep -Seconds 2
    Start-Dsh
}

# --- Launch-at-login toggle (HKCU Run key, per-user, no admin needed) ---
function Get-LaunchCommand {
    # Prefer the VBS wrapper (zero console flash); fall back to hidden PowerShell.
    $vbs = Join-Path (Split-Path -Parent $PSScriptRoot) 'dsh-tray.vbs'
    if (Test-Path -LiteralPath $vbs) {
        return "wscript.exe `"$vbs`""
    }
    return "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
}

function Get-LaunchAtLogin {
    $item = Get-ItemProperty -LiteralPath $runKeyPath -Name $runValueName -ErrorAction SilentlyContinue
    return ($null -ne $item)
}

function Set-LaunchAtLogin {
    param([bool]$Enabled)
    if ($Enabled) {
        Set-ItemProperty -LiteralPath $runKeyPath -Name $runValueName -Value (Get-LaunchCommand)
    } else {
        Remove-ItemProperty -LiteralPath $runKeyPath -Name $runValueName -ErrorAction SilentlyContinue
    }
}

# --- Status icons (green = running, red = stopped) ---
function New-StateIcon {
    param([System.Drawing.Color]$Color)
    $bmp = New-Object System.Drawing.Bitmap 16, 16
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $brush = New-Object System.Drawing.SolidBrush($Color)
    $g.FillEllipse($brush, 2, 2, 12, 12)
    $g.DrawEllipse([System.Drawing.Pens]::DimGray, 2, 2, 12, 12)
    $g.Dispose()
    $brush.Dispose()
    $icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    $bmp.Dispose()
    return $icon
}

# --- Tray icon + context menu ---
if (-not $NoTray) {
    $iconRunning = New-StateIcon ([System.Drawing.Color]::ForestGreen)
    $iconStopped = New-StateIcon ([System.Drawing.Color]::Firebrick)

    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = $iconStopped
    $notify.Text = 'DSH Web'
    $notify.Visible = $true

    $menu = New-Object System.Windows.Forms.ContextMenuStrip

    $openUI = $menu.Items.Add('Open Web UI')
    $openUI.Add_Click({ Start-Process "http://127.0.0.1:$port" })

    $showLogs = $menu.Items.Add('Show Logs (Windows Terminal)')
    $showLogs.Add_Click({ ShowLogs })

    $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

    $start = $menu.Items.Add('Start Server')
    $start.Add_Click({
            Start-Dsh
            $msg = if ($mode -eq 'remote') {
                "Starting cloud server + tunnel for http://127.0.0.1:$port ..."
            } else {
                "Starting server on http://127.0.0.1:$port ..."
            }
            $notify.ShowBalloonTip(3000, 'DSH Web', $msg, 'Info')
        })

    $stop = $menu.Items.Add('Stop Server')
    $stop.Add_Click({
            Stop-Dsh
            $notify.ShowBalloonTip(3000, 'DSH Web', 'Stopping server...', 'Info')
        })

    $restart = $menu.Items.Add('Restart Server')
    $restart.Add_Click({
            Restart-Dsh
            $notify.ShowBalloonTip(3000, 'DSH Web', 'Restarting server...', 'Info')
        })

    $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

    $launchAtLogin = $menu.Items.Add('Launch at login')
    $launchAtLogin.CheckOnClick = $true
    $launchAtLogin.Checked = Get-LaunchAtLogin
    $launchAtLogin.Add_Click({
            Set-LaunchAtLogin $launchAtLogin.Checked
            if ($launchAtLogin.Checked) {
                $notify.ShowBalloonTip(3000, 'DSH Tray', 'DSH Tray will start at login.', 'Info')
            } else {
                $notify.ShowBalloonTip(3000, 'DSH Tray', 'DSH Tray will NOT start at login.', 'Info')
            }
        })

    $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

    $exit = $menu.Items.Add('Exit (stop server)')
    $exit.Add_Click({
            Stop-Dsh -Quiet
            $notify.Visible = $false
            [System.Windows.Forms.Application]::Exit()
        })

    function Update-MenuState {
        $running = Get-DshRunning

        if ($null -ne $script:lastRunning) {
            if ($script:lastRunning -and -not $running) {
                $script:trackedPid = 0
                if ((Get-Date) -gt $script:suppressUntil) {
                    $notify.ShowBalloonTip(5000, 'DSH Web',
                        "Server exited unexpectedly (port $port is free).", 'Warning')
                }
            } elseif (-not $script:lastRunning -and $running -and -not $script:trackedPid) {
                if ((Get-Date) -gt $script:suppressUntil) {
                    $notify.ShowBalloonTip(5000, 'DSH Web',
                        "Server detected running at http://127.0.0.1:$port", 'Info')
                }
            }
        }
        $script:lastRunning = $running

        $start.Enabled = -not $running
        $stop.Enabled = $running
        $restart.Enabled = $running
        $notify.Icon = if ($running) { $iconRunning } else { $iconStopped }
        $notify.Text = if ($running) { "DSH Web - running (:${port})" } else { "DSH Web - stopped (:${port})" }
    }
    $menu.Add_Opening({ Update-MenuState })

    $pollTimer = New-Object System.Windows.Forms.Timer
    $pollTimer.Interval = $pollIntervalMs
    $pollTimer.Add_Tick({ Update-MenuState })

    $notify.ContextMenuStrip = $menu
    $notify.Add_DoubleClick({ Start-Process "http://127.0.0.1:$port" })

    # Auto-start the server on launch when not already running (skipped under -NoTray).
    if ($autoStart -and -not (Get-DshRunning)) {
        Start-Dsh
    }
    Update-MenuState
    $pollTimer.Start()

    $notify.ShowBalloonTip(3000, 'DSH Web', "DSH Web tray ready at http://127.0.0.1:$port`nRight-click the icon to control it.", 'Info')

    $hiddenForm = New-Object System.Windows.Forms.Form
    $hiddenForm.WindowState = 'Minimized'
    $hiddenForm.ShowInTaskbar = $false
    $hiddenForm.Visible = $false
    [System.Windows.Forms.Application]::Run($hiddenForm)
}
