# AGENTS.md

面向在此仓库工作的 AI 协作者。人类读者可把它当作操作手册。

## 仓库是什么

`niubook` 是 AI 生成书稿的 monorepo。一本书 = `books/<slug>/` 下的
Typst 源码 + `book.toml` + 溯源与审校台账。构建、门禁与站点都在根目录脚本里。

## 开始之前

1. 读 [`docs/BOOK-CONTRACT.md`](docs/BOOK-CONTRACT.md)：一本书必须满足什么。
2. 读目标书的 `book.toml`、`PROVENANCE.md`、`AUTHORING.md`。
3. 读 [`docs/AUTHORING.md`](docs/AUTHORING.md)：系列写作规范。

## 常用命令

```sh
just bootstrap     # 安装固定版本 Typst 与 mdBook
just doctor        # 字体 / 依赖 / vendor 检查
just build <slug>  # 编译一本（默认 embodied-rsi）
just check <slug>  # 单本门禁
just check-all     # 全部门禁 + 目录一致性
just meta <slug>   # 由 book.toml 重新生成 _meta.typ
just catalog       # 重新生成 catalog/books.json
just site          # 生成 dist/site
```

提交前至少运行 `just check-all`。没有通过的构建不允许提交发布相关改动。

## 硬规则

- **不要手改 `_meta.typ`**。改 `book.toml`，然后 `just meta <slug>`。
- **不要虚构文献**。只引用 `bibkeys.txt` 中已分配的 key；新增必须带
  arXiv ID / DOI 并在章节末以 `% NEWBIB:` 申报。
- **不要提交 `dist/`、`.tools/`**。PDF 由 CI 重建并部署。
- **不要悄悄改分页基线**。正文改动导致页数变化时，同步更新
  `book.toml` 的 `stats.pages`，并在 `PROVENANCE.md` 记一笔。
- **不要在书里删改 AI 标识**。`NOTICE`、README、站点与 `PROVENANCE.md`
  的 AI 声明是发布要求。
- 正文用中文；仓库路径、slug、脚本标识符用 ASCII。
- 脚本只依赖 Python 3.12 标准库；不引入运行时包。
- 模板改动改 `toolchain/typst/`，单本书的个性化放该书的 `template.typ`
  （覆盖 tokens 即可），不要复制整份模板。

## 修改地图

| 想改什么 | 改哪里 |
| --- | --- |
| 书名、版次、许可、统计 | `books/<slug>/book.toml`（然后 `just meta`） |
| 系列配色、字体、页眉版式 | `toolchain/typst/tokens.typ`、`base.typ` |
| 定理环境、要点框、数学简写 | `toolchain/typst/components.typ` |
| 章节正文 | `books/<slug>/chapters/*.typ` |
| 图的布局与箭头 | 对应章节的 `cetz.canvas`；先读 `docs/FIGURES.md` |
| 参考文献 | `books/<slug>/references.bib` + `bibkeys.txt` |
| 门禁规则 | `scripts/check.py` |
| 站点版式 | `site/book.toml`（mdBook 默认主题）；页面内容由 `scripts/site.py` 生成 |
| 发布流程 | `.github/workflows/pages.yml` |

## 新增一本书

1. `books/embodied-rsi/` 为模板复制为 `books/<slug>/`，清空章节；
2. 改 `book.toml`（slug 必须等于目录名，`order` 不得重复）；
3. 写 `chapters/preface.typ` 与 `ch01.typ`，保持首行
   `#import "../template.typ": *`；
4. `just meta <slug>`；
5. 补 `PROVENANCE.md`（含来源 sha256 或"原创"说明）与 `REVIEW.md`；
6. `just catalog && just check-all && just build <slug>`。

## 提交与发布

- 提交信息用「范围: 动作」：`book(embodied-rsi): import v1.0.0`、
  `toolchain: pin typst 0.15.1`、`site: add reader placeholder`。
- 推送 `main` 后，GitHub Actions 会跑门禁、编译、生成站点并部署 Pages。
- 发布版本用 tag 标注：`book/embodied-rsi/v1.0.0`。
- 若 Actions 失败，先看门禁输出；不要用跳过检查的方式"修复"发布。
