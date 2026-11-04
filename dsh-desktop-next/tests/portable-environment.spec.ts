import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterEach, expect, it } from 'vitest'
import { NextProfiles } from '../src/profiles.ts'
import { applyPortableEnvironment, applyPortableEnvironmentIfPortable, portablePathEntries, portablePaths } from '../src/portable-environment.ts'

const roots: string[] = []
function root() { const path = mkdtempSync(join(tmpdir(), 'next-portable-')); roots.push(path); return path }
afterEach(() => roots.splice(0).forEach(path => rmSync(path, { recursive: true, force: true })))

function packageWithRuntime(): string {
  const program = root()
  const runtime = join(program, 'resources', 'runtime', 'x64', 'primary-runtime', 'dependencies')
  mkdirSync(join(runtime, 'node', 'bin'), { recursive: true })
  mkdirSync(join(runtime, 'python', 'bin'), { recursive: true })
  writeFileSync(join(program, 'portable.json'), '{}')
  return program
}

it('keeps every downloader, store and cache of a portable package inside the package', () => {
  const program = packageWithRuntime()
  const environment: NodeJS.ProcessEnv = { PATH: '/usr/bin' }
  const paths = applyPortableEnvironment(environment, program, { platform: process.platform === 'win32' ? 'win32' : 'linux' })

  expect(environment.DSH_PORTABLE_ROOT).toBe(program)
  expect(environment.XDG_CACHE_HOME).toBe(paths.cache)
  expect(environment.XDG_STATE_HOME).toBe(paths.state)
  expect(environment.XDG_DATA_HOME).toBe(paths.share)
  expect(environment.pnpm_config_store_dir).toBe(join(program, 'registry', 'store'))
  expect(environment.pnpm_config_cache_dir).toBe(join(program, 'registry', 'cache'))
  expect(environment.npm_config_cache).toBe(join(paths.cache, 'npm'))
  expect(environment.PIP_CACHE_DIR).toBe(join(paths.cache, 'pip'))
  expect(environment.UV_CACHE_DIR).toBe(join(paths.cache, 'uv'))
  expect(environment.UV_PYTHON_INSTALL_DIR).toBe(join(paths.share, 'python'))
  // Everything derived from the package root; nothing points at the user's home.
  for (const value of Object.values(environment)) {
    if (typeof value === 'string' && value !== '/usr/bin') expect(value.startsWith(program)).toBe(true)
  }
})

it('puts the bundled interpreters first on PATH without duplicating them across relaunches', () => {
  const program = packageWithRuntime()
  const environment: NodeJS.ProcessEnv = { PATH: '/usr/bin' }
  const paths = applyPortableEnvironment(environment, program, { platform: 'linux' })
  const entries = portablePathEntries(paths, 'linux')
  expect(entries[0]).toBe(join(paths.runtime!, 'node', 'bin'))
  // Directories the package does not carry stay out of PATH.
  expect(environment.PATH).toBe(`${entries.filter(entry => existsSync(entry)).join(':')}:/usr/bin`)

  // A launcher already exported the same directories; the second application keeps one copy.
  applyPortableEnvironment(environment, program, { platform: 'linux' })
  const seen = environment.PATH!.split(':')
  expect(seen).toEqual([...new Set(seen)])
  expect(seen.filter(entry => entry === entries[0])).toHaveLength(1)
})

it('applies nothing outside a portable package', () => {
  const program = root()
  const environment: NodeJS.ProcessEnv = { PATH: '/usr/bin' }
  expect(applyPortableEnvironmentIfPortable(environment, program)).toBeUndefined()
  expect(environment).toEqual({ PATH: '/usr/bin' })
})

it('gives every profile a package-local pnpm configuration before the first install', () => {
  const program = packageWithRuntime()
  const home = join(program, 'home', 'data')
  mkdirSync(home, { recursive: true })
  const profiles = new NextProfiles(home)
  const dir = profiles.ensure('desktop')
  const workspace = readFileSync(join(dir, 'pnpm-workspace.yaml'), 'utf8')
  expect(workspace).toContain('storeDir: ../../../../registry/store')
  expect(workspace).toContain('cacheDir: ../../../../registry/cache')
  // Relative paths keep pointing into the package after it is unzipped somewhere else.
  expect(join(dir, '../../../../registry/store')).toBe(join(program, 'registry', 'store'))
})

it('leaves the pnpm configuration of a normal installation alone', () => {
  const home = root()
  const dir = new NextProfiles(home).ensure('desktop')
  expect(readFileSync(join(home, 'profiles', 'desktop', 'package.json'), 'utf8')).toContain('bundles')
  const workspace = readFileSync(join(dir, 'pnpm-workspace.yaml'), 'utf8')
  expect(workspace).toContain('nodeLinker: hoisted')
  expect(workspace).not.toContain('storeDir')
})
