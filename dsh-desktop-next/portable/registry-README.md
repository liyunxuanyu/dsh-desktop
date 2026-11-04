# 离线插件仓库

预装插件的 npm 包与 pnpm store 都在这里，断网也能装/重装插件。

- `store/`：pnpm 内容寻址存储，打包时由 `pnpm store add` 写入，含 `dsh-ops@0.4.4`、
  `@liustack/modsearch@5.10.11` 及其运行依赖（`commander@15`、`undici@7`）。
- `*.tgz`：同样的包，可直接 `pnpm add ./registry/<file>.tgz`。

启动器把 `NPM_CONFIG_STORE_DIR`、`NPM_CONFIG_CACHE`、`NPM_CONFIG_USERCONFIG` 指到包内，
界面里装插件默认走本地 store（`prefer-offline`）。需要新插件而无网络时，先在联网机器执行
`pnpm store add <包名> --store-dir <包>/registry/store`，再把整个目录拷回来。
