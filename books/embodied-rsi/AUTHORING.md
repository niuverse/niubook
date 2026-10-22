# 作者规范（所有章节 writer 必读）

## 文件与导入
- 每章一个文件 `chapters/chNN.typ`，第一行：
  `#import "../template.typ": *`
- 章标题用 `= 标题`（level 1），节 `==`（显示为 N.M），小节 `===`。

## 数学
- 行内 `$...$`，行间 `$ ... $`；需要编号引用时加标签 `$...$ <eq:xxx>`，引用 `@eq:xxx`。
- 公式编号自动按章生成 (N.k)。
- 全书统一符号（遵守，勿自创冲突记号）：
  - 状态 $s in cal(S)$，动作 $a in cal(A)$，观测 $o in cal(O)$，转移 $P(s'|s,a)$，奖励 $r(s,a)$，折扣 $gamma in [0,1]$
  - 策略 $pi_theta (a|s)$，参数 $theta$；轨迹 $tau = (s_0,a_0,r_0,...)$；回报 $J(theta) = EE_(tau ~ pi_theta)[sum_t gamma^t r_t]$
  - Harness 记 $cal(H)$，Agent 记 $cal(A)_"llm"$（避免与动作空间冲突时写 $"Agent"$），改进算子 $Phi$，修改 $m$，验证集 $cal(D)_"val"$
  - 期望用 `EE`，概率用 `PP`（模板已定义简写）
- 长推导分行：`$ ... \ ... $`，保持等号对齐。

## 定理环境（模板已提供）
`#definition(title: [..])[...]` `#theorem(title:..)[...]` `#lemma[..]` `#proposition[..]` `#corollary[..]` `#assumption[..]` `#remark[..]` `#example[..]` `#proof[..]` `#keybox(title:[本章要点])[..]`

## 图（CeTZ 矢量图，强制）
- 每章 2–4 幅。统一写法：
```typst
#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // ... 绘制代码
  }),
  caption: [图题],
) <fig:xxx>
```
- 文件顶部加 `#import "@preview/cetz:0.3.4"`。
- 配色只用模板色：accent `#0f5c5c`、accent2 `#8c5a2b`、softbg `#f6f4ef`、softline `#d9d4c8`；节点用圆角矩形+浅色填充+深色描边，箭头用 `mark: (end: ">")`。
- 画布宽度不超过 15cm；字体小（content 里 `text(size: 8pt)`）。
- 禁止装饰性图片；图必须承载信息（架构、数据流、时序、算法）。

## 表格
- `#figure(table(columns: ..., ..), caption: [...])`；表头自动加粗。对比表列名精炼。

## 引用（严禁虚构）
- 只引用分配给你的 BibTeX 片段中列出的 key；如确需新文献，必须真实存在（arXiv/DOI 可核查），并在章节文件末尾用注释 `% NEWBIB: key = 标题, 作者, 年份, arXiv:XXXX.XXXXX` 申报，由主编统一入库。
- 引用写法 `@key` 或 `@key[p. 3]`。

## 时效性（主编强制要求）
- Embodied RSI / Harness 是全新主题：实质分析优先 2025–2026 年工作，尤其 2026 下半年；经典工作（MDP、Gödel machine、MAML、POET 等）只作压缩背景。
- 每章至少一节讨论"最新进展与未解决问题"。

## 风格
- 研究生教材口吻：连贯段落为主，列表为辅；每个概念先直觉后定义再推导。
- 明确区分：【已有成果】（带引用）、【合理推断】（注明"本书推断"）、【原创设计】（注明"本书提出"）。
- 代码块用 ```python 等语言标记。
- 章末：本章小结段落 + `#keybox` 要点框。
