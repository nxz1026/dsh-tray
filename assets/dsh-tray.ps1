# DSH Web system-tray launcher (standalone, download-and-run).
# Keeps the server running HEADLESS (no console window) and uses the tray
# icon as the control surface: start / stop / restart / open UI / show logs.
# "Show Logs" opens a Windows Terminal tab that tails the server log.
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
# Command to start the DSH Web server when it is not running. The first
# element is resolved via PATH (including .cmd/.ps1 via PATHEXT); the rest are
# its arguments. Examples:
#   @('dsh', 'web', '--port', $port)              # if `dsh` is on PATH
#   @('pnpm', 'dsh', 'web', '--port', $port)      # from a project with dsh
#   @('cmd', '/c', 'pnpm dsh web --port', $port)  # launched through cmd
$startCommand = @('dsh', 'web', '--port', $port)
# Log files for the server output (used by "Show Logs").
$logOut = Join-Path $env:TEMP 'dsh-tray.out.log'
$logErr = Join-Path $env:TEMP 'dsh-tray.err.log'
# Start the server automatically on launch if it is not already running.
$autoStart = $true
# ============================

$wt = Get-Command wt.exe -ErrorAction SilentlyContinue

function Get-DshRunning {
    $c = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    ($c.OwningProcess | Where-Object { $_ -ne 0 } | Measure-Object).Count -gt 0
}

function Start-Dsh {
    $exe = Get-Command $startCommand[0] -CommandType Application -ErrorAction SilentlyContinue
    if (-not $exe) {
        [System.Windows.Forms.MessageBox]::Show(
            "Cannot find launcher '$($startCommand[0])' on PATH.`nEdit `$startCommand in dsh-tray.ps1.",
            'DSH Tray') | Out-Null
        return
    }
    Start-Process -FilePath $exe.Path -WindowStyle Hidden `
        -ArgumentList $startCommand[1..($startCommand.Count - 1)] `
        -RedirectStandardOutput $logOut -RedirectStandardError $logErr
}

function Stop-Dsh {
    $c = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    $c.OwningProcess | Where-Object { $_ -ne 0 } | Sort-Object -Unique | ForEach-Object {
        Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
    }
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

# --- Tray icon + context menu ---
if (-not $NoTray) {
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Application
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
            $notify.ShowBalloonTip(3000, 'DSH Web', "Starting... browser opens at http://127.0.0.1:$port", 'Info')
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

    $exit = $menu.Items.Add('Exit (stop server)')
    $exit.Add_Click({
            Stop-Dsh
            $notify.Visible = $false
            [System.Windows.Forms.Application]::Exit()
        })

    function Update-MenuState {
        $running = Get-DshRunning
        $start.Enabled = -not $running
        $stop.Enabled = $running
        $restart.Enabled = $running
        $notify.Text = if ($running) { "DSH Web - running (:${port})" } else { "DSH Web - stopped (:${port})" }
    }
    $menu.Add_Opening({ Update-MenuState })

    $notify.ContextMenuStrip = $menu
    $notify.Add_DoubleClick({ Start-Process "http://127.0.0.1:$port" })

    # Auto-start the server on launch when not already running (skipped under -NoTray).
    if ($autoStart -and -not (Get-DshRunning)) {
        Start-Dsh
    }
    $notify.ShowBalloonTip(3000, 'DSH Web', "DSH Web tray ready at http://127.0.0.1:$port`nRight-click the icon to control it.", 'Info')

    $hiddenForm = New-Object System.Windows.Forms.Form
    $hiddenForm.WindowState = 'Minimized'
    $hiddenForm.ShowInTaskbar = $false
    $hiddenForm.Visible = $false
    [System.Windows.Forms.Application]::Run($hiddenForm)
}
