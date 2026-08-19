# DSH Tray

A Windows system-tray launcher for DeepSeek Harness Web. No install step:
download (or clone) the repo, edit a small config block, and run the script.
The tray icon controls the running server — start / stop / restart / open the
Web UI / tail logs.

## Quick start

1. Download or clone this repo.
2. (Optional) edit the `CONFIG` block at the top of `assets/dsh-tray.ps1`:
   - `$port` — server port (default `3080`).
   - `$startCommand` — the command that launches `dsh web` (must be on `PATH`).
   - `$autoStart` — start the server on launch if it is not already running.
3. Run it:
   ```sh
   powershell -File assets/dsh-tray.ps1
   ```
   or just double-click `dsh-tray.vbs` (runs hidden, no console window) or
   `dsh-tray.bat` at the repo root. The DSH Web server starts headless and the
   tray icon appears. Right-click it to control the server.

Requirements: Windows, and the `dsh` CLI on `PATH` (the tray calls `dsh web`).
If `dsh` is not on `PATH`, edit `$startCommand` in `assets/dsh-tray.ps1` to the
command that starts your server (see the examples in the CONFIG block).

## Menu

- **Open Web UI** — open http://127.0.0.1:3080 in the default browser.
- **Show Logs (Windows Terminal)** — tail the server log in a Windows Terminal tab.
- **Start / Stop / Restart Server** — mutually exclusive with the running state.
- **Exit (stop server)** — stop the server and remove the tray icon.

## How it works

The script creates a `System.Windows.Forms` notify icon, polls the server port
to keep the menu state accurate, and drives `dsh web` for start/stop/restart.
"Show Logs" opens a Windows Terminal tab that tails the server log.

## Plugin-ready (future)

This repo also carries Cordis plugin scaffolding — `package.json` with a
`dsh.bundle` manifest, `cordis.patch.yml`, and `src/plugin.js` — so it can
later be installed as a `dsh` plugin. That is not the current usage: for now
you just run the script directly.

## Limitations

- Windows only.
- Assumes the default port 3080 and the default web profile.
- "Restart" stops the server on the port; bring it back up yourself.
- Independent tool, not an official DeepSeek product.

---

# DSH Tray（中文）

DeepSeek Harness Web 的 Windows 系统托盘启动器。无需安装:下载(或克隆)本仓库,
改一小段配置,直接运行脚本即可。托盘图标用于控制正在运行的服务:启动 / 停止 /
重启 / 打开 Web UI / 查看日志。

## 快速开始

1. 下载或克隆本仓库。
2. (可选)编辑 `assets/dsh-tray.ps1` 顶部的 `CONFIG` 配置区:
   - `$port` — 服务端口(默认 `3080`)。
   - `$startCommand` — 启动 `dsh web` 的命令(需在 `PATH` 中)。
   - `$autoStart` — 若服务未运行,启动时自动拉起。
3. 运行:
   ```sh
   powershell -File assets/dsh-tray.ps1
   ```
   或直接双击仓库根目录的 `dsh-tray.vbs`(隐藏运行,无黑框),也可双击 `dsh-tray.bat`。
   DSH Web 服务以无窗口方式启动,托盘图标随即出现。右键图标即可控制服务。

环境要求:Windows,且 `dsh` CLI 在 `PATH` 中(托盘会调用 `dsh web`)。
若 `dsh` 不在 `PATH`,编辑 `assets/dsh-tray.ps1` 里的 `$startCommand` 改成你启动服务的命令
(配置区内有示例)。

## 菜单

- **打开 Web UI** — 在默认浏览器中打开 http://127.0.0.1:3080。
- **查看日志 (Windows Terminal)** — 在 Windows Terminal 标签页中实时追踪服务日志。
- **启动 / 停止 / 重启服务** — 与运行状态互斥。
- **退出(停止服务)** — 停止服务并移除托盘图标。

## 工作原理

脚本创建 `System.Windows.Forms` 通知图标,轮询服务端口以保持菜单状态准确,
并通过 `dsh web` 实现启动 / 停止 / 重启。"查看日志"会打开一个 Windows Terminal
标签页实时追踪服务日志。

## 插件化(未来)

本仓库同时保留了 Cordis 插件骨架 —— 含 `dsh.bundle` manifest 的 `package.json`、
`cordis.patch.yml` 与 `src/plugin.js` —— 以便将来可作为 `dsh` 插件安装。但那不是
当前用法:现在你只需直接运行脚本。

## 限制

- 仅支持 Windows。
- 使用默认端口 3080 与默认 web profile。
- "重启"会停止端口上的服务,需自行重新拉起。
- 独立工具,非 DeepSeek 官方产品。
