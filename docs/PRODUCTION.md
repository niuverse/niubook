# 生产流程：从选题到可下载的书

本文件描述 Niubook 的「AI 生产线」。它把第 1 本书里隐含的做法（研究简报 →
并行章节 → 文献合并 → 统稿）固化成可复用的步骤。

## 0. 产出物

```text
books/<slug>/
├─ briefs/
│  ├─ book-brief.md          这本书要回答什么、不回答什么、读者是谁
│  ├─ outline.yml            章标题 / 字数预算 / 图数 / 依赖章 / 分配的 bib key
│  └─ chNN.md                每章的论点、证据、图、反例、边界
├─ prompts/                  本次使用的提示词快照（可复用、可版本化）
├─ references.bib
├─ bibkeys.txt               写作前分配的 key 清单
├─ chapters/
├─ PROVENANCE.md             生成记录（见 BOOK-CONTRACT）
└─ REVIEW.md                 未决问题
```

`outline.yml` 建议字段：

```yaml
book: embodied-rsi
knowledge_cutoff: 2026-10
chapters:
  - number: 1
    title: 引言
    thesis: ...
    words: 9000
    figures: 2
    depends_on: []
    bib_keys: [zhou2026physicalrsi, zhang2025dgm]
```

## 1. 选题与简报（人工主导）

- 写 `book-brief.md`：一句话论点、目标读者、与已有书/综述的差异、明确不写的范围。
- 把主题拆成 3–7 份研究简报（第 1 本书是 R1–R7）。每份简报只负责一个子领域，
  输出「方法—结果—局限」三列表，而不是文献罗列。
- 人工确认简报的事实密度：如果一份简报只能产出 2000 字，它撑不起一章。

## 2. 大纲与文献分配（人工 + AI）

- 由简报生成 `outline.yml`，人工删掉撑不起论证的章。
- 合并去重 `references.bib`，为每条分配稳定 key，生成 `bibkeys.txt`。
- 把 key 按章分配。**写作阶段只允许引用已分配的 key**——这一条比任何
  "请勿编造引用" 的提示都有效。
- 先定稿符号表（附录 A），它是跨章一致性的锚点。

## 3. 章节起草（并行）

每章一个写作 agent，输入固定为：

1. 该章的 `chNN.md` 简报；
2. `outline.yml` 的本章条目（字数、图数、依赖）；
3. 符号表与 `docs/AUTHORING.md`；
4. 分配给本章的 bib key 清单。

输出必须满足：首行 import、一个一级标题、章末小结 + 要点框、所有图用 CeTZ。
并行写作不追求一次成稿，追求「结构完整、论点可审」。

## 4. 集成（串行，单 agent）

并行写作必然产生术语漂移与重复论证。集成阶段做四件事：

1. 统一术语与符号，核对附录符号表覆盖率；
2. 删除跨章重复的定义，改为前向引用；
3. 合并 `% NEWBIB:` 申报，跑 `just meta` 与文献校验；
4. 调整章序与过渡段，保证 1 → N 的主线可读。

集成必须由单一 agent 完成；多人同时改全书会制造新的不一致。

## 5. 审校（四遍）

| 遍次 | 目标 | 手段 |
| --- | --- | --- |
| 事实 | 引用是否支持论断 | 抽样回原文；`just audit-cites` 核 arXiv/DOI |
| 一致 | 符号、术语、编号 | 脚本查重复 label；人工过符号表 |
| 风格 | 教材口吻、证据分级 | 对照 `docs/AUTHORING.md` |
| 领域 | 判断是否成立 | 人类专家；这一遍不能外包给模型 |

审校结论写进 `REVIEW.md`，不要只留在对话里。

## 6. 发布

```sh
just meta <slug>
just catalog
just check-all
just build <slug>
just site
```

门禁全绿才允许推送。推送后 CI 重新编译并部署 Pages；tag 记录版本
（`book/<slug>/vX.Y.Z`）。

## 7. 溯源

发布前把以下内容写进 `PROVENANCE.md`：

- 来源（zip / 仓库 / 原创）与 sha256；
- 使用的模型与版本、生成日期；
- 简报、章节分配、集成与审校的执行者；
- 不可考项（不要补写猜测）；
- 文本指纹与页数基线。

## 8. 第二本书才是验证

一本书的流程是假设，两本书才是证据。第 2 本书必须复用本文件的步骤，
并把所有「只有第 1 本书才知道」的隐含知识补进 `docs/`。
在第 2 本书跑通之前，不要并行开第三本。
