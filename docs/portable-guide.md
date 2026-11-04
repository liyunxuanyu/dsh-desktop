# DSH NEXT 便捷包使用指南

这是一份**给拿到压缩包的人**看的文档：从下载、校验、解压，到第一次启动、配置模型、
安装插件、清空带走和排错，都不需要任何开发知识。

- 不需要安装 Node、Python 或 pnpm，运行时全部在包里。
- 不需要管理员权限，解压到任意可写目录即可。
- 所有数据（会话、凭据、缓存、日志）都在包内，可以整个文件夹拷走。

> 这是本仓库（`liyunxuanyu/dsh-desktop`）发布的便携构建说明。上游产品文档见
> [`docs/`](README.md)，本仓库相对上游只增加了「便携化 + 预装插件 + 离线仓库」这一层。

---

## 1. 下载哪个文件

到本仓库的 [Releases](https://github.com/liyunxuanyu/dsh-desktop/releases/latest) 页面，
按你的系统选一个：

| 你的系统 | 下载这个 | 大小（约） |
| --- | --- | --- |
| Windows 10/11 x64 | `DSH-NEXT-<版本>-x64-Portable.zip` | 582 MB |
| Linux x64（Ubuntu/Debian/Fedora 等） | `DSH-NEXT-<版本>-linux-x64-portable.tar.gz` | 446 MB |
| 想离线装更多插件（可选） | `DSH-NEXT-<版本>-offline-plugins.tar.gz` | 18 MB |

同一页还有：

- `SHA256SUMS.txt`：所有产物的校验和；
- `verify-download.sh` / `verify-download.cmd` / `verify-download.ps1`：一键校验脚本。

> 目前只提供 **Windows x64** 与 **Linux x64**。macOS、Windows ARM、Linux ARM 没有构建。

## 2. 先校验（可选，但建议）

下载完把校验脚本和 `SHA256SUMS.txt` 放在同一个目录，然后：

```sh
# Linux / macOS
chmod +x verify-download.sh
./verify-download.sh
```

```bat
:: Windows
verify-download.cmd
```

输出 `通过 <文件名>` 就说明文件完整。只下载了其中一个包也没关系，脚本会跳过没下载的。
出现 `不匹配` 说明文件损坏，重新下载。

## 3. 解压

**Windows**

1. 右键 zip →「全部解压缩」（不要直接在压缩包里双击运行）；
2. 建议解压到 `D:\DSH-NEXT` 这类**你自己可写**的目录；
3. 不要放在 `C:\Program Files` 下——那里需要管理员权限，程序无法写自己的 `home/`。

**Linux**

```sh
tar -xzf DSH-NEXT-<版本>-linux-x64-portable.tar.gz
cd linux-unpacked
```

解压后约 1.3 GB，属于正常大小（里面带了 Electron、Node、Python 与插件仓库）。

## 4. 第一次启动

| 系统 | 怎么做 |
| --- | --- |
| Windows | 双击 `DSH-NEXT.cmd`（也可以直接运行 `DSH NEXT.exe`，但用 `.cmd` 会一并配置离线仓库） |
| Linux | `./DSH-NEXT.sh` |

首次启动会做两件事：

1. 在本目录创建 `home/`，之后所有数据都写在这里；
2. 弹出应用窗口并走一遍首次引导（选择外观、是否启用插件市场等）。

Windows 第一次运行时可能弹出 **SmartScreen** 蓝框：点「更多信息 → 仍要运行」。
这是未签名程序的常规提示，不是报毒。

> 如果窗口没出现：用命令行启动（Windows 在资源管理器地址栏输入 `cmd` 回车，
> 再执行 `DSH-NEXT.cmd`；Linux 直接在终端 `./DSH-NEXT.sh`），启动器会把真实报错打印出来。

## 5. 配置模型（必须做，否则不能对话）

DSH 只是客户端，模型要接你自己的服务商。启动后：

1. 打开应用内的**设置**；
2. 找到模型 / 服务商相关设置，填入 **Base URL**、**模型名** 和 **API Key**；
3. 保存后即可开始对话。

填写的凭据只保存在本包 `home/data/` 下，不会上传到别处（除非你自己把包分享出去）。

## 6. 包里已经装好什么

| 插件 / 组件 | 作用 |
| --- | --- |
| `@deepseek-ai/dsh-base` | 核心工具集：文件读写、命令执行、任务与子代理等 |
| `@deepseek-ai/dsh-web-app` | 应用界面本身 |
| `dsh-ops` 0.4.4 | 原生文件检索与批处理（Rust 后端，比纯 JS 快） |
| `@liustack/modsearch` 5.10.11 | 网页搜索、网页正文读取、X（Twitter）搜索 |

这些插件在**每个新建 Profile** 里默认启用，不需要你手动安装。

包内还带了：

- Node 24.21.0、pnpm 11.28.5、Python 3.12.14（技能、MCP 服务、脚本工具都能直接用）；
- `registry/`：预装插件的离线包与 pnpm store（25 MB + 元数据缓存）。

## 7. 装更多插件

**在界面里装**：设置 → 插件市场 / 插件管理，搜索后安装。离线仓库已经指向包内，
所以已预装的插件及其依赖不需要联网。

**用离线包装**（没有网络时）：

```sh
# Linux
./install-plugins.sh --list      # 先看清单，什么都不改
./install-plugins.sh             # 装进当前 Profile
```

```bat
:: Windows
install-plugins.cmd --list
install-plugins.cmd
```

- 插件来源按 `显式路径 > ./plugins-offline/ > 包内 registry/` 的顺序查找；
- 如果拿到了单独的 `*-offline-plugins.tar.gz`，解压得到 `plugins-offline/`，
  放在包目录旁边即可被自动发现，也可以把路径作为参数传进去；
- 装完**重启应用**生效。

## 8. 数据在哪、怎么清空带走

```
<包目录>/
├── home/                     你的数据（首次启动后出现）
│   └── data/
│       ├── profiles/         会话、每个 Profile 的插件配置
│       ├── electron-user-data/  界面缓存、窗口状态、Crashpad
│       └── logs/             运行日志
├── registry/                 离线插件仓库
├── resources/                程序与内置运行时（不要删）
├── portable.json             便携标记（不要删）
├── DSH-NEXT.cmd / .sh        启动器
└── DSH-NEXT-reset.cmd / .sh  清空用户数据
```

**把包交给别人 / 换电脑前**，清掉用户数据：

```sh
./DSH-NEXT-reset.sh --yes        # Linux
```

```bat
DSH-NEXT-reset.cmd --yes         :: Windows
```

它只删 `home/`（会话、凭据、缓存、日志），程序、运行时和插件都保留。
删除后重新启动就是一台「全新机器」。

想连配置一起带走就别执行 reset，直接压缩整个文件夹——**但要记得 `home/` 里有你的 API Key**。

## 9. 排错

| 现象 | 处理 |
| --- | --- |
| 双击没反应 / 窗口一闪而过 | 用命令行启动看报错（见第 4 节） |
| 提示无法写入 / 权限错误 | 包放在了只读或需要管理员权限的目录，换到用户目录 |
| 装完插件没生效 | 退出应用重新启动 |
| 界面打不开、端口冲突 | 退出后重试；仍不行检查是否有别的程序占用端口 |
| 想恢复出厂 | `DSH-NEXT-reset.*` 或直接删除 `home/` |
| Windows 报 SmartScreen | 「更多信息 → 仍要运行」 |
| 校验不通过 | 重新下载（网络中断导致文件损坏很常见） |

日志在 `home/data/logs/`，提 issue 时把它一起贴上最有帮助。

## 10. 常见问题

**插件用到的运行时从哪来？**
全部来自包内 `resources/runtime/x64/primary-runtime/dependencies/`（Node 24.21.0、pnpm 11.28.5、
Python 3.12.14）。启动器把 `node/bin` 与 `python/bin` 加进 PATH，插件的依赖由包内 pnpm
从包内离线仓库装进 Profile；插件、技能、MCP 服务里直接写 `node` / `python3` / `npm` / `pip`
都会命中包内版本，不需要系统预装。

**需要自己装 Node / Python 吗？**
不需要。包里已带 Node 24、pnpm 11、Python 3.12，启动器会把它们加进进程环境。

**需要联网吗？**
配模型、使用网页搜索类插件时需要；纯离线也能启动和使用本地能力。

**能装在 U 盘里吗？**
可以，整个目录是自包含的。注意 U 盘写入速度会影响响应。

**为什么这么大？**
Electron 运行时、三个解释器载荷和离线插件仓库都在里面，这是「解压即用」的代价。

**和上游 DSH Desktop 有什么区别？**
上游提供安装包（NSIS / deb / AppImage / DMG）；本仓库提供**免安装、数据在包内、
预装插件、带离线仓库**的便携包。上游文档见 [`docs/`](README.md)。

**会丢数据吗？**
只要 `home/` 在，数据就在。升级版本时把 `home/` 拷到新包同位置即可。
