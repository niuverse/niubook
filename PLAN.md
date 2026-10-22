# Niubook 规划：书库架构与第 1 本书集成

> 状态：已执行 · 2026-10-22
> 目标仓库：`git@github.com:niuverse/niubook.git`（public，Pages 已启用）
>
> 落地结果与本文的差异记录在文末「执行记录」。架构决策保留原文，便于回看权衡。

## 0. 一页结论

把 `niubook` 做成**一个可复现的 AI 书库（monorepo）**，而不是一堆 PDF：

- `books/<slug>/` 一书一目录，独立可编译；`toolchain/` 放统一版式、固定版本的 Typst 与离线依赖。
- 每本书用 `book.toml` 描述元数据，用 `PROVENANCE.md` 记录"谁、用什么流水线、在哪一天生成/审校"。
- `just build` 出 PDF，`just check` 跑质量门禁，`just catalog` 生成书库索引。
- 第 1 本书《具身递归自我改进》**原样导入、零内容改动**，先让基线与构建变绿，再做系列化重构。

已实测：该 zip 用 Typst 0.13.1 可在 4.6 秒内编译为 **106 页 A4 PDF，0 警告、0 未解析引用**。这是可以冻结的基线。

## 1. 现状核查（已实测，非估算）

| 项目 | 实测值 |
| --- | --- |
| 源包 | `/data/Downloads/具身递归自我改进-typst源码.zip`，204 KB |
| 源包 sha256 | `b9475a270f972e7e85a1af02c8427d4c5e70e1c14a01af136612084bef01cbb2` |
| 内容 | 25 个文件 / 457 KB 源码；17 章 + 前言 + 附录 A/B/C |
| 规模 | 106 页 A4；章节正文 2,812 行；104 节；37 个图表块；22 幅 CeTZ 矢量图；52 个编号公式 |
| 文献 | 327 条 BibTeX，1,007 处引用，其中 **24 条 `UNVERIFIED`** |
| 工具链 | Typst 0.13.1 + `@preview/cetz:0.3.4` + `oxifmt:0.2.1`；全量编译 4.6 s |
| 字体 | 拉丁/数学：New Computer Modern（Typst 内置）；中文：Noto Serif/Sans CJK SC（系统） |
| 导入时基线指纹 | `pdftotext -layout` 后 sha256 = `27185eec3d8f53e966f484a726277ce5ca3605ed90e7950b0e424fa560a3ba90`（v1.0.1 字形修复后为 `b8ff45df…`） |

结构干净：无重复 label、无 TODO/占位符、0 编译警告。问题集中在三处：

1. 书名/作者在 `main.typ`、`template.typ`、封面里**硬编码了 3 次**，无法复用；
2. 24 条文献待核实，缺少可追踪的审校台账；
3. 没有任何生成溯源信息（模型、日期、章节责任人），与"AI 生成"的定位不匹配。

## 2. 目标与设计原则

1. **一书一目录，独立可编译**：`typst compile books/x/main.typ` 即可出书，不依赖根目录状态。
2. **单一事实源**：元数据只写在 `book.toml`，Typst 侧由生成的 `_meta.typ` 消费，禁止三处手改。
3. **可复现**：Typst 版本 + sha256 锁定，CeTZ 依赖 vendor 进仓库，字体缺失时 `just doctor` 明确报错；构建不依赖网络。
4. **溯源优先**：AI 生成的书必须能回答"哪一章、哪天、什么流水线、谁审过"。不可考的信息如实标注"不可考"，不编造。
5. **门禁先于发布**：`check` 绿才允许 `build`/`release`；基线一旦冻结，用**文本指纹**而非肉眼做回归。
6. **内容留在 Typst**：不转 Markdown/Quarto。CeTZ 矢量图、定理环境、按章编号、双栏表格在转换中会不可逆损失。

## 3. 目标仓库结构

```text
niubook/
├─ README.md                  # 书库简介 + 快速开始
├─ AGENTS.md                  # 给 AI 协作者的仓库契约（构建/门禁/写作规范入口）
├─ justfile                   # bootstrap / build / check / catalog / new / release
├─ PLAN.md                    # 本文件（落地后移入 docs/）
├─ .gitignore                 # dist/ .tools/ .build/
├─ docs/
│  ├─ BOOK-CONTRACT.md        # 一本书必须满足的文件与元数据
│  ├─ AUTHORING.md            # 系列级写作规范（由第 1 本书的版本泛化）
│  └─ PRODUCTION.md           # AI 生产线：brief → 章节 → 集成 → 审校 → 发布
├─ toolchain/
│  ├─ versions.toml           # typst 0.13.1 + tarball sha256
│  ├─ typst/
│  │  ├─ base.typ             # 系列统一版式（从第 1 本书 template.typ 抽出）
│  │  └─ components.typ       # 定理环境 / keybox / 图框 / 数学简写
│  ├─ vendor/preview/         # cetz 0.3.4 + oxifmt 0.2.1（离线构建）
│  └─ python/validate_bib.py  # 从第 1 本书上收
├─ books/
│  ├─ _template/              # `just new` 的脚手架（下划线前缀，不进 catalog）
│  └─ embodied-rsi/
│     ├─ book.toml
│     ├─ PROVENANCE.md        # 生成溯源（含"不可考"项）
│     ├─ REVIEW.md            # 待办：24 条待核实文献等
│     ├─ main.typ
│     ├─ _meta.typ            # 由 book.toml 生成，提交入库，check 校验同步
│     ├─ template.typ         # P1 原样；P2 收敛为 ≤40 行主题配置
│     ├─ chapters/            # preface + ch01..ch17 + appendix
│     ├─ references.bib
│     ├─ bibkeys.txt          # 文献分配清单（写作时防止虚构引用的关键工件）
│     └─ assets/
├─ catalog/
│  └─ books.json              # 由 book.toml + 构建统计生成
├─ scripts/                   # 标准库 Python，不引入运行时依赖
│  ├─ bootstrap.py            # 下载并校验固定版本 Typst
│  ├─ gen_meta.py             # book.toml → _meta.typ
│  ├─ check.py                # G0–G6 门禁
│  ├─ catalog.py              # 扫描 books/ → catalog/books.json
│  └─ audit_cites.py          # arXiv / Crossref 文献核验（联网，独立命令）
└─ dist/                      # 构建产物，git 忽略
   ├─ embodied-rsi/embodied-rsi-2026.10.pdf
   └─ books.json
```

Phase 1 只落地其中最小子集（`books/` + `toolchain/` + `justfile` + `scripts/bootstrap.py`），其余随 Phase 2/3 增量加入。

## 4. 一本书的契约

### 4.1 必需文件

| 文件 | 作用 | 缺失后果 |
| --- | --- | --- |
| `book.toml` | 元数据唯一事实源 | 无法进 catalog / 无法生成 `_meta.typ` |
| `main.typ` | 入口，含封面、目录、include 顺序 | 无法构建 |
| `chapters/` | 章节源文件 | — |
| `references.bib` | 文献库 | 引用无法渲染 |
| `PROVENANCE.md` | 生成与审校记录 | `check` 失败（AI 书的硬要求） |
| `REVIEW.md` | 未决问题台账 | `check` 警告 |

### 4.2 `book.toml` 示例

```toml
[book]
slug = "embodied-rsi"          # ASCII，目录名与 URL 用
order = 1                       # 系列内排序
title = "具身递归自我改进"
subtitle = "理论、系统与实践"
title_en = "Embodied Recursive Self-Improvement: Theory, Systems, and Practice"
series = "Niubook"
language = "zh-CN"
version = "0.1.0"               # 语义化版本
edition = "2026.10"             # 内容版次（知识截点）
status = "draft"                # draft | review | stable | archived
audience = "机器人与 AI 方向研究生、研究人员、资深工程师"
knowledge_cutoff = "2026-10"

[build]
engine = "typst"
typst = "0.13.1"
main = "main.typ"

[provenance]
origin = "zip:具身递归自我改进-typst源码.zip"
origin_sha256 = "b9475a270f972e7e85a1af02c8427d4c5e70e1c14a01af136612084bef01cbb2"
imported_at = "2026-10-22"
pipeline = "R1–R7 研究简报 → 17 章并行写作 → BibTeX 合并去重 → 集成"
```

### 4.3 溯源记录（`PROVENANCE.md`）

AI 生成的书，溯源不是仪式，而是可审计性的一部分。建议固定四段：

1. **来源**：原始 zip 路径、sha256、导入日期、是否改动内容；
2. **流水线**：简报数量、章节分配方式、合并/去重步骤、使用模型（不可考就写不可考）；
3. **审校**：已做/未做的检查，24 条 UNVERIFIED 的处置状态；
4. **已知局限**：知识截点、未同行评审的引用、立场性内容。

第 1 本书的溯源可以确定：`references.bib` 头部写明"由 R1–R7 研究简报合并"，`AUTHORING.md` 面向"所有章节 writer"——**这套流水线本来就存在，只是散落在 zip 里**。Niubook 要做的是把它固化下来。

## 5. 分阶段实施

### Phase 0 · 决策（0.5 h）

确认第 9 节的四个选择。默认按推荐项执行。

### Phase 1 · 导入第 1 本书，冻结基线（0.5 天）

**步骤**

1. 建骨架：`README.md`、`AGENTS.md`、`justfile`、`.gitignore`。
2. 工具链落地：`scripts/bootstrap.py` 下载 Typst 0.13.1 到 `.tools/`，按 sha256 `7d214bfe…` 校验；`toolchain/vendor/` 放入 cetz 0.3.4 + oxifmt 0.2.1（共约 452 KB，附 LICENSE 与 `THIRD_PARTY.md`）。
3. 导入：`unzip` 到临时目录，把 `typst/` **这一层去掉**，整体落到 `books/embodied-rsi/`；`Downloads` 里的原包不动。
4. 登记：写 `book.toml`、`PROVENANCE.md`、`REVIEW.md`（24 条 UNVERIFIED 逐条列成待办）。此阶段**只登记，不改正文**，`main.typ` 仍用硬编码标题。
5. `justfile` 三条命令：

```make
build book="embodied-rsi":
    .tools/typst compile --package-path toolchain/vendor \
      books/{{book}}/main.typ dist/{{book}}/{{book}}-2026.10.pdf

check book="embodied-rsi":
    python3 scripts/check.py books/{{book}}

text book="embodied-rsi":
    pdftotext -layout dist/{{book}}/{{book}}-2026.10.pdf - | sha256sum
```

**验收（全部可自动判定）**

- [ ] `just build` 产出 PDF，`pdfinfo` 显示 `Pages: 106`
- [ ] `just text` 输出 `27185eec3d8f53e966f484a726277ce5ca3605ed90e7950b0e424fa560a3ba90`
- [ ] 编译 stderr 为空（0 警告）
- [ ] `validate_bib.py` 通过：327 条、24 条 UNVERIFIED
- [ ] 断网可构建（`--package-path` 指向 vendor）
- [ ] 首次提交 + 标签 `book/embodied-rsi/v0.1.0-import`

> 这一步的价值：先证明"搬进来没搬坏"，之后所有重构都有可回滚的对照指纹。

### Phase 2 · 系列化（1 天）

1. **抽版式**：`template.typ` 中的计数器、配色、标题体系、定理环境拆到 `toolchain/typst/base.typ` + `components.typ`；`base.typ` 接受 `meta` 参数（书名、副书名、作者、页眉短名）。
2. **去硬编码**：`scripts/gen_meta.py` 从 `book.toml` 生成 `_meta.typ`；`main.typ` 改为 `#show: book-style.with(meta: meta)`。`_meta.typ` 提交入库保证裸 `typst compile` 可用，`check` 校验"重新生成后无 diff"。
3. **主题覆盖**：每本书保留 `theme.typ`（配色/封面留白/字体），默认继承系列样式；第 1 本书先零覆盖，保证视觉不变。
4. **脚手架**：`just new <slug>` 从 `books/_template/` 生成可编译空壳 + `book.toml` + 溯源模板。
5. **索引**：`just catalog` 扫描所有 `book.toml` 与构建统计，生成 `catalog/books.json`（slug、标题、状态、版本、页数、文献数、PDF 路径）。

**验收**

- [ ] 第 1 本书文本指纹不变、页数不变（版式重构的硬指标）
- [ ] `template.typ` ≤ 40 行
- [ ] `just new demo` 生成的书 5 秒内可编译；验收后删除
- [ ] 手改 `book.toml` 标题后 `just check` 能报出 `_meta.typ` 失同步

### Phase 3 · 质量门禁与文献审计（1–2 天）

实现 `scripts/check.py`（标准库，无依赖）：

| 门禁 | 检查内容 | 失败条件 |
| --- | --- | --- |
| G0 元数据 | `book.toml` 必填字段、slug 唯一、`order` 不重复 | 缺字段/冲突 |
| G1 结构 | `ch01..chNN` 连续、`main.typ` include 齐全、每章首行 import、每章恰好一个一级标题 | 断号/漏 include |
| G2 构建 | 固定版本编译；stderr 含 warning 即失败 | 编译错误/警告/未解析引用 |
| G3 文献 | `validate_bib` 通过；每个 `@key` 可解析；无"孤儿条目"；UNVERIFIED 数不得增长 | 坏 key/新增待核实 |
| G4 内容卫生 | `TODO`/`待补`/占位图；重复 label；CeTZ 画布宽度 > 15cm；章节字数偏离预算 ±40% | 命中任一 |
| G5 溯源 | `PROVENANCE.md` 存在且 sha256 与 `book.toml` 一致；`REVIEW.md` 条目未超期 | 缺失/不一致 |
| G6 索引 | `catalog/books.json` 与仓库状态一致 | 漂移 |

配套 `just audit-cites`（联网，独立于 `check`）：对含 arXiv/DOI 的条目调用 arXiv Export API / Crossref，比对标题相似度，产出 `reports/citations.md`；24 条 UNVERIFIED 逐条转为"已确认 / 已修正 / 无法确认（保留标注）"。这条命令直接决定这本书能不能从 `draft` 升到 `review`。

### Phase 4 · AI 生产线（2–3 天）

把第 1 本书里隐含的流水线显式化，形成新书可复用的四层：

```text
briefs/            series-brief.md → book-brief.md → chapter-briefs/chNN.md
outline.yml        章标题 / 字数预算 / 图数与要点 / 依赖章 / 分配的 bib key
prompts/           chapter-writer.md, integrator.md, fact-review.md, style-review.md
reports/           citations.md, consistency.md, gates.json
```

写作层的关键约束（沿用第 1 本书已验证的做法）：

- **文献预分配**：写作前把 key 清单（`bibkeys.txt`）发给每个章节 agent，只允许引用清单内条目；需要新增必须带 arXiv/DOI 申报，由主编统一入库。这一条几乎消灭了 LLM 编造引用。
- **符号表先行**：附录 A 的符号表在写作前定稿，作为各章共享输入；集成阶段用脚本核对同名记号是否漂移。
- **证据分级**：`【已有成果】/【本书推断】/【本书提出】` 三档，审校时抽样核对。
- **并行 + 串行**：章节可并行起草；集成、术语统一、跨章引用必须串行，由单一 agent 完成。

第 2 本书用来验证契约：建议从第 1 本书第 15 章（工程实践）扩展成《Embodied RSI 工程手册》，或另起一个主题。**在第二本书跑通之前，不要急着写第三本**——一本书的架构是猜测，两本书才是证据。

### Phase 5 · 发布（可选，0.5 天）

- GitHub Actions：`check` + `build` + 上传 PDF 到 Release（runner 需 `apt install fonts-noto-cjk`）。
- GitHub Pages：`catalog/books.json` 渲染成书库首页，链到 PDF。
- HTML 阅读版暂缓：Typst 0.13 的 HTML 导出仍是实验特性，106 页数学书风险高，PDF 是当前正确形态。

## 6. 里程碑与工作量

| 阶段 | 产出 | 估时 | 阻塞点 |
| --- | --- | --- | --- |
| P0 | 四个决策 | 0.5 h | 需要你拍板 |
| P1 | 第 1 本书入库、106 页基线可复现 | 0.5 天 | 无 |
| P2 | 统一版式、`just new`、书库索引 | 1 天 | 版式重构需视觉回归 |
| P3 | 门禁 + 文献审计报告 | 1–2 天 | 联网核验 24 条 |
| P4 | 生产线固化 + 第 2 本书试跑 | 2–3 天 | 选题 |
| P5 | CI + Pages | 0.5 天 | 仓库公开性 |

## 7. 第 1 本书的已知问题与处置

| 问题 | 影响 | 处置 |
| --- | --- | --- |
| 24 条 `UNVERIFIED` 文献 | 不能宣称 `stable` | P3 逐条核验，`REVIEW.md` 跟踪 |
| 书名硬编码 3 处 | 无法模板化 | P2 由 `book.toml` 生成 |
| 无生成溯源 | 与"AI 书库"定位不符 | P1 补 `PROVENANCE.md`，P4 自动化 |
| 拉丁字体依赖 Typst 内置 NewCM | 升级大版本可能变版式 | 锁定 0.13.1，升级需过文本指纹 |
| 中文依赖系统 Noto CJK | CI/他机可能缺字 | `just doctor` 检查 + CI 装字体 |
| 附录 B 提到"在线仓库" | 目前尚不存在 | P1 后即成事实，无需改文 |
| 封面无 ISBN/版次信息 | 正式出版不足 | 保持"学术讲义"定位，暂不处理 |

## 8. 风险与取舍

- **Monorepo vs 一书一仓**：10 本以内 monorepo 明显更省事（共享版式与门禁）；超过后可用 `git subtree split` 拆出，目录即边界。推荐 monorepo。
- **统一版式 vs 每书个性**：默认继承 `base.typ`，允许 `theme.typ` 覆盖配色与封面；不为个性复制整份模板。
- **PDF 是否入库**：不入库（1.8 MB/版，且二进制 diff 无意义），走 Release 附件；`dist/` 忽略。
- **中文目录名**：仓库内一律 ASCII slug，中文只出现在元数据与排版里。
- **内容修改边界**：P1 不做任何正文编辑。发现的问题只登记，不改稿——否则基线回归失去意义。

## 9. 已拍板的四件事

1. **仓库形态**：monorepo（已执行）。
2. **第 1 本书发布级别**：直接发布 `stable` v1.0.0；24 条待核文献如实公开，不阻塞发布。
3. **许可证**：内容 `CC BY-NC-SA 4.0`，代码 `MIT`；AI 生成声明写入 `NOTICE`、
   `PROVENANCE.md` 与站点。依据见 `docs/LICENSING.md`。
4. **执行范围**：P1–P3 + 站点 + Pages 全部落地；第 2 本书的生产线待选题。

## 10. 执行记录（与本文的差异）

已完成：

- `books/embodied-rsi/` 原样导入，106 页 / 导入时文本指纹
  `27185eec…` 与导入前完全一致；v1.0.1 字形修复后为 `b8ff45df…`，页数不变；
- 版式抽到 `toolchain/typst/{tokens,components,base}.typ`，`template.typ` 缩到 5 行；
- `book.toml → _meta.typ` 生成与同步门禁；G0–G6 门禁全部可执行；
- `catalog/books.json`、mdBook 站点与 `dist/site` 构建；
- GitHub Actions：PR 跑 CI，`main` 推送到 Pages；
- 许可与 AI 声明：`LICENSE` / `LICENSE-CODE` / `NOTICE` / `docs/LICENSING.md`。

与本文的差异：

| 计划 | 实际 | 原因 |
| --- | --- | --- |
| 独立 Python 包 `src/niubook` | `scripts/` 标准库脚本 | 依赖为零，`just` 已足够；变大再包化 |
| Typst HTML 导出 | mdBook 站点 + PDF 直链 | 0.13 的 HTML 导出报错（`set page` 不允许），且 CeTZ/数学会失真 |
| PDF 不入库（本文已建议） | 采纳 | CI 重建并部署，Pages 提供稳定下载链接 |
| `just new` 脚手架 | 暂缓，README/AGENTS 给出复制步骤 | 第 2 本书开写时再做，避免凭空设计 |
| 引用审计自动改书目 | 只出报告，不自动改 | 标题匹配不等于作者/venue 核实，需人工判断 |

未完成、已登记：

- 24 条 `UNVERIFIED` 文献的逐条人工核验（`REVIEW.md`）；
- PDF 内页版权/AI 标识页（下一版，会改变分页基线）；
- 第 2 本书（生产线的真正验收）。

后续变更：2026-10-22 站点从自绘 HTML 迁移到 mdBook 0.5.3（书目、书页、搜索、打印、404 由 mdBook 生成），PDF 仍为唯一下载格式。

