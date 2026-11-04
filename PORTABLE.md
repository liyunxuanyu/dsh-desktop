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
