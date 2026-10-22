# 书籍契约

任何进入 `books/` 的书都必须满足本文件。门禁 `scripts/check.py` 是它的可执行版本。

## 1. 必需文件

| 文件 | 作用 | 缺失 |
| --- | --- | --- |
| `book.toml` | 元数据唯一事实源 | 无法进目录、无法生成 `_meta.typ` |
| `main.typ` | 入口：封面、目录、include 顺序、参考文献 | 无法构建 |
| `chapters/` | 前言、`ch01..chNN.typ`、`appendix.typ` | 结构门禁失败 |
| `references.bib` | 文献库 | 引用无法渲染 |
| `PROVENANCE.md` | 生成与审校溯源 | G5 失败 |
| `REVIEW.md` | 未决问题台账 | G5 失败 |

推荐但非必需：`bibkeys.txt`（文献分配清单）、`AUTHORING.md`（本书写作细则）、
`assets/`（图片等静态资源）。

## 2. `book.toml`

```toml
schema = 1

[book]
slug = "embodied-rsi"        # 必须等于目录名，ASCII
order = 1                     # 系列内排序，唯一
title = "具身递归自我改进"
subtitle = "理论、系统与实践"
title_en = "..."
author = "Embodied RSI Research Group"
series = "Niubook"
short_title = "具身递归自我改进"   # 页眉用
language = "zh-CN"
year = 2026
edition = "2026.10"           # 内容版次
version = "1.0.4"             # 语义化版本
status = "stable"             # draft | review | stable | archived
audience = "..."
knowledge_cutoff = "2026-10"
cover_note = "学术讲义 · 2026"
tags = ["..."]
abstract = "..."              # 站点与 catalog 使用

[build]
engine = "typst"
typst = "0.15.1"
main = "main.typ"

[stats]                       # 与源文件核对；pages 是分页基线
pages = 106
chapters = 17
sections = 104
references = 327
unverified = 24

[quality]
max_unverified = 24           # 只许降，不许升

[license]
spdx = "CC-BY-NC-SA-4.0"
name = "..."
url = "..."
code = "MIT"

[provenance]
origin = "zip:..."
origin_sha256 = "<64 hex>"
imported_at = "2026-10-22"
generator = "Kimi K3"
pipeline = "..."
```

字段会经 `scripts/gen_meta.py` 变成 `_meta.typ` 的 Typst 字典。
`_meta.typ` 提交入库，保证裸 `typst compile` 可用；`check` 会重新生成并比对。

## 3. 状态语义

| 状态 | 含义 |
| --- | --- |
| `draft` | 结构可用，内容仍在写；允许占位符以外的缺口 |
| `review` | 内容冻结，正在核引用/清权/审读 |
| `stable` | 内容冻结并已发布；不随版本漂移。**不代表引用已全部核实** |
| `archived` | 不再更新，仅保留可构建性 |

引用真实性由 `REVIEW.md` 与 `stats.unverified` 单独表达，不与 `status` 混为一谈。

## 4. 分页基线与指纹

`stats.pages` 是硬基线：G2 要求编译页数与之相等。版式或正文改动导致页数变化时：

1. 确认变化是有意的；
2. 更新 `stats.pages`；
3. 在 `PROVENANCE.md` 记录变更；
4. 重新记录文本指纹（`just text <slug>`）。

文本指纹用于判断"内容是否被意外改动"：版式重构不应改变 `pdftotext -layout`
的输出哈希。第 1 本书的基线是
`d9dece5cc397a1404c83f2e535e6308e1270747b0c4ed32f1568ec8f4c63897c`（v1.0.4）。

## 5. 门禁

| 门禁 | 失败条件 |
| --- | --- |
| G0 元数据 | 必填字段缺失、slug 与目录不符、status 非法、无许可、无 `stats.pages` |
| G1 结构 | 章节断号、include 缺失/重复、章节首行无 import、一级标题不是恰好一个 |
| G2 构建 | 编译失败、出现任何 warning、页数偏离基线 |
| G3 引用 | bib 结构损坏、正文引用无对应条目、待核数量超过 `max_unverified`、统计不符 |
| G4 卫生 | `TODO`/`FIXME`/`XXX`/`待补` 等占位、重复 label |
| G5 溯源 | 缺 `PROVENANCE.md`/`REVIEW.md`、sha256 未记录、`_meta.typ` 失同步 |
| G6 索引 | `catalog/books.json` 与源文件不一致 |

## 6. 版式与主题

- 系列版式在 `toolchain/typst/base.typ`，视觉令牌在 `tokens.typ`，
  组件在 `components.typ`。
- 一本书的 `template.typ` 只做导入与覆盖：

```typst
#import "../../toolchain/typst/base.typ": *
#let accent = rgb("#7a3b2e")   // 可选：本书主色
```

- 不要在书目录里复制整份模板；那会让系列修复无法下发。
- `main.typ` 必须 `#import "_meta.typ": meta` 并
  `#show: book-style.with(meta: meta)`。

## 7. 构建产物

PDF 不入库。CI 从源码重建并部署到 Pages；本地构建落在 `dist/`（git 忽略）。
一本书的下载路径固定为 `books/<slug>/<slug>.pdf`。
