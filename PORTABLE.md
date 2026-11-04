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
| 文件缺失 | `缺失 a.txt` → exit 1 |
| 离线安装回归 | `offline install ok: @liustack/modsearch, dsh-ops`（CI 同步验证） |
