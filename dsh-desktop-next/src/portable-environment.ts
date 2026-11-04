/**
 * One package, every byte it writes.
 *
 * A portable package carries its own Node, pnpm, Python and uv. Everything those tools
 * download — plugin tarballs, interpreter builds, pip wheels, npm packages — must land
 * beside the executable as well, so the package stays self-contained after it is copied
 * to another machine and so wiping `home/` is enough to hand it on.
 *
 * The paths are derived from the package location alone: no variable has to be set before
 * a launch, and a moved or renamed package keeps working because nothing is absolute in a
 * configuration file. Package managers and downloaders are pointed at the package through
 * the environment variables they already read, which keeps the redirection invisible to
 * plugins, terminals and the agents they run.
 */
import { existsSync, mkdirSync } from 'node:fs'
import { delimiter, join } from 'node:path'
import { PORTABLE_MARKER } from './data-directory.ts'

/** Directories a portable package owns, all below its root. */
export interface PortablePaths {
  /** Package root: the directory holding the executable and `portable.json`. */
  readonly root: string
  /** Mutable root; deleting it resets the package without touching the installation. */
  readonly home: string
  /** pnpm content-addressable store, seeded by the release with the offline plugin library. */
  readonly store: string
  /** pnpm metadata cache; offline resolution of ranged dependencies needs it. */
  readonly metadata: string
  /** State, cache and share roots that XDG-aware tools fall back to. */
  readonly state: string
  readonly cache: string
  readonly share: string
  /** Interpreters the release ships, when this package carries one. */
  readonly runtime?: string
}

export interface PortableEnvironmentOptions {
  readonly platform?: NodeJS.Platform
  readonly arch?: NodeJS.Architecture
  readonly exists?: (path: string) => boolean
  readonly create?: (path: string) => void
}

function createPrivate(path: string): void {
  try { mkdirSync(path, { recursive: true, mode: 0o700 }) } catch { /* A read-only package still launches; tools report their own failure. */ }
}

/** Resolve every directory of one portable package from the package root alone. */
export function portablePaths(program: string, options: PortableEnvironmentOptions = {}): PortablePaths {
  const { arch = process.arch, exists = existsSync } = options
  const home = join(program, 'home')
  const runtime = join(program, 'resources', 'runtime', arch, 'primary-runtime', 'dependencies')
  return {
    root: program,
    home,
    store: join(program, 'registry', 'store'),
    metadata: join(program, 'registry', 'cache'),
    state: join(home, 'state'),
    cache: join(home, 'cache'),
    share: join(home, 'share'),
    ...(exists(runtime) ? { runtime } : {}),
  }
}

/** Executable directories the package resolves from itself, nearest first. */
export function portablePathEntries(paths: PortablePaths, platform: NodeJS.Platform = process.platform): string[] {
  const entries: string[] = []
  if (paths.runtime !== undefined) {
    entries.push(platform === 'win32' ? join(paths.runtime, 'node') : join(paths.runtime, 'node', 'bin'))
    entries.push(platform === 'win32'
      ? join(paths.runtime, 'python')
      : join(paths.runtime, 'python', 'bin'))
    if (platform === 'win32') entries.push(join(paths.runtime, 'python', 'Scripts'))
  }
  entries.push(join(paths.home, 'bin'), join(paths.home, 'npm-global', 'bin'))
  return entries
}

/**
 * Point every downloader this process starts at the package.
 *
 * Only the directories a tool already reads are touched, so nothing in the package has to
 * be discovered by a wrapper script and no user configuration is involved. The variables
 * are inherited by the Host, plugins, the terminal and the processes an agent spawns.
 */
export function applyPortableEnvironment(
  environment: NodeJS.ProcessEnv,
  program: string,
  options: PortableEnvironmentOptions = {},
): PortablePaths {
  const platform = options.platform ?? process.platform
  const create = options.create ?? createPrivate
  const paths = portablePaths(program, options)
  const dirs = {
    cache: paths.cache,
    state: paths.state,
    share: paths.share,
    store: paths.store,
    metadata: paths.metadata,
    pnpmState: join(paths.state, 'pnpm'),
    npmCache: join(paths.cache, 'npm'),
    npmPrefix: join(paths.home, 'npm-global'),
    corepack: join(paths.cache, 'corepack'),
    pipCache: join(paths.cache, 'pip'),
    pythonUser: join(paths.share, 'python-user'),
    uvCache: join(paths.cache, 'uv'),
    uvPython: join(paths.share, 'python'),
    uvTools: join(paths.share, 'uv-tools'),
    bin: join(paths.home, 'bin'),
  }
  for (const dir of Object.values(dirs)) create(dir)
  environment.DSH_PORTABLE_ROOT = paths.root
  // XDG-aware tools (pip, uv, less, node itself) keep their caches and state in the package.
  environment.XDG_CACHE_HOME = dirs.cache
  environment.XDG_STATE_HOME = dirs.state
  environment.XDG_DATA_HOME = dirs.share
  // pnpm ignores NPM_CONFIG_* for these three settings; its own variables always apply.
  environment.pnpm_config_store_dir = dirs.store
  environment.pnpm_config_cache_dir = dirs.metadata
  environment.pnpm_config_state_dir = dirs.pnpmState
  // npm (when the terminal or an agent calls one) and corepack stay inside the package too.
  environment.npm_config_cache = dirs.npmCache
  environment.npm_config_prefix = dirs.npmPrefix
  environment.COREPACK_HOME = dirs.corepack
  // Python tooling: downloads and `--user` installs belong to the package, not to $HOME.
  environment.PIP_CACHE_DIR = dirs.pipCache
  environment.PYTHONUSERBASE = dirs.pythonUser
  environment.UV_CACHE_DIR = dirs.uvCache
  environment.UV_PYTHON_INSTALL_DIR = dirs.uvPython
  environment.UV_TOOL_DIR = dirs.uvTools
  environment.UV_TOOL_BIN_DIR = dirs.bin
  const exists = options.exists ?? existsSync
  const entries = portablePathEntries(paths, platform).filter(path => exists(path))
  if (entries.length > 0) {
    // A launcher may prepend the same directories already; keep one copy of each so a
    // relaunch inside the package does not grow PATH on every generation.
    const kept = (environment.PATH ?? '').split(delimiter).filter(entry => entry.length > 0 && !entries.includes(entry))
    environment.PATH = [...entries, ...kept].join(delimiter)
  }
  return paths
}

/** Apply the portable environment only when this executable sits in a portable package. */
export function applyPortableEnvironmentIfPortable(
  environment: NodeJS.ProcessEnv,
  program: string,
  options: PortableEnvironmentOptions = {},
): PortablePaths | undefined {
  if (!(options.exists ?? existsSync)(join(program, PORTABLE_MARKER))) return undefined
  return applyPortableEnvironment(environment, program, options)
}
