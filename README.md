# Niubook

AI 生成书稿的合集。每本书以 Typst 源码维护，经人工统稿与引用核验，
由固定版本的工具链可复现地编译为 PDF。

阅读站点：<https://niuverse.github.io/niubook/>

## 书目

| # | 书名 | 页数 | 文献 | 版次 | 状态 |
| --- | --- | ---: | ---: | --- | --- |
| 01 | [具身递归自我改进：理论、系统与实践](books/embodied-rsi/) | 106 | 327 | 2026.10 | stable |

## 快速开始

```sh
just bootstrap     # 下载并校验 Typst 0.13.1 与 mdBook 0.5.3
just doctor        # 检查字体、CeTZ 与 poppler
just build         # 编译第 1 本书 → dist/books/embodied-rsi/*.pdf
just check         # 质量门禁：元数据 / 结构 / 构建 / 引用 / 卫生 / 溯源
just site          # 生成 mdBook 站点 → dist/site
just serve         # http://localhost:8000
```

只依赖 Python 3.12 标准库、Typst、mdBook、`poppler-utils` 与 `fonts-noto-cjk`。
Typst 包已 vendor；两个工具链由 `just bootstrap` 按 sha256 固定版本安装。

## 仓库结构

```text
books/<slug>/            一本书：book.toml + Typst 源码 + 溯源与审校台账
toolchain/
  versions.toml          Typst / mdBook 版本与 sha256（唯一版本事实源）
  typst/                 系列版式：tokens / components / base
  vendor/                CeTZ 0.3.4 + oxifmt 0.2.1（离线构建）
  python/                BibTeX 校验器
scripts/                 标准库 Python：bootstrap / build / check / catalog / site
site/book.toml           mdBook 配置（默认主题）
catalog/books.json       由 book.toml 与源文件生成的机读书目
docs/                    书籍契约、写作规范、生产流程、许可调研
dist/                    构建产物（git 忽略）
```

## 一本书由什么构成

```text
books/embodied-rsi/
├─ book.toml          元数据唯一事实源（标题、版次、许可、统计、溯源）
├─ _meta.typ          由 book.toml 生成；提交入库，check 校验是否失同步
├─ main.typ           封面 → 目录 → 前言 → 17 章 → 附录 → 参考文献
├─ template.typ       本书主题入口，导入 toolchain/typst/base.typ
├─ chapters/          前言、ch01–ch17、附录 A/B/C
├─ references.bib     327 条 BibTeX
├─ bibkeys.txt        写作前分配的文献 key 清单
├─ AUTHORING.md       本书的写作细则（系列规范见 docs/AUTHORING.md）
├─ PROVENANCE.md      生成溯源：来源哈希、流水线、章节台账、不可考项
└─ REVIEW.md          审校台账：24 条待核文献与已知问题
```

## 质量门禁

`just check` 逐项执行，任何一项失败都会阻止发布：

| 门禁 | 检查 |
| --- | --- |
| G0 元数据 | `book.toml` 必填字段、slug 与目录一致、许可与统计 |
| G1 结构 | 章节连续、`main.typ` 恰好 include 一次、每章一个一级标题 |
| G2 构建 | 固定版本 Typst 编译，**零警告**，页数等于 `stats.pages` |
| G3 引用 | BibTeX 结构合法、每个 `@key` 可解析、待核数量不超预算 |
| G4 卫生 | 无 TODO/待补、无重复 label |
| G5 溯源 | 原始来源 sha256 已记录、`_meta.typ` 与 `book.toml` 同步 |
| G6 索引 | `catalog/books.json` 与仓库一致 |

`stats.pages` 是分页基线。任何改动导致页数变化，都必须是有意识的决定，
并同步更新基线——这样版式重构不会悄悄改掉一本书。

## PDF 为什么不在 git 里

PDF 是**构建产物**，不是事实源：

- 每版 1.8 MB，二进制 diff 没有审阅价值，只会让仓库随版本膨胀；
- 源码 + 固定工具链已经能逐字节复现内容（文本指纹见
  `books/embodied-rsi/PROVENANCE.md`）；
- CI 在每次推送后重新编译，并把 PDF 随站点部署到 GitHub Pages，
  下载链接始终指向最新构建。

因此：需要离线副本时运行 `just build`；公开下载走
`https://niuverse.github.io/niubook/books/embodied-rsi/embodied-rsi.pdf`。
如果将来需要长期归档某个版本，再在打 tag 时把 PDF 附到 GitHub Release 即可。

## 新增一本书

1. 复制 `books/embodied-rsi/` 为 `books/<slug>/`，改 `book.toml` 的 slug、标题与统计；
2. 清空 `chapters/` 写入新稿，保留 `template.typ` 与文件头 import；
3. `just meta <slug>` 生成 `_meta.typ`；
4. 补写 `PROVENANCE.md` 与 `REVIEW.md`（门禁会强制）；
5. `just catalog && just check-all`。

## 文档

- [书籍契约](docs/BOOK-CONTRACT.md)：一本书必须满足的文件、元数据与门禁。
- [写作规范](docs/AUTHORING.md)：章节、数学、定理、引用与风格。
- [图形规范](docs/FIGURES.md)：CeTZ 画布、盒子、箭头、标签与验收清单。
- [生产流程](docs/PRODUCTION.md)：从简报、并行写作到审校与发布。
- [许可调研](docs/LICENSING.md)：AI 生成内容的版权与许可证选择依据。

## 许可与 AI 声明

- 书籍内容：**CC BY-NC-SA 4.0**，见 [`LICENSE`](LICENSE)；
- 构建代码与 Typst 模板：**MIT**，见 [`LICENSE-CODE`](LICENSE-CODE)；
- 权利、第三方材料与商业授权：见 [`NOTICE`](NOTICE)；
- 许可选择的调研依据：见 [`docs/LICENSING.md`](docs/LICENSING.md)。

本书初稿由 **Kimi K3** 生成；人类作者完成选题、大纲、多轮编辑、引用核验与统稿。
完全由 AI 生成的部分可能不受著作权保护，仓库与站点均保留 AI 生成标识。
