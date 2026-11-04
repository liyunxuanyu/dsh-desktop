# DSH NEXT 便捷包

**解压就能用**：不用装 Node、Python 或 pnpm，插件已预装，数据都留在这个文件夹里。
把这个文件夹拷到 U 盘、换台电脑，解开就能继续用。

---

## 一、三十秒开始

**Windows**：双击 **`DSH-NEXT.cmd`**，等窗口出现。
若弹出 SmartScreen 蓝框，点「更多信息 → 仍要运行」。
（Windows 的 `.cmd` 脚本刻意只用 ASCII 输出：cmd.exe 按控制台代码页解码批处理，
中文多字节字符会吞掉下一行的开头。说明文档仍是中文。）

**Linux**：在终端执行 **`./DSH-NEXT.sh`**（如果提示没有执行权限，先 `chmod +x DSH-NEXT.sh`）。

窗口出现后，第一件事是**配置模型**（见第三节），否则无法对话。

## 二、这个文件夹里是什么

```
DSH-NEXT.cmd / DSH-NEXT.sh          启动器（推荐用它启动）
DSH-NEXT-reset.cmd / .sh            清空用户数据（换人/换机前用）
install-plugins.cmd / .sh           从离线仓库装插件
update-plugins.cmd / .sh            联网刷新包内插件库
verify-download.cmd / .ps1 / .sh    校验你下载的压缩包是否完整
portable.json                       便携标记：程序据此把数据写进 ./home
.npmrc                              包内 npm 偏好设置
registry/                           离线插件仓库（插件包 + pnpm store + 元数据缓存）
tools/                              维护脚本（刷新插件库）
resources/                          程序本体与内置运行时（Node / pnpm / Python）
home/                               你的数据（第一次启动后自动出现）
```

**不要删除** `portable.json`、`resources/`、`registry/`：
删了会退回「把数据写到用户目录」的模式，或者失去离线装插件的能力。

## 三、配置模型（必须）

1. 打开应用内的**设置**；
2. 找到模型 / 服务商设置，填入 **Base URL**、**模型名**、**API Key**；
3. 保存，回到对话界面即可开始。

凭据只保存在本目录 `home/data/` 下，不会上传到别处——但**分享这个包之前请先执行
`DSH-NEXT-reset`**，否则你的 Key 会跟着包一起被带走。

## 四、已经装好的插件

| 插件 | 能做什么 |
| --- | --- |
| `@deepseek-ai/dsh-base` | 核心工具：读写文件、执行命令、任务与子代理 |
| `@deepseek-ai/dsh-web-app` | 应用界面本身 |
| `dsh-ops` 0.4.4 | 原生文件检索与批处理（Rust 后端，搜索大仓库更快） |
| `@liustack/modsearch` 5.10.11 | 网页搜索、网页正文读取、X（Twitter）搜索 |

这些在每个新建的 Profile 里默认启用，不需要手动安装。
包内运行时：Node 24.21.0、pnpm 11.28.5、Python 3.12.14——
技能脚本、MCP 服务可以直接调用 `node` / `pnpm` / `python3`。

## 运行时不装也行：它们就在包里

三个运行时都放在 `resources/runtime/x64/primary-runtime/dependencies/`：

```
node/bin/node          Node 24.21.0（含 npm、npx）
pnpm/bin/pnpm.mjs      pnpm 11.28.5
python/bin/python3     Python 3.12.14（含 pip 与常用库）
```

启动器会把 `node/bin` 与 `python/bin` 加进 **PATH**，所以：

- 应用自己在包内 Node 上跑，不依赖系统 Node；
- 你在界面里装的插件，**它的依赖由包内 pnpm + 包内离线仓库**装进该 Profile，
  插件代码本身不需要系统运行时；
- 插件、技能、MCP 服务里写 `node`、`python3`、`npm`、`pip` 会直接命中包内版本，
  用户机器上没装 Node/Python 也能跑；
- 少数需要“绝对路径”的场景（例如 Office 技能），应用会通过
  `dsh-tool-workspace-dependencies` 工具把上面这些绝对路径告诉模型。

这些路径由程序自己按包目录算出来（`src/portable-environment.ts`），
**不需要你配置任何环境变量**：双击 `dsh-desktop-next` / `DSH NEXT.exe` 直接启动也一样。
`DSH-NEXT.cmd` / `./DSH-NEXT.sh` 只是顺手把解释器提前放进 PATH，方便你自己开终端调试。

## 五、再装插件

**界面里装**：设置 → 插件市场 / 插件管理，搜索安装。已指向包内离线仓库，
预装插件的依赖无需联网。

**用离线包装**（无网络时）：

```sh
./install-plugins.sh --list     # 只看清单，不改任何东西
./install-plugins.sh            # 装进当前 Profile
```

```bat
install-plugins.cmd --list
install-plugins.cmd
```

插件来源按 `显式路径 > ./plugins-offline/ > 包内 registry/` 查找。
如果另外下载了 `*-offline-plugins.tar.gz`，解压出的 `plugins-offline/`
放在本目录旁边就会被自动发现。**装完要重启应用。**

### 离线仓库是怎么生效的

程序在创建/打开每个 Profile 时，把**相对路径**追加进该 Profile 的 `pnpm-workspace.yaml`：

```yaml
storeDir: ../../../../registry/store
cacheDir: ../../../../registry/cache
```

相对路径指向包根，所以**把文件夹改名或搬到别处也不会失效**。
同时程序把 pnpm / npm / pip / uv 的 store、缓存、状态目录全部指向包内
（`DSH_PORTABLE_ROOT`、`pnpm_config_store_dir`、`XDG_CACHE_HOME` 等只对子进程生效，
你不需要设置它们），因此：

- 界面里装插件 → 包内 `registry/store`、`registry/cache`；
- 终端里 `pnpm add` / `npm i -g` → 同样落在包内；
- AI 用 `uv` / `pip` 下载 Python 或包 → 落在包内 `home/share/`；
- 用户目录（`~/.cache`、`~/.local/state`、`~/.npm`）**不会被写**。

### 更新自带插件库

包里的离线插件库会过期。联网时执行：

```sh
./update-plugins.sh                # 按 registry/plugins.json 的清单刷新
./update-plugins.sh --latest       # 全部升到最新版
./update-plugins.sh dsh-ops@0.5.0  # 指定插件
```

```bat
update-plugins.cmd --latest
```

它用**包内 node + pnpm** 重新解析并下载，写回 `registry/`（tarball、store、元数据缓存、
`plugins.json`），装好的插件随后在界面里就能直接更新；全程只改包内文件。

## 六、数据、清空、带走

```
home/
└── data/
    ├── profiles/            会话与每个 Profile 的插件配置
    ├── electron-user-data/  界面缓存、窗口状态
    └── logs/                运行日志
```

交给别人 / 换电脑前：

```sh
./DSH-NEXT-reset.sh --yes      # Linux
```

```bat
DSH-NEXT-reset.cmd --yes       :: Windows
```

只删 `home/`（会话、凭据、缓存、日志），程序、运行时、插件都保留，
重新启动就是一台全新机器。

想连配置一起带走就别 reset，直接压缩整个文件夹——记得里面有你的 API Key。
升级版本时，把旧包的 `home/` 拷到新包的同位置即可保留数据。

## 七、出问题看这里

| 现象 | 怎么办 |
| --- | --- |
| 双击没反应 / 窗口一闪而过 | 从命令行启动（Windows 在地址栏输入 `cmd` 回车后执行 `DSH-NEXT.cmd`；Linux 直接 `./DSH-NEXT.sh`），会打印真实报错 |
| 提示权限不足 / 无法写入 | 包被放在只读或用管理员权限才能写的目录，换到用户目录 |
| 装完插件没生效 | 退出并重新启动 |
| 想恢复出厂 | `DSH-NEXT-reset.*`，或直接删掉 `home/` |
| Windows 报 SmartScreen | 「更多信息 → 仍要运行」 |
| 下载后校验不通过 | 重新下载，多半是网络中断导致文件损坏 |

日志在 `home/data/logs/`，反馈问题时一并附上最有用。
完整版说明（含下载、校验、常见问题）见仓库的 `docs/portable-guide.md`。

## 八、校验下载完整性

发布页附 `SHA256SUMS.txt` 与校验脚本，放在同一目录执行：

```sh
./verify-download.sh          # Linux / macOS
```

```bat
verify-download.cmd           :: Windows
```

看到 `通过 <文件名>` 即完整；`不匹配` 请重新下载。只下载了其中一个包也没关系，
脚本会跳过没下载的文件。