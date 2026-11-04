# 离线插件仓库（包内 registry/）

预装插件的 npm 包与 pnpm store 都在这里，断网也能装/重装插件。

- `store/`：pnpm 内容寻址存储。注意 **`pnpm store add` 只写入指定的包本身，不写依赖闭包**，
  所以打包时用一次性的 `pnpm add` 把 `dsh-ops`、`@liustack/modsearch` 及其依赖
  （`commander`、`undici`）一起解析进 store；只 `store add` 会在离线安装时报
  `ERR_PNPM_NO_OFFLINE_TARBALL`。
- `*.tgz`：同样的包，可直接 `pnpm add --offline ./registry/<file>.tgz`。

启动器把 `NPM_CONFIG_STORE_DIR`、`NPM_CONFIG_CACHE`、`NPM_CONFIG_USERCONFIG` 指到包内，
界面里装插件默认走本地 store（`prefer-offline`）。要加新插件：把它加进
`dsh-desktop-next/portable-bundles.json` 和 `package.json` 的依赖，重新打包即可，
store 与 registry 会自动跟着更新。
