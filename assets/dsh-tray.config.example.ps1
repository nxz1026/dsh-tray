# DSH Tray user config -- COPY THIS FILE to dsh-tray.config.ps1 (same folder)
# and edit the values. dsh-tray.config.ps1 is git-ignored, so your host and
# key paths stay on your machine only. Any value you set here overrides the
# built-in defaults in assets/dsh-tray.ps1.

# Server port (the Web UI is always at http://127.0.0.1:$port, local or tunneled).
$port = 3080

# Root of the DeepSeek Harness repo (local mode only). The server is started
# from here so apps/cli/src/bin.ts and tsx resolve correctly.
$workDir = 'E:\2026Workplace\Code\deepseek-harness'

# Command that starts the server locally (local mode only). The first element
# is resolved via PATH; the rest are its arguments. Examples:
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

# Backend mode: 'local' runs the server on this machine; 'remote' launches it on
# a cloud host over SSH and opens a local tunnel to 127.0.0.1:$port.
$mode = 'local'

# --- remote mode config (only used when $mode = 'remote') ---
$sshHost = 'ubuntu@your-cloud-host.example.com'   # user@host
$sshKey  = Join-Path $env:USERPROFILE '.ssh\DSH.pem'  # identity file
# Remote command that starts the server (must bind 127.0.0.1 so the tunnel reaches it).
$remoteStartCommand = 'dsh web --port ' + $port
# Also kill the server on the cloud host when stopping (otherwise it keeps running).
$stopRemoteServer = $true
