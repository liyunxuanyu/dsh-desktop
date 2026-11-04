# 校验从 Release 下载的压缩包是否完整（Windows 实现）。
param(
  [string]$Sums = '',
  [string]$Target = ''
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($Sums)) { $Sums = Join-Path $here 'SHA256SUMS.txt' }
if ([string]::IsNullOrEmpty($Target)) { $Target = Split-Path -Parent (Resolve-Path $Sums) }
if (-not (Test-Path $Sums)) {
  Write-Error "找不到校验和文件：$Sums（请从 Release 页面一并下载 SHA256SUMS.txt）"
  exit 1
}

$missing = 0; $failed = 0; $checked = 0
foreach ($line in Get-Content $Sums) {
  $trimmed = $line.Trim()
  if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
  $parts = $trimmed -split '\s+', 2
  if ($parts.Count -lt 2) { continue }
  $expected = $parts[0].ToLower(); $name = $parts[1]
  $file = Join-Path $Target $name
  if (-not (Test-Path $file)) { Write-Host "缺失  $name"; $missing++; continue }
  $checked++
  $actual = (Get-FileHash -Path $file -Algorithm SHA256).Hash.ToLower()
  if ($actual -eq $expected) { Write-Host "通过  $name" }
  else {
    Write-Host "不匹配 $name"; Write-Host "      期望 $expected"; Write-Host "      实际 $actual"; $failed++
  }
}
Write-Host ''
if ($checked -eq 0) { Write-Error "没有找到任何待校验文件（缺失 $missing 个）。"; exit 1 }
if ($failed -ne 0) { Write-Error "校验未通过：不匹配 $failed 个（已核对 $checked 个）。"; exit 1 }
if ($missing -ne 0) { Write-Host "已核对 $checked 个文件，全部通过；另有 $missing 个未下载，跳过。"; exit 0 }
Write-Host "全部校验通过（$checked 个文件）。"
exit 0
