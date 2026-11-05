import { chmodSync, mkdirSync, mkdtempSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterEach, expect, it } from 'vitest'
import { restoreExecutableBits } from '../scripts/prepare-payload.ts'

const roots: string[] = []
function root() { const path = mkdtempSync(join(tmpdir(), 'next-exec-bit-')); roots.push(path); return path }
afterEach(() => roots.splice(0).forEach(path => rmSync(path, { recursive: true, force: true })))

/** A four-byte ELF header is enough for the content check; the bytes never execute. */
function elf(path: string): void { writeFileSync(path, Buffer.from([0x7f, 0x45, 0x4c, 0x46, 0x02, 0x01])) }
function mode(path: string): number { return statSync(path).mode & 0o777 }

it('restores the executable bit of a native image a package published without one', () => {
  // @dataiku/uv-linux-x64 declares no bin entry, so npm delivers bin/uv as 0644 and spawning
  // it fails with EACCES — the packaged release carried 0644 before this step existed.
  const packageDir = root(), bin = join(packageDir, 'bin')
  mkdirSync(bin, { recursive: true })
  elf(join(bin, 'uv'))
  chmodSync(join(bin, 'uv'), 0o644)
  restoreExecutableBits(packageDir, 'linux')
  expect(mode(join(bin, 'uv'))).toBe(0o755)
})

it('leaves scripts, data files and already runnable images as they are', () => {
  const packageDir = root(), bin = join(packageDir, 'bin')
  mkdirSync(bin, { recursive: true })
  writeFileSync(join(bin, 'shim'), '#!/bin/sh\nexit 0\n')
  chmodSync(join(bin, 'shim'), 0o644)
  writeFileSync(join(bin, 'notes.txt'), 'plain text')
  chmodSync(join(bin, 'notes.txt'), 0o644)
  elf(join(bin, 'ready'))
  chmodSync(join(bin, 'ready'), 0o750)
  restoreExecutableBits(packageDir, 'linux')
  expect(mode(join(bin, 'shim'))).toBe(0o644)
  expect(mode(join(bin, 'notes.txt'))).toBe(0o644)
  // An owner-executable image already runs; its tighter group/other bits stay untouched.
  expect(mode(join(bin, 'ready'))).toBe(0o750)
})

it('does nothing on Windows, where an image starts by extension, and outside a bin directory', () => {
  const packageDir = root(), bin = join(packageDir, 'bin'), lib = join(packageDir, 'lib')
  mkdirSync(bin, { recursive: true })
  mkdirSync(lib, { recursive: true })
  elf(join(bin, 'uv.exe'))
  chmodSync(join(bin, 'uv.exe'), 0o644)
  elf(join(lib, 'embedded'))
  chmodSync(join(lib, 'embedded'), 0o644)
  restoreExecutableBits(packageDir, 'win32')
  expect(mode(join(bin, 'uv.exe'))).toBe(0o644)
  restoreExecutableBits(packageDir, 'linux')
  expect(mode(join(lib, 'embedded'))).toBe(0o644)
})
