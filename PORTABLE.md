# 桌面版便捷包（DSH NEXT）：自包含 + 可清空 + 随便带走

目标：桌面版（Electron 壳，不是浏览器 Web 版）打成「解压就能用」的包，**所有**可变状态都在包内，
带走前把用户数据一清，插件与运行时依旧齐全，换台机器功能不减。

## 产物

`DSH-NEXT-2.0.21-next-linux-x64-portable.tar.gz`（398 MB，解压 1.3 GB）

```
linux-unpacked/
├── dsh-desktop-next                 Electron 主程序（44.7.0 / Node 24.21.0）
├── portable.json                    便携标记：程序据此把全部状态放进 ./home
├── DSH-NEXT.sh                      启动器（Linux）
├── DSH-NEXT-reset.sh                清空用户数据（保留程序/运行时/插件）
├── DSH-NEXT.cmd / -reset.cmd        Windows 版同款脚本
├── .npmrc                           pnpm 指向包内 store
├── home/                            空的用户数据根（首次启动自动写入）
├── registry/
│   ├── store/                       离线 pnpm store（dsh-ops、modsearch 及依赖）
│   └── *.tgz                        同样的包，可直接 pnpm add
└── resources/
    ├── app.asar (+ .unpacked)       应用与依赖；预装插件在此
    └── runtime/x64/primary-runtime  Node 24.21.0 + pnpm 11.28.5 + Python 3.12.14
```

## 三条自包含链路

1. **数据目录**：`data-directory.ts` 新增 `PORTABLE_MARKER`/`portableRoot` 等，`main.ts` 里
   一旦检出可执行文件旁的 `portable.json`，数据目录取 `<包>/home/data`、位置记录取
   `<包>/home/.location`。Electron 的 userData 本来就被放在 `<数据目录>/electron-user-data`，
   于是会话、凭据、Chromium 存储、Crashpad、日志全部落在包内。
   实测启动后生成：`home/data/electron-user-data/`、`home/data/logs/`。
2. **预装插件**：`profiles.ts` 新增 `PREINSTALLED_BUNDLES = ['dsh-ops', '@liustack/modsearch']`
   并拼进 `WEB_BUNDLES`（新建 Profile 的唯一入口），两个包同时进了 `dependencies`，
   并在 `build.asarUnpack` 里解包——`dsh-ops` 的 Rust worker 是可执行文件，留在 asar 里无法 spawn。
   打包后的 Host 自检（`packaged-host-smoke`）因此会真实加载这两个 bundle，失败会直接中断打包。
3. **离线仓库**：`registry/store` 用包内 pnpm 11.28.5 预先 `store add` 了插件及依赖，
   启动器把 `NPM_CONFIG_STORE_DIR` / `NPM_CONFIG_CACHE` / `NPM_CONFIG_USERCONFIG` 指进包内，
   界面里装插件默认 `prefer-offline`，不走网络。

## 清空带走

```sh
./DSH-NEXT-reset.sh --yes     # 删除 home/（会话、凭据、插件配置、缓存），保留程序与运行时
```

清完即可压缩带走；换机器解压、`./DSH-NEXT.sh` 启动，插件与运行时原样可用。

## 本机构建的三处绕行（环境限制，非仓库问题）

1. 无系统编译器 → micromamba 装 `gcc/make` 到 `/root/mamba` 并前置 `PATH`（`fs-ext` 的 node-gyp 需要）。
2. `.yarnrc.yml` 的 `enableScripts: false` 让 Electron 的 postinstall 不执行 →
   手动 `node dsh-desktop-next/node_modules/electron/install.js`。
3. 子模块默认停在 Beta 提交 → 按 `upstream.json` 的 `channels.next.commit` 重新 checkout，
   否则 `prepare-runtime` 找不到 `lock.json`。

另外 `package:dir` 的自检会跑打包后的 Host：容器缺 GTK 时 GUI 检查必失败，
本次通过是因为 Host 自检以 Node 模式运行；GUI 本身在本机无法验证（无 X、`/dev/shm` 受限、root 沙箱）。

## 复现

```sh
git clone --depth 1 https://github.com/anywhere-labs/dsh-desktop.git && cd dsh-desktop
git submodule update --init deepseek-harness
commit=$(node -p "require('./upstream.json').channels.next.commit")
git -C deepseek-harness fetch --depth 1 origin "$commit" && git -C deepseek-harness checkout "$commit"
corepack enable && corepack yarn install --immutable
node dsh-desktop-next/node_modules/electron/install.js
corepack yarn workspace dsh-community-market build      # 必需，否则打包后 Host 自检报插件未激活
corepack yarn workspace dsh-desktop-next build
corepack yarn workspace dsh-desktop-next package:dir
```

Windows 用 `dist:win-portable`（须原生 Windows，rcedit 改写 exe）；`.github/workflows/portable.yml`
已把两个平台接进 CI。

## 改动的源码文件

| 文件 | 改动 |
| --- | --- |
| `dsh-desktop-next/src/data-directory.ts` | +12：`PORTABLE_MARKER`、`portableRoot`/`portableDataDirectory`/`portableLocationRoot` |
| `dsh-desktop-next/src/main.ts` | +10/−4：检出 `portable.json` 后改走包内数据目录与位置记录 |
| `dsh-desktop-next/src/profiles.ts` | +7/−1：`PREINSTALLED_BUNDLES` 并入 `WEB_BUNDLES` |
| `dsh-desktop-next/package.json` | 加两个插件依赖 + 两条 `asarUnpack` |
| `.github/workflows/portable.yml` | 新增：Windows/Linux 双平台便捷包 |

## CI 验证结果（liyunxuanyu/dsh-desktop，run 41776232911）

两个 job 全绿，关键证据：

| 平台 | 证据 |
| --- | --- |
| Windows | `Packaged Next Host booted from …\app.asar: profile desktop, loopback http://127.0.0.1:52211, diagnostics export ok`；`Verified the archive against the prepared Next payload: 31284 files (3671 unpacked) for win32`；启动 60 s 后 `home/data` 内含 `electron-user-data`、`logs`，且 `%APPDATA%\DSH NEXT\home` 未被写入 |
| Linux | `Verified the archive against the prepared Next payload: 20995 files (2288 unpacked) for linux`；`xvfb-run` 真开窗口后 `home/data` 内含 `electron-user-data`，`~/.dsh/profiles` 不存在 |

另外 Windows 侧日志显示原生插件确实加载：
`Packaged computer-use driver loaded from …\cua-driver-win32-x64-msvc: 56 tools`。

产物：`dsh-next-portable-win-x64`（613 MB）、`dsh-next-portable-linux-x64`（443 MB），
在 Actions run 页面下载，保留至 2027-02-02。

注意：`workflow_dispatch` 只有在默认分支存在该工作流时可用；当前默认分支是 `master`，
所以要么把改动合进 `master`，要么靠 `push` 到 `portable/next` 触发。

## 发布产物（tag `v2.0.21-next-portable`）

https://github.com/liyunxuanyu/dsh-desktop/releases/tag/v2.0.21-next-portable

| 资产 | 大小 | SHA256 |
| --- | --- | --- |
| `DSH-NEXT-2.0.21-next-x64-Portable.zip` | 582.3 MB | `0124b669f76e77ed898b45e8532bf4d898c703e6db04bd10591a46738d84b441` |
| `DSH-NEXT-2.0.21-next-linux-x64-portable.tar.gz` | 445.8 MB | `bc5626fe45fbdf6b9315a015596e207e20c0dd5c8e25d3573f31858ae32860bc` |
| `SHA256SUMS.txt` | — | — |

首次发布踩到的坑：CI 里为省时间设了 `DSH_WINDOWS_PACKAGE_COMPRESSION=store`，
发布资产因此是未压缩的 1.66 GB zip；去掉该覆盖后按 `build.win.compression: normal` 压到 582 MB。

## 预装清单数据化 + 离线插件包（tag `v2.0.21-next-portable.4`）

https://github.com/liyunxuanyu/dsh-desktop/releases/tag/v2.0.21-next-portable.4

| 资产 | 大小 | SHA256 |
| --- | --- | --- |
| `DSH-NEXT-2.0.21-next-x64-Portable.zip` | 582.3 MB | `3d503abd…d3b98a` |
| `DSH-NEXT-2.0.21-next-linux-x64-portable.tar.gz` | 445.3 MB | `c7967469…49f7e1` |
| `DSH-NEXT-2.0.21-next-offline-plugins.tar.gz` | 18.1 MB | `234a9c34…9c3007` |
| `SHA256SUMS.txt` | — | — |

**加插件现在是改数据，不是改代码**：`dsh-desktop-next/package.json` 的
`dsh.portableBundles` 列出预装 bundle，`dependencies` 给出对应版本；
`profiles.ts` 在运行时读这个清单拼进 `WEB_BUNDLES`，CI 则据此灌 pnpm store 与 `registry/`。

**离线插件包**（独立分发，18 MB）：内含插件 tgz、按依赖闭包写满的 pnpm store，
以及 `install-plugins.sh` / `.cmd`。用法：

```sh
tar -xzf DSH-NEXT-2.0.21-next-offline-plugins.tar.gz
./plugins-offline/install-plugins.sh          # 先启动一次便捷包生成 Profile
```

### 这一步踩的两个坑（都已修）

1. **清单文件不在 asar 里**：最初把清单放在 `portable-bundles.json` 兄弟文件，
   workspace 包的 `files` 字段不生效，打包后启动直接 `ENOENT portable-bundles.json`。
   改为放在 `package.json` 的 `dsh.portableBundles`，它一定随 asar 走。
2. **`pnpm store add` 不写依赖闭包**：它只存被点名的包，`commander`/`undici` 缺失，
   离线安装报 `ERR_PNPM_NO_OFFLINE_TARBALL`。改为用一次性的 `pnpm add` 解析整个闭包写进 store。
3. 附带一个隐蔽 bug：`--store-dir` 用了相对路径、又放在 `cd "$scratch"` 之后，
   store 被写进临时目录随后删除。现在全部绝对路径，并在 CI 里断言 `store/v11` 存在，
   还加了一步「把离线包装进临时 Profile」的端到端检查（日志会打印 `offline install ok: …`）。

## 分发校验与离线清单（tag `v2.0.21-next-portable.5`）

https://github.com/liyunxuanyu/dsh-desktop/releases/tag/v2.0.21-next-portable.5

Release 里除三个产物外，还带 `SHA256SUMS.txt` 与 `verify-download.sh / .ps1 / .cmd`，
内网分发时可以只拿这四个小文件核对完整性：

```sh
curl -LO <release>/verify-download.sh
curl -LO <release>/SHA256SUMS.txt
curl -LO <release>/DSH-NEXT-2.0.21-next-x64-Portable.zip
chmod +x verify-download.sh && ./verify-download.sh
```

Windows 用 `verify-download.cmd`（内部调用 `Get-FileHash`）。脚本对「通过 / 不匹配 / 缺失」
三种情况分别给出结论并以非零码退出，可直接接进运维脚本。

**离线包的 `--list`**：

```sh
./plugins-offline/install-plugins.sh --list      # 只列清单，不动 Profile
```

清单来自打包时写入的 `plugins.json`（插件名 + 版本），缺失时退回 tgz 文件名。
不带参数直接运行则执行安装。

### 本地验证过的行为

| 场景 | 结果 |
| --- | --- |
| `--list` 在包内运行 | 正确列出 `dsh-ops@0.4.4`、`@liustack/modsearch@5.10.11` 与 store 体积 |
| 校验通过 | `通过 a.txt` → exit 0 |
| 文件被篡改 | `不匹配 a.txt` 并打印期望/实际哈希 → exit 1 |
| 只下载了部分资产 | 已核对的通过、未下载的跳过 → exit 0（避免运维误报） |
| 一个待校验文件都没有 | `没有找到任何待校验文件` → exit 1 |
| 离线安装回归 | `offline install ok: @liustack/modsearch, dsh-ops`（CI 同步验证） |

用真实 Release 资产验证过：下载 `v2.0.21-next-portable.5` 的
`DSH-NEXT-2.0.21-next-offline-plugins.tar.gz`（18 MB）后，
`verify-download.sh` 报 `通过 …` 并与发布页 SHA256 一致。

## 包内使用说明与 Windows 离线仓库（tag `v2.0.21-next-portable.7`）

- 包根目录新增 `README.md`（随 `portable/` 一起打进 Linux 与 Windows 产物）：
  首次启动、目录职责、预装清单、离线装插件、清空带走、排错、校验下载。
- Windows 任务补上 **registry seeding**：此前只有 Linux 包带 `registry/store`，
  Windows 包的 `.npmrc` 指向一个不存在的目录，包内离线装插件实际无效。
  现在两边都用包内 node + pnpm 走真实依赖解析填充 store，并断言 `store/v11` 存在。

## 第十版（tag `v2.0.21-next-portable.8`）— 全绿

https://github.com/liyunxuanyu/dsh-desktop/releases/tag/v2.0.21-next-portable.8

| 资产 | 大小 | SHA256 |
| --- | --- | --- |
| `DSH-NEXT-2.0.21-next-x64-Portable.zip` | 582.34 MB | `343325fe…039ed5` |
| `DSH-NEXT-2.0.21-next-linux-x64-portable.tar.gz` | 445.35 MB | `9d0709ed…a7abe7` |
| `DSH-NEXT-2.0.21-next-offline-plugins.tar.gz` | 18.09 MB | `e1271b6b…7411ab` |
| `SHA256SUMS.txt` + `verify-download.{sh,ps1,cmd}` | — | — |

Windows 侧证据（run 41811933740）：
- `preinstalled plugins: dsh-ops@0.4.4, @liustack/modsearch@5.10.11`
- `registry/` 内出现 `dsh-ops-0.4.4.tgz`、`liustack-modsearch-5.10.11.tgz`（store seeding 成功）
- `preinstalled: dsh-ops` / `preinstalled: @liustack/modsearch`（插件随包且已解包）
- 启动 60 s 后 `home/data` 中出现 `electron-user-data`，`%APPDATA%\DSH NEXT\home` 未被创建

### 第五次踩坑：Windows 的 node 在 `bin/` 下

`primary-runtime.ts:158` 把 Windows 的 node 从归档里的 `node.exe` 复制到
`dependencies/node/bin/node.exe`——和 Linux 的 `bin/node` 同构。我在 registry seeding
与 `install-plugins.cmd` 里都写成了 `dependencies/node/node.exe`，少了 `bin/`，
于是 PowerShell 报「不是可识别的 cmdlet/可执行程序」。现在两处都改正，
并在 seeding 前断言解释器存在，避免再次静默失败。

## UI 冒烟与包内注册表回退（tag `v2.0.21-next-portable.9`）

https://github.com/liyunxuanyu/dsh-desktop/releases/tag/v2.0.21-next-portable.9

CI 的 Linux 任务在打包前多跑一步仓库自带的 Playwright 验证（headless Chromium，
不需要 X 服务器），日志证据：

```
Next onboarding passed in standalone pre-Host shell and official account continuation:
independent native eligibility, official progress completed, state-read and save retries,
six pages, artwork, back navigation, choices, skip, completion, inert cleanup, and no repeat
```

这一步覆盖首次引导的六个页面、跳过、完成、以及「不重复弹出」，比只测进程存活有意义得多。

**安装脚本的注册表回退**：`install-plugins.sh/.cmd` 现在按
`显式参数 > ./plugins-offline/ > 包内 registry/` 的顺序找插件包，
所以不下载那个 18 MB 的独立包、直接用包内 `registry/` 也能装：

```sh
./install-plugins.sh          # 自动用 ./registry
./install-plugins.sh --list   # 看清单
```

本地端到端验证：干净 Profile 下从包内 registry 安装，`dependencies` 得到
`["@liustack/modsearch", "dsh-ops"]`。

### 又一个环境坑：git push tag 被服务端拒绝

`git push refs/tags/…` 两次分别返回 `Internal Server Error` 与 `fatal error in commit_refs`，
改用 GitHub API `POST /git/refs` 创建 tag 立即可用（201）。分支 push 正常，仅 tag 受影响；
以后打 tag 走 API 更省事。

## 测试与第十版（tag `v2.0.21-next-portable.10`）

便携模式此前只靠 CI 端到端验证，代码层没有单测。补了 3 条：

- `portableRoot` / `portableDataDirectory` / `portableLocationRoot` 的路径推导，以及
  Electron 数据目录一定落在 `portableRoot` 之下；
- 标记文件名 `portable.json` 的常量；
- `dsh.portableBundles` 的每一项都必须是 `dependencies` 里的真实依赖，
  且都会进 `WEB_BUNDLES`——这条防的是「清单里写了但没装，打包后启动才炸」。

全量桌面端单测：**110 个文件 / 978 通过 / 17 跳过**。

发布：https://github.com/liyunxuanyu/dsh-desktop/releases/tag/v2.0.21-next-portable.10

## 空清单重构与上游分支（tag `v2.0.21-next-portable.11`）

两个目标：

1. **允许空清单**：`readPortableBundles()` 现在把「没写 `dsh.portableBundles`」视为空数组，
   只有格式非法才抛错。这样上游分支可以保持 `portableBundles: []` 的中立默认，
   而分发版填两个插件——代码完全一致，只有数据不同。
2. **给上游准备一个只含核心改动的分支**：`upstream/portable-core`（从 `117e489` 起），
   包含 `data-directory.ts` / `main.ts` / `profiles.ts` 的便携模式、对应单测、
   `portable/` 下的启动器与 reset 脚本、以及说明；**不含**我们的 CI workflow、
   离线插件包、校验脚本和具体插件清单。

本地全量单测：110 个文件 / 978 通过 / 17 跳过。

### 第十一版（tag `v2.0.21-next-portable.11`）— 最终版

https://github.com/liyunxuanyu/dsh-desktop/releases/tag/v2.0.21-next-portable.11

代码与产物一一对应（tag 指向最终提交 `2908bb7`），三个 job 全绿：

```
Next onboarding passed ... six pages, artwork, back navigation, choices, skip, completion, inert cleanup, and no repeat
Verified the archive against the prepared Next payload: 20995 files (2288 unpacked) for linux x64
offline install ok: @liustack/modsearch, dsh-ops
```

| 资产 | 大小 | SHA256 |
| --- | --- | --- |
| `DSH-NEXT-2.0.21-next-x64-Portable.zip` | 582.34 MB | `fe1da56d…5c2d0d` |
| `DSH-NEXT-2.0.21-next-linux-x64-portable.tar.gz` | 445.36 MB | `4b9b9fde…4f1980` |
| `DSH-NEXT-2.0.21-next-offline-plugins.tar.gz` | 18.08 MB | `f6ae844e…bf8b21` |

上游贡献已备在分支 `upstream/portable-core`（从 `117e489` 起，13 个文件，只含便携核心），
PR 说明草稿在 `/root/dsh-next-desktop/upstream/PR.md`，补丁同目录。

### `master` 引用修复

之前用 `git push HEAD:master` 推送，本地 `master` 引用没随之前移，停在 `35fd93d`，
导致后续 `git checkout master` 拿到旧树（`package.json` 没有 `dsh.portableBundles`，
单测 1 条失败、脚本报 `KeyError`）。用 `git reset --hard 4ac8d23` 修正引用后，
同步「允许空清单」的重构，全量单测恢复 **110 文件 / 978 通过 / 17 跳过**。

## 离线安装的真实缺陷与修复（tag `v2.0.21-next-portable.13`）

把发布的 Linux 包解压到干净环境实测时发现：`install-plugins.sh` 装 `@liustack/modsearch`
直接失败——

```
[ERR_PNPM_NO_OFFLINE_META] Failed to resolve commander@>=13.1.0 <14.0.0-0
  in package mirror …/registry/cache/v12/metadata/https%3A+registry.npmjs.org/commander.jsonl
```

原因：pnpm 的 store 只有 tarball，**解析 `commander@^13.1.0` 这类范围依赖需要元数据缓存**，
而包内 `registry/cache` 一直是空的。CI 里之所以没暴露，是因为同一台机器上刚做过 seeding，
全局缓存里恰好有元数据。

修复分三处：

1. **打包时把元数据一起写进包**：seeding 的 `pnpm add` 增加 `--config.cacheDir=<包内 cache>`，
   并断言 `registry/cache/v12/metadata` 存在；
2. **安装时指向同一份 cache**：`install-plugins.sh/.cmd` 传 `--config.cacheDir=…`；
3. **两个坑**：
   - 标志必须写成 **camelCase 且用等号**（`--config.cacheDir=…`）。短横线式 `--config.cache-dir`
     会被忽略；把路径当作下一个参数传，pnpm 还会报 `opts.cacheDir is required`。
   - 不能导出 `NPM_CONFIG_CACHE` / `NPM_CONFIG_STORE_DIR`：大写变量会让 pnpm 把 cacheDir 解析成空值。
   - PowerShell 里 `--config.cacheDir=(Join-Path …)` 会按字面量传给 pnpm，必须先算好再插值
     （这正是 `.12` 的 Windows 失败原因）。

验证（在**发布的 .13 包**上，`HOME` 指向全新的空目录）：

```
$ HOME=/tmp/cleanhome5 sh ./install-plugins.sh
Done in 1.8s using pnpm v11.28.5
deps: ['@liustack/modsearch', 'dsh-ops']
$ sh ./DSH-NEXT-reset.sh --yes
已清空用户数据 …
```

发布：https://github.com/liyunxuanyu/dsh-desktop/releases/tag/v2.0.21-next-portable.13

## 应用内装插件也走包内离线仓库（tag `v2.0.21-next-portable.14`）

pnpm 11 的配置读取顺序很容易踩坑，实测结论：

| 写法 | 是否生效 |
| --- | --- |
| `--config.cacheDir=<abs>` / `--config.storeDir=<abs>`（驼峰 + 等号） | ✅ |
| `--config.cache-dir=<abs>`（短横线） | ❌ 被忽略 |
| `--config.cacheDir <abs>`（空格分隔） | ❌ 报 `opts.cacheDir is required` |
| `NPM_CONFIG_CACHE` / `NPM_CONFIG_STORE_DIR` 环境变量 | ❌ 会让 cacheDir 解析成空值 |
| `.npmrc` 里的 `storeDir=` / `cacheDir=` | ❌ 不读 |
| Profile 下 `pnpm-workspace.yaml` 的 `storeDir:` / `cacheDir:` | ✅ |

因此启动器（`DSH-NEXT.sh/.cmd`）与 `install-plugins.sh/.cmd` 现在都会在每个
`home/data/profiles/*/` 下写一份 `pnpm-workspace.yaml`：

```yaml
storeDir: <包>/registry/store
cacheDir: <包>/registry/cache
preferOffline: true
```

这样**界面里装插件**也会命中包内 store，而不是退回 `~/.local/share/pnpm/store`。
验证：干净 `HOME` 下 `install-plugins.sh` 装齐两个插件，`deps: ['@liustack/modsearch', 'dsh-ops']`。

## 最终状态（tag `v2.0.21-next-portable.14`）

https://github.com/liyunxuanyu/dsh-desktop/releases/tag/v2.0.21-next-portable.14

| 资产 | 大小 | SHA256 |
| --- | --- | --- |
| `DSH-NEXT-2.0.21-next-x64-Portable.zip` | 582.34 MB | `1fcfad9c…5527a3` |
| `DSH-NEXT-2.0.21-next-linux-x64-portable.tar.gz` | 445.59 MB | `bac21d20…1e1bf1` |
| `DSH-NEXT-2.0.21-next-offline-plugins.tar.gz` | 18.30 MB | `35d519aa…1f4d3f1` |

在**已发布的 .14 Linux 包**上做的最终验证（`HOME` 指向全新空目录）：

```
$ sh ./install-plugins.sh
Done in 2.4s using pnpm v11.28.5
完成。重新启动便捷包使插件生效。
deps: ['@liustack/modsearch', 'dsh-ops']

$ cat home/data/profiles/desktop/pnpm-workspace.yaml
storeDir: /tmp/v14/linux-unpacked/registry/store
cacheDir: /tmp/v14/linux-unpacked/registry/cache
preferOffline: true
```

即：包内 `registry/store`（25M）+ `registry/cache`（728K）齐全，安装脚本与启动器都会把
绝对路径写进 Profile 的 `pnpm-workspace.yaml`，界面里装插件同样命中包内仓库。

已知细节：`pnpm-workspace.yaml` 是按「已存在的 Profile」写入的，所以**首次启动**后才会有该文件；
正常使用（第二次启动起）以及运行 `install-plugins.sh` 之后都会就位。

## 文档同步版（tag `v2.0.21-next-portable.15`）

`.14` 的发布标签指向功能提交 `e02b2f0`，其后的三个文档提交没有随包发布，
导致包内 `README.md` 缺少「离线仓库怎么生效」一节。`.15` 把标签移到最新提交，
使**包内文档、`PORTABLE.md` 与产物完全一致**；除文档外，代码与 `.14` 相同。

（`.14` 之后不再需要清理：保留 `.14` 与 `.15` 中的最新者即可。）

## 运行时如何随包提供（tag `v2.0.21-next-portable.17`）

运行时都在 `resources/runtime/x64/primary-runtime/dependencies/`：

| 组件 | 路径 | 版本 |
| --- | --- | --- |
| Node | `node/bin/node`（Windows `node/bin/node.exe`） | 24.21.0 |
| pnpm | `pnpm/bin/pnpm.mjs` | 11.28.5 |
| Python | `python/bin/python3`（Windows `python/python.exe`） | 3.12.14 |

这之前存在一个**实际缺口**：启动器只设置 `DSH_DESKTOP_NEXT_HOME` 与离线仓库配置，
**没有把运行时目录放进 PATH**。源码侧的现状是：

- `host-process.ts` 用 `desktopNodeEnvironment(this.node, undefined, …)` 启动 Host，
  而 `node-environment.ts` 只在传入 `bin` 时才改 PATH —— 也就是 Host 继承系统 PATH；
- `bundled-pnpm.ts` 只给 pnpm 子进程加了 `scripts/node-bin` 这层 PATH；
- `host/office.ts` 给 Office 技能传了 node 的绝对路径；
- `@deepseek-ai/dsh-tool-workspace-dependencies` 只把绝对路径**告诉模型**，
  其 README 明确写着 "changes neither PATH nor package-manager settings"。

于是第三方插件里若直接 spawn `node` / `python3`，在没装运行时的机器上会失败。
现在 `DSH-NEXT.sh` / `.cmd` 与 `install-plugins.sh` / `.cmd` 都会把
`dependencies/node/bin`、`dependencies/python/bin`（Windows 为 `dependencies/python` 与 `Scripts`）
前置到 PATH。

验证（在**发布的 .16 包**上，用 `env -i PATH=/usr/bin:/bin` 模拟没装 Node/Python 的机器）：

```
$ sh ./DSH-NEXT.sh          # 探测脚本替换 exec 行后运行
node: /tmp/rt/linux-unpacked/resources/runtime/x64/primary-runtime/dependencies/node/bin/node
python3: /tmp/rt/linux-unpacked/resources/runtime/x64/primary-runtime/dependencies/python/bin/python3
node runtime: v24.21.0
python runtime: 3.12.14
```

同时回归了离线安装：干净 HOME 下 `install-plugins.sh` 仍装齐两个插件
（`deps: ['@liustack/modsearch', 'dsh-ops']`）。

## 包内自洽：在线安装、运行时下载、插件库更新（tag `v2.0.21-next-portable.18`）

`v2.0.21-next-portable.17` 只解决了「运行时能找到」，还剩下三个真实缺口：

1. 联网装插件时，pnpm 的 store / 元数据缓存 / 状态目录仍是**用户目录**下的默认位置
   （`~/.local/share/pnpm`、`~/Library/pnpm`、`%LOCALAPPDATA%\pnpm`），
   包搬走就丢；
2. AI（或技能）用 `uv` / `pip` 下载的 Python 与包，同样落在 `~/.cache`、`~/.local`；
3. 包内离线插件库**没有更新入口**，版本只能等下一次发版。

### 一、程序自己解析包内路径，不依赖任何用户配置

新增 `src/portable-environment.ts`。存在 `portable.json` 时，主进程在启动早期
把下面这些变量写进**自己的进程环境**，Host、插件、终端、Agent 派生的子进程全部继承：

| 变量 | 指向 |
| --- | --- |
| `DSH_PORTABLE_ROOT` | 包根 |
| `XDG_CACHE_HOME` / `XDG_STATE_HOME` / `XDG_DATA_HOME` | `home/cache` / `home/state` / `home/share` |
| `pnpm_config_store_dir` / `pnpm_config_cache_dir` / `pnpm_config_state_dir` | `registry/store` / `registry/cache` / `home/state/pnpm` |
| `npm_config_cache` / `npm_config_prefix` | `home/cache/npm` / `home/npm-global` |
| `PIP_CACHE_DIR` / `PYTHONUSERBASE` | `home/cache/pip` / `home/share/python-user` |
| `UV_CACHE_DIR` / `UV_PYTHON_INSTALL_DIR` / `UV_TOOL_DIR` / `UV_TOOL_BIN_DIR` | `home/cache/uv` 等 |
| `COREPACK_HOME` | `home/cache/corepack` |
| `PATH` | 前置包内 `node/bin`、`python/bin`（Windows 另有 `python`、`Scripts`） |

两点是实测出来的，不是推测：

- **`pnpm_config_*` 必须用小写带下划线的形式**，pnpm 11 才认；
  `NPM_CONFIG_CACHE` 这类大写变量会让 pnpm 把 `cacheDir` 解析成空值，
  这也是 `.13` 之前离线安装偶发失败的原因之一。
- 只设 `XDG_*` 时 pnpm 会把 store 放到 `$XDG_DATA_HOME/pnpm`、状态放到 `$XDG_STATE_HOME/pnpm`，
  所以 `pnpm_config_*` 与 XDG 要一起给，才能精确落到 `registry/`。

同一实现也接进了 `<包> dsh …` 这条 CLI 引导路径（`desktop-cli.ts`），
即使从别的目录执行 CLI，插件命令依旧写进包内。

### 二、Profile 的 pnpm 配置改成相对路径

`NextProfiles.ensure()` / `create()` 现在会（仅在便携模式）向 Profile 的
`pnpm-workspace.yaml` **追加**两条设置，而不是整份重写——上游模板里的
`packages`、`nodeLinker: hoisted` 必须保留，整份覆盖会破坏安装布局：

```yaml
storeDir: ../../../../registry/store
cacheDir: ../../../../registry/cache
```

相对路径指向包根，因此**包被改名、搬到别的目录之后仍然有效**
（`.17` 及以前由启动器写入绝对路径，搬走就失效）。
启动器与 `install-plugins.sh` 里原先那段「按绝对路径重写 yaml」的代码已删除。

### 三、插件库更新

新增 `tools/refresh-library.mjs`，由 `update-plugins.sh` / `update-plugins.cmd` 驱动，
用**包内 node + pnpm** 重新解析并下载：

```sh
./update-plugins.sh              # 按 registry/plugins.json
./update-plugins.sh --latest     # 全部取最新
./update-plugins.sh dsh-ops@0.5.0
```

它把新版本写回包内三处（tarball、store、元数据缓存）并重写 `registry/plugins.json`，
同时删掉同一插件的旧 tarball。全程只改包内文件。

实测（在发布的 `.16` 包上，先补一份 `registry/plugins.json`）：

```
refreshing 2 plugin(s) into /tmp/rt/linux-unpacked/registry
+ @liustack/modsearch 5.10.11
+ dsh-ops 0.4.4
  dsh-ops@0.4.4 → dsh-ops-0.4.4.tgz
  @liustack/modsearch@5.10.11 → liustack-modsearch-5.10.11.tgz
plugin library refreshed: dsh-ops@0.4.4, @liustack/modsearch@5.10.11
```

刷新后 store 与缓存都留在 `registry/` 下，离线安装依旧可用。

### 四、在线安装的隔离验证

在解压出来的包里，用**干净 HOME**跑一次在线安装：

```sh
# 用包内 node + pnpm，PATH 里只有 /usr/bin:/bin
env -i HOME=/tmp/audit-home2 PATH=/usr/bin:/bin \
  XDG_CACHE_HOME=<pkg>/home/cache XDG_STATE_HOME=<pkg>/home/state \
  pnpm_config_store_dir=<pkg>/registry/store pnpm_config_cache_dir=<pkg>/registry/cache \
  pnpm_config_state_dir=<pkg>/home/state/pnpm \
  <pkg>/…/node/bin/node <pkg>/…/pnpm/bin/pnpm.mjs add dsh-context
```

结果：`+ dsh-context 0.80.3 / Done in 2.8s`，`find /tmp/audit-home2` 只有 **HOME 目录本身**——
用户目录零写入。反证也确认过：不给这些变量时，pnpm 会写
`$HOME/.local/state/pnpm/pnpm-state.json` 与 `$HOME/.local/share/pnpm/store`。

### 五、CI 新增的断言

`windows-portable` / `linux-portable` 两个 job 现在会：

- 启动后检查 Profile 的 `pnpm-workspace.yaml` 含**相对** `storeDir`/`cacheDir`，
  且 `home/cache`、`home/state` 存在；
- 用干净 HOME 做一次在线安装，断言 HOME 内无任何写入；
- 跑一次 `update-plugins.sh --latest`，断言 `registry/plugins.json` 被重写、
  刷新后的库**仍能离线安装**；
- 断言 `tools/refresh-library.mjs`、`update-plugins.sh` / `.cmd`、
  `registry/plugins.json` 都随包发布。

### 单元测试

新增 `tests/portable-environment.spec.ts`（5 条）：路径全部落在包内、
PATH 去重、非便携模式不改环境、Profile 的 pnpm 配置为相对路径、
普通安装不写 `storeDir`。
`tests` 全量（Node 24）：**111 个文件 / 983 通过 / 17 跳过**；
`tsc --noEmit` 通过。
（本地 `node` 是 22.11，缺 `module.registerHooks`，用 22.11 跑会有 24 条与本次改动无关的
环境性失败；仓库要求 `^22.19` 或 `>=24`。）
