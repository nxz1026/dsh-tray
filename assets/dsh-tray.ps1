# DSH Web system-tray launcher (standalone plugin asset).
# Keeps the server running HEADLESS (no console window) and uses the tray
# icon as the control surface: start / stop / restart / open UI / show logs.
# "Show Logs" opens a Windows Terminal tab that tails the server log.
#
# NOTE: ASCII-only. PowerShell 5.1 reads .ps1 as the system codepage and
# non-ASCII breaks string parsing.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$port = 3080
$logOut = Join-Path $env:TEMP 'dsh-tray.out.log'
$logErr = Join-Path $env:TEMP 'dsh-tray.err.log'
$wt = Get-Command wt.exe -ErrorAction SilentlyContinue

function Get-DshRunning {
    $c = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    ($c.OwningProcess | Where-Object { $_ -ne 0 } | Measure-Object).Count -gt 0
}

function Start-Dsh {
    Start-Process -FilePath 'dsh' -WindowStyle Hidden -ArgumentList @('web', '--port', $port) `
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

# Auto-start the server on launch so double-clicking the shortcut just works.
Start-Dsh
$notify.ShowBalloonTip(3000, 'DSH Web', "Launching at http://127.0.0.1:$port`nRight-click the icon to control it.", 'Info')

$hiddenForm = New-Object System.Windows.Forms.Form
$hiddenForm.WindowState = 'Minimized'
$hiddenForm.ShowInTaskbar = $false
$hiddenForm.Visible = $false
[System.Windows.Forms.Application]::Run($hiddenForm)
