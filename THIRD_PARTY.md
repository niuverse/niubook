# 第三方依赖

构建不联网：Typst 包 vendor 在 `toolchain/vendor/`，Typst 可执行文件由
`scripts/bootstrap.py` 按 `toolchain/versions.toml` 的版本与 sha256 下载。

| 组件 | 版本 | 许可 | 位置 |
| --- | --- | --- | --- |
| [Typst](https://typst.app/) | 0.15.1 | Apache-2.0 | `.tools/typst`（构建时下载，不入库） |
| [CeTZ](https://github.com/cetz-package/cetz) | 0.3.4 | LGPL-3.0-or-later | `toolchain/vendor/preview/cetz/0.3.4/` |
| [oxifmt](https://github.com/PgBiel/oxifmt) | 0.2.1 | MIT-0 | `toolchain/vendor/preview/oxifmt/0.2.1/` |
| [Latin Modern Math](https://www.gust.org.pl/projects/e-foundry/lm-math) | 1.959 | GUST Font License | `site/fonts/latinmodern-math.otf`（随站点发布） |

第三方包保留原始 `LICENSE` 与 `typst.toml`，未做修改。正文中引用的论文与图表
权利归原作者所有，不在本仓库许可范围内，详见 `NOTICE`。

字体：拉丁与数学使用 Typst 内置的 New Computer Modern；中文使用系统的
Noto Serif CJK SC / Noto Sans CJK SC（Linux 上由 `fonts-noto-cjk` 提供）。
