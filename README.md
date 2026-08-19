# DSH Tray

Windows system-tray launcher for DeepSeek Harness Web. Once the plugin loads, a
tray icon appears and the DSH Web server starts headless in the background. The
tray menu controls the server without any console window:

- **Open Web UI** — open http://127.0.0.1:3080 in the default browser.
- **Show Logs (Windows Terminal)** — tail the server log in a Windows Terminal tab.
- **Start / Stop / Restart Server** — mutually exclusive with the running state
  (only the valid action for the current state is enabled).
- **Exit (stop server)** — stop the server and remove the tray icon.

## Install

Requires the `dsh` CLI on `PATH` and Windows.

```sh
dsh plugin --profile web add github:YOUR_GITHUB_USERNAME/dsh-tray
```

Then restart the DSH Web profile. The plugin launches the systray host process
on load.

Uninstall:

```sh
dsh plugin --profile web remove dsh-tray
```

## How it works

The Cordis plugin (`src/plugin.js`) spawns the bundled PowerShell script
(`assets/dsh-tray.ps1`) on Windows when the profile loads. The script creates
the `System.Windows.Forms` notify icon, polls the server port to keep the menu
state accurate, and drives `dsh web` for start/stop/restart.

## Limitations

- Windows only (`os: ["win32"]`).
- Assumes the default port 3080 and the default web profile.
- Independent tool, not an official DeepSeek product.
