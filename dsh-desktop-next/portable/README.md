# DSH NEXT 便捷包（桌面版）

解压即用：不需要安装 Node、Python 或 pnpm，会话与插件也都在这个目录里。
**整个文件夹可以拷到 U 盘、换台电脑继续用。**

## 第一次用

| 系统 | 双击 / 执行 |
| --- | --- |
| Windows x64 | `DSH-NEXT.cmd` |
| Linux x64 | `./DSH-NEXT.sh` |

首次启动会在本目录生成 `home/`，之后所有数据（会话、凭据、浏览器缓存、日志）都留在里面。

## 目录里都是什么

```
DSH-NEXT.cmd / .sh        启动器（唯一入口）
DSH-NEXT-reset.cmd / .sh  清空用户数据（保留程序与插件），换机前执行
portable.json             便携标记：程序据此把数据写进 ./home
.npmrc                    pnpm 指向包内的 registry/store
registry/                 离线插件仓库（预装插件的包 + pnpm store）
resources/                程序本体与内置运行时（Node / pnpm / Python）
home/                     你的数据（首次启动后出现）
```

**不要删除** `portable.json`、`resources/`、`registry/`：删了会退回「写到用户目录」的模式，
或者丢掉离线装插件的能力。

## 已经预装什么

- 核心工具集与 Web UI（`@deepseek-ai/dsh-base`、`dsh-web-app`）
- `dsh-ops`：原生文件检索 / 批处理（Rust 后端）
- `@liustack/modsearch`：网页搜索、读页、X 搜索

首次启动后进「设置 → 模型」填自己的服务商与 API Key 即可开始。
凭据保存在 `home/data/.credentials.yaml`。

## 加插件（离线）

预装插件已随包，若要再装别的：

```sh
./install-plugins.sh --list                 # 先看清单，不动 Profile
./install-plugins.sh                        # 装进当前 Profile
```

脚本按 `显式路径 > ./plugins-offline/ > 包内 registry/` 的顺序找插件来源，
所以**不下载那个独立的离线包也能装**——直接用包内 `registry/`。
要装清单以外的插件，才需要 Release 里的 `*-offline-plugins.tar.gz`。

## 离线仓库怎么生效

包内 `registry/`（store + 元数据缓存）就是离线源。启动器和 `install-plugins` 会把
**绝对路径**写进各 Profile 的 `pnpm-workspace.yaml`：

```yaml
storeDir: <包>/registry/store
cacheDir: <包>/registry/cache
preferOffline: true
```

pnpm 11 只认这份配置（`.npmrc` 里的 storeDir/cacheDir 和 `NPM_CONFIG_*` 环境变量都不生效），
所以界面里装插件也会命中包内仓库。该文件在**首次启动之后**由启动器写入，
运行一次 `install-plugins.sh` 也会立即补齐。

## 换电脑 / 交接

```sh
./DSH-NEXT-reset.sh --yes     # 清掉 home/（会话、凭据、缓存），程序与运行时不动
```

之后压缩整个目录带走即可。想连插件配置一起保留，就不要执行 reset，直接拷走整个文件夹
（注意 `home/` 里有你的 API Key）。

## 出问题先看这里

- **端口被占 / 打不开界面**：退出后用命令行启动 `DSH-NEXT.cmd`（Windows）或 `./DSH-NEXT.sh`（Linux），
  窗口会打印实际地址与报错。
- **插件没生效**：插件装完需要重启便捷包。
- **想恢复出厂**：执行 reset 脚本，或直接删掉 `home/`。
- **Windows 首次运行被 SmartScreen 拦**：未签名程序的常规提示，选「更多信息 → 仍要运行」。

## 校验下载完整性

Release 里附带 `SHA256SUMS.txt` 与校验脚本：

```sh
./verify-download.sh          # Linux / macOS
verify-download.cmd           # Windows
```
