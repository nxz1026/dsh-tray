[![Awesome DSH Plugin](https://awesome-dsh-plugin.com/badge.svg)](https://awesome-dsh-plugin.com)
# DSH Tray

A Windows system-tray launcher for DeepSeek Harness Web. No install step:
download (or clone) the repo, edit a small config block, and run the script.
The tray icon controls the running server — start / stop / restart / open the
Web UI / tail logs.

## Quick start

1. Download or clone this repo.
2. (Optional) copy `assets/dsh-tray.config.example.ps1` to
   `assets/dsh-tray.config.ps1` and edit it. The config file is git-ignored,
   so your host/key paths stay local; built-in defaults apply if you skip this.
   - `$port` — server port (default `3080`).
   - `$startCommand` — the command that launches `dsh web` (must be on `PATH`).
   - `$autoStart` — start the server on launch if it is not already running.
   - `$pollIntervalMs` — how often the tray re-checks the port (default `3000`).
3. Run it:
   ```sh
   powershell -File assets\dsh-tray.ps1
   ```
   or double-click `dsh-tray.vbs` at the repo root — it launches the script
   through `wscript.exe`, so **no console window appears at all**. The DSH Web
   server starts headless and the tray icon appears. Right-click it to control
   the server. (`dsh-tray.bat` is kept as a fallback and also routes through the
   VBS file.)

Configuration: all values live in `assets/dsh-tray.config.ps1` (copy from the
example). Defaults in `assets/dsh-tray.ps1` are used for any value you omit:
- `$workDir` — your DeepSeek Harness repo root. The server is started from
  here so `apps/cli/src/bin.ts` and `tsx` resolve correctly.
- `$startCommand` — the command that starts the server (default launches the
  harness via `node --import tsx/esm apps/cli/src/bin.ts web`).
   - `$port`, `$autoStart`, `$pollIntervalMs`.
   - `$mode` — `local` (default) runs the server on this machine, or `remote`
     to launch it on a cloud host over SSH and tunnel it to `127.0.0.1:$port`.
   - `$sshHost`, `$sshKey`, `$remoteStartCommand`, `$stopRemoteServer` — only
     used in `remote` mode.

Requirements: Windows, and `node` on `PATH`.

## Menu

- **Open Web UI** — open http://127.0.0.1:3080 in the default browser.
- **Show Logs (Windows Terminal)** — tail the server log in a Windows Terminal tab.
- **Start / Stop / Restart Server** — mutually exclusive with the running state.
- **Launch at login** — checkbox; registers/removes a per-user Run-key entry.
- **Exit (stop server)** — stop the server and remove the tray icon.

The tray icon is green while the server runs and red when stopped.

## How it works

The script creates a `System.Windows.Forms` notify icon and polls the server
port on a timer to keep the icon color, tooltip, and menu state accurate. If
the server exits unexpectedly you get a balloon warning; if it starts running
on its own (e.g. launched from another terminal) the tray picks that up too.
Stop/Restart target only the process tree this tray started — if some other
program holds the port, the tray asks before touching it. "Show Logs" opens a
Windows Terminal tab that tails the server log.

### Remote mode (cloud host over SSH)

Set `$mode = 'remote'` and fill in `$sshHost`, `$sshKey`, `$remoteStartCommand`.
The launcher prepends `/usr/local/bin:/usr/bin:/bin` to the remote PATH so `dsh`
(often at `/usr/local/bin/dsh`) is found even in a non-login SSH session that
starts with an empty PATH. If your `dsh` lives elsewhere, set
`$remoteStartCommand` to its absolute path. Server logs are written on the cloud
host and shown by "Show Logs" (it tails `/tmp/dsh-tray.out.log` over SSH).
"Start" launches the server on the cloud host over SSH, then opens a separate
persistent local tunnel (`ssh -f -N -L $port:127.0.0.1:$port <host>`), so the Web
UI is reachable at `http://127.0.0.1:$port` exactly like local mode. The tunnel is
just a pipe: the tray only reports "ready" (green icon) and auto-opens the Web UI
in your default browser once the cloud server is **actually serving HTTP** — not
merely when the tunnel is up — so the browser never opens against a still-warming
server and spin. In local mode `dsh web` opens the browser itself, so the tray does
not auto-open there. The tray's status icon and Open Web UI keep working because the
tunnel terminates on the local port. "Show Logs" follows the cloud log live
(`tail -f /tmp/dsh-tray.out.log` over SSH). "Stop" kills the tunnel and, when
`$stopRemoteServer` is `$true`, also `ssh`es in to `pkill` the server. Windows 10+
ships OpenSSH (`ssh.exe`) — no extra install needed.

## Install as a dsh plugin

The repo declares a `dsh.bundle` manifest, so it can also be installed directly
into a dsh profile (Windows):

```sh
dsh plugin --profile web add https://github.com/nxz1026/dsh-tray
```

This registers the tray launcher as a profile bundle; the tray script itself is
still started from the Start-menu shortcut, the `.vbs` file, or manually.

## Plugin-ready

This repo carries Cordis plugin scaffolding — `package.json` with a
`dsh.bundle` manifest, `cordis.patch.yml`, and `src/plugin.js`. CI validates the
manifest and PowerShell syntax on every push.

## Limitations

- Windows only.
- Assumes the default port 3080 and the default web profile.
- "Launch at login" stores absolute paths; re-toggle it after moving the repo.
- Independent tool, not an official DeepSeek product.

---

# DSH Tray（中文）

DeepSeek Harness Web 的 Windows 系统托盘启动器。无需安装:下载(或克隆)本仓库,
改一小段配置,直接运行脚本即可。托盘图标用于控制正在运行的服务:启动 / 停止 /
重启 / 打开 Web UI / 查看日志。

## 快速开始

1. 下载或克隆本仓库。
2. (可选)将 `assets/dsh-tray.config.example.ps1` 复制为
   `assets/dsh-tray.config.ps1` 并编辑。该配置文件已被 git 忽略,
   你的 host/key 路径不会进版本库;若跳过,则使用脚本内置默认值。
   - `$port` — 服务端口(默认 `3080`)。
   - `$startCommand` — 启动 `dsh web` 的命令(需在 `PATH` 中)。
   - `$autoStart` — 若服务未运行,启动时自动拉起。
   - `$pollIntervalMs` — 托盘轮询服务端口的间隔(默认 `3000`)。
3. 运行:
   ```sh
   powershell -File assets\dsh-tray.ps1
   ```
   或直接双击仓库根目录的 `dsh-tray.vbs`(通过 `wscript.exe` 拉起脚本,**完全不会
   出现任何命令行窗口**)。DSH Web 服务以无窗口方式启动,托盘图标随即出现。
   右键图标即可控制服务。(`dsh-tray.bat` 保留作后备,同样会路由到 VBS 文件。)

配置:所有配置项都在 `assets/dsh-tray.config.ps1`(从示例文件复制而来)。
未在文件中写出的项会使用 `assets/dsh-tray.ps1` 中的默认值:
- `$workDir` — 你的 DeepSeek Harness 仓库根目录。服务从这里启动,
  这样 `apps/cli/src/bin.ts` 与 `tsx` 才能正确解析。
- `$startCommand` — 启动服务的命令(默认用
  `node --import tsx/esm apps/cli/src/bin.ts web` 拉起 harness)。
- `$port`、`$autoStart`、`$pollIntervalMs`。
- `$mode` — `local`（默认）在本机启动服务；设为 `remote` 则通过 SSH 在云端主机
  启动服务并把端口隧道到 `127.0.0.1:$port`。
- `$sshHost`、`$sshKey`、`$remoteStartCommand`、`$stopRemoteServer` — 仅 remote 模式使用。

环境要求:Windows,且 `node` 在 `PATH` 中。

## 菜单

- **打开 Web UI** — 在默认浏览器中打开 http://127.0.0.1:3080。
- **查看日志 (Windows Terminal)** — 在 Windows Terminal 标签页中实时追踪服务日志。
- **启动 / 停止 / 重启服务** — 与运行状态互斥。
- **开机自启 (Launch at login)** — 复选项;读写当前用户的 Run 注册表项,无需管理员权限。
- **退出(停止服务)** — 停止服务并移除托盘图标。

服务运行时托盘图标为绿色,停止时为红色。

## 工作原理

脚本创建 `System.Windows.Forms` 通知图标,并通过定时器轮询服务端口,实时刷新
图标颜色、悬浮提示与菜单状态。服务意外退出时会弹出气泡警告;若服务在托盘之外
被自行拉起(例如从别的终端启动),托盘也能感知到。停止/重启只作用于本托盘启动
的进程树——若端口被其他程序占用,托盘会先询问再处理。"查看日志"会打开一个
Windows Terminal 标签页实时追踪服务日志。

### 远程模式（云端主机 + SSH）

将 `$mode` 设为 `remote` 并填好 `$sshHost`、`$sshKey`、`$remoteStartCommand`。
启动器会在远程 PATH 前补上 `/usr/local/bin:/usr/bin:/bin`，这样即便非登录的
SSH 会话 PATH 为空也能找到 `dsh`（通常在 `/usr/local/bin/dsh`）。若你的 `dsh`
在其他位置，请把 `$remoteStartCommand` 写成绝对路径。服务日志写在云端主机上，
由「查看日志」通过 SSH 拉取 `/tmp/dsh-tray.out.log` 显示。
点「启动」会先在云端主机用 SSH 拉起服务，再单独开一条常驻本地隧道
（`ssh -f -N -L $port:127.0.0.1:$port <host>`），于是 Web UI 通过
`http://127.0.0.1:$port` 访问，与本地模式完全一致。隧道只是个管道：托盘只在云端
服务**真正在提供 HTTP 服务**时才判定「就绪」（图标变绿）并自动在本地默认浏览器打开
Web UI——而不是隧道一建好就开，避免浏览器连上还在预热的服务一直转圈。本地模式由
`dsh web` 自己打开浏览器，故托盘不在本地自动打开。托盘的状态图标、「打开 Web UI」
全部照常生效（隧道终结在本地端口）。「查看日志」会实时跟踪云端日志
（`tail -f /tmp/dsh-tray.out.log`）。点「停止」会杀掉隧道，
若 `$stopRemoteServer` 为 `$true`，还会 `ssh` 进去 `pkill` 掉云端服务。Windows 10+
自带 OpenSSH（`ssh.exe`），无需额外安装。

## 插件化(未来)

本仓库同时保留了 Cordis 插件骨架 —— 含 `dsh.bundle` manifest 的 `package.json`、
`cordis.patch.yml` 与 `src/plugin.js` —— 以便将来可作为 `dsh` 插件安装。但那不是
当前用法:现在你只需直接运行脚本。

## 限制

- 仅支持 Windows。
- 使用默认端口 3080 与默认 web profile。
- "开机自启"记录的是绝对路径;移动仓库位置后需重新勾选一次。
- 独立工具,非 DeepSeek 官方产品。
