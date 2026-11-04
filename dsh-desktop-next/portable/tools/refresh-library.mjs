#!/usr/bin/env node
/**
 * Refresh the plugin library a portable package carries.
 *
 * The package ships an offline copy of its plugins: tarballs in `registry/`, a pnpm store and
 * the metadata cache that lets pnpm resolve them without a network. Those copies age. This
 * script re-resolves the same plugins against the registry, downloads the current releases and
 * rewrites `registry/plugins.json`, all inside the package that runs it.
 *
 * Only the package directory is touched: the store and cache are the ones the application
 * itself uses, so the refreshed library is what the interface installs from afterwards.
 * Run it with the package's own interpreter — no system Node is involved:
 *
 *   Linux:   resources/runtime/x64/primary-runtime/dependencies/node/bin/node tools/refresh-library.mjs
 *   Windows: resources\runtime\x64\primary-runtime\dependencies\node\bin\node.exe tools\refresh-library.mjs
 *
 * Options:
 *   --latest          take the newest release of every listed plugin
 *   dsh-ops@1.2.3     refresh these plugins instead of the shipped list
 */
import { spawnSync } from 'node:child_process'
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { basename, dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const program = resolve(here, '..')
const registryDir = join(program, 'registry')
const store = join(registryDir, 'store')
const cache = join(registryDir, 'cache')
const scratch = join(program, 'home', 'library-update')
const node = process.execPath
const pnpm = join(program, 'resources', 'app.asar.unpacked', 'node_modules', 'pnpm', 'bin', 'pnpm.mjs')

function fail(message) {
  process.stderr.write(`refresh-library: ${message}\n`)
  process.exit(1)
}

/** Package name of a spec: `@scope/name@1.2.3` and `name@1.2.3` both resolve. */
function packageName(spec) {
  const at = spec.lastIndexOf('@')
  return at > 0 ? spec.slice(0, at) : spec
}

/** The plugin list the package already ships, used when the caller passed none. */
function shippedSpecs() {
  const file = join(registryDir, 'plugins.json')
  if (!existsSync(file)) return []
  const document = JSON.parse(readFileSync(file, 'utf8'))
  return (document.plugins ?? []).map(item => `${item.name}@${item.version ?? 'latest'}`)
}

function pnpmAdd(specs) {
  rmSync(scratch, { recursive: true, force: true })
  mkdirSync(scratch, { recursive: true })
  writeFileSync(join(scratch, 'package.json'), JSON.stringify({ name: 'library-refresh', private: true }, undefined, 2))
  // The same two directories the application uses: the store grows in place and the metadata
  // cache records what a later offline install resolves.
  const result = spawnSync(node, [pnpm, 'add', '--config.minimumReleaseAge=0', ...specs], {
    cwd: scratch, stdio: 'inherit',
    env: { ...process.env, pnpm_config_store_dir: store, pnpm_config_cache_dir: cache },
  })
  if (result.status !== 0) fail(`pnpm could not resolve ${specs.join(', ')}`)
}

/** Version a plugin resolved to, read from the installed copy. */
function installedVersion(name) {
  const manifest = join(scratch, 'node_modules', ...name.split('/'), 'package.json')
  if (!existsSync(manifest)) return undefined
  return JSON.parse(readFileSync(manifest, 'utf8')).version
}

async function registryMetadata(name) {
  const base = (process.env.npm_config_registry ?? 'https://registry.npmjs.org').replace(/\/+$/u, '')
  const response = await fetch(`${base}/${name.replace('/', '%2f')}`)
  if (!response.ok) fail(`registry metadata for ${name} failed: ${response.status}`)
  return response.json()
}

/** Download one release beside the existing library tarballs. */
async function download(name, version) {
  const metadata = await registryMetadata(name)
  const release = metadata.versions?.[version]
  if (release === undefined) fail(`${name}@${version} is missing from the registry metadata`)
  const response = await fetch(release.dist.tarball)
  if (!response.ok) fail(`${name}@${version} tarball failed: ${response.status}`)
  const file = join(registryDir, `${name.replace('@', '').replace('/', '-')}-${version}.tgz`)
  writeFileSync(file, Buffer.from(await response.arrayBuffer()))
  return file
}

/** Remove every other tarball of the same plugin, so one release stays beside the store. */
function pruneOlder(name, keep) {
  const stem = `${name.replace('@', '').replace('/', '-')}-`
  for (const entry of readdirSync(registryDir)) {
    if (!entry.startsWith(stem) || !entry.endsWith('.tgz') || entry === basename(keep)) continue
    rmSync(join(registryDir, entry), { force: true })
    process.stdout.write(`removed ${entry}\n`)
  }
}

const argv = process.argv.slice(2)
const latest = argv.includes('--latest')
const explicit = argv.filter(argument => !argument.startsWith('-'))
const specs = explicit.length > 0 ? explicit : shippedSpecs()
if (specs.length === 0) fail('no plugins to refresh: pass package specs, or keep registry/plugins.json')
if (!existsSync(pnpm)) fail(`bundled pnpm is missing: ${pnpm}`)

process.stdout.write(`refreshing ${specs.length} plugin(s) into ${registryDir}\n`)
pnpmAdd(latest ? specs.map(spec => `${packageName(spec)}@latest`) : specs)

const plugins = []
for (const spec of specs) {
  const name = packageName(spec)
  const version = installedVersion(name)
  if (version === undefined) fail(`${name} did not install into the scratch profile`)
  const file = await download(name, version)
  pruneOlder(name, file)
  plugins.push({ name, version })
  process.stdout.write(`  ${name}@${version} → ${basename(file)}\n`)
}
writeFileSync(join(registryDir, 'plugins.json'), `${JSON.stringify({ plugins }, undefined, 2)}\n`)
rmSync(scratch, { recursive: true, force: true })
process.stdout.write(`plugin library refreshed: ${plugins.map(item => `${item.name}@${item.version}`).join(', ')}\n`)
