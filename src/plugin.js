import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

export const name = 'dsh-tray'

export function apply(ctx) {
  if (process.platform !== 'win32') return
  const here = dirname(fileURLToPath(import.meta.url))
  const tray = join(here, '..', 'assets', 'dsh-tray.ps1')
  const child = spawn(
    'powershell.exe',
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', tray],
    { windowsHide: true, stdio: 'ignore' },
  )
  child.unref()
  ctx.on('dispose', () => {
    try {
      child.kill()
    } catch {
      // already gone
    }
  })
}
