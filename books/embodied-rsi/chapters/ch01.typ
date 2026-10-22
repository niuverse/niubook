#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 引言：从「Who Improves the Robot?」到 Embodied RSI 研究纲领

2026 年 10 月，一篇由三十余家机构联署的立场论文直接发问：*Who Improves the Robot?*——谁在改进机器人@zhou2026physicalrsi。同一周内，EmbodiedEvo@li2026embodiedevo、RSIGym@meng2026rsigym、SEAR@wang2026sear 等系统与基准相继出现，审计 RSI 评估证据的元研究@chen2026auditing 也随之问世。「Embodied RSI」（具身递归自我改进）从修辞后缀变成了自命名的研究纲领。

本章为全书定调：先交代浪潮的两股源流（@sec:motivation），再给出四个核心概念的严格定义（@sec:concepts），随后预告形式化（@sec:formulation），最后划定边界（@sec:boundary）并给出全书地图（@sec:roadmap）。

== 动机：当「造 AI 的 AI」遇上物理世界 <sec:motivation>

2022–2024 年，ReAct@yao2023react、Reflexion@shinn2023reflexion 与 Voyager@wang2023voyager 确立了 LLM 智能体形态：冻结大模型为内核，外裹提示词、工具、记忆与控制流组成的脚手架；脚手架的每一段都是可修改的工件，而修改者最初始终是人。2025–2026 年，修改者的角色开始被系统自身接管：DGM 把「读写自身代码库的智能体」放进开放式进化档案，八十代内把 SWE-bench 成绩从 20.0% 推进到 50.0%@zhang2025dgm；AlphaEvolve 把「LLM + 自动评估器 + 进化档案」推进到数据中心调度与芯片优化@novikov2025alphaevolve；harness 本身也成为可学习、可搜索的对象@harnessengineering2026 @zhang2026selfharness @harnessmdp2026 @karten2026continual。

机器人学习的自动化诉求更为迫切，原因根植于物理数据的特殊性：语言语料以万亿 token 计，而最大的跨本体机器人数据集 Open X-Embodiment 汇集上百家机构之力也只有一百万余条轨迹@oxe2023，相差五至六个数量级，且轨迹不可再生——每一条都必须逐条物理产生。各环节在 2023–2026 年间已被分别做出原型：Eureka 用 LLM 进化搜索奖励函数@ma2024eureka，RoboGen 自动生成任务与场景@wang2024robogen，AutoRT 编排机器人集群采集数据@ahn2024autort，RoboCat 演示权重级自我改进@bousmalis2023robocat，PLD 实现 VLA 自主后训练@xiao2025pld。然而把这条环作为整体审视（第 13 章逐篇审计），结论一致：*各段皆有原型，整环无人闭合*。物理经验如何自动、可靠、可审计地转化为能力的持久提升，且转化机制本身也在改进——这正是 Embodied RSI 要回答的系统级问题。

== 核心概念：Agent、Harness 与自我改进 <sec:concepts>

本书的全部技术论述建立在四个概念之上。先给直觉：*模型*是静态的函数近似器；接上感知输入、工具输出、记忆读写与控制循环，它才成为能持续行动的 *Agent*；那层「接线」的总和就是 *Harness*；系统的修改让自身表现更好，是*自我改进*；「产生修改的机制」本身也被改进，才是*递归*自我改进。

=== Agent 与 Harness：$cal(A)_"llm" = (cal(H), Theta)$

#definition(title: [模型（Model）])[本书中的*模型*记为 $Theta$，指一组可训练参数连同其前向计算图，例如 VLA 策略、世界模型、奖励模型或作为认知内核的 LLM。模型在给定输入—输出接口的意义下是静态的：它不会自发地「记得」上一次交互，也不会自行决定何时被调用。]

#definition(title: [Harness（脚手架）])[记为 $cal(H)$，指包裹在模型之外、使模型得以与环境持续交互的全部非参数化组件的总和：提示词与上下文装配、工具与技能接口、记忆策略、子代理编排、控制流与重试逻辑、验证与回滚门控@harnessengineering2026 @qin2026agenticrobots。]

#definition(title: [Agent])[记为 $cal(A)_"llm" = (cal(H), Theta)$，即 *agent = model + harness*。这与评估实践中区分「模型分数」与「智能体分数」的用法一致——同一模型换一副 harness，在同一基准上可相差数十个百分点；能力声明属于「模型 + 脚手架」整体而非模型本身。]

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let boxstyle = (radius: 0.12, fill: softbg, stroke: 0.9pt + accent)
    // ---- 改进程序 Phi ----
    rect((0.4, 7.6), (9.4, 9.0), fill: softbg, stroke: 0.9pt + accent2, radius: 0.12, name: "phi")
    content((4.9, 8.55), text(size: 8pt, weight: "bold")[改进程序 $Phi$（Adapt / Train / Ver，可更新自身）])
    content((4.9, 7.95), text(size: 7.5pt)[提议修改 $m$、执行训练、调用验证；产出新版本 $(cal(H)', Theta')$])
    // ---- Agent 容器 ----
    rect((0.4, 2.4), (9.4, 7.1), stroke: (dash: "dashed", paint: accent, thickness: 0.9pt), radius: 0.12, name: "agent")
    content((1.55, 6.82), text(size: 8pt, weight: "bold", fill: accent.darken(10%))[Agent $cal(A)_"llm" = (cal(H), Theta)$])
    // Harness
    rect((0.7, 4.6), (9.1, 6.5), ..boxstyle, name: "harness")
    content((4.9, 6.14), text(size: 8pt, weight: "bold")[Harness $cal(H)$：自我改进的*载体*])
    content((4.9, 5.66), text(size: 7.2pt)[提示与上下文装配 · 工具/技能接口 · 记忆策略])
    content((4.9, 5.24), text(size: 7.2pt)[子代理与控制流 · 验证门控])
    content((4.9, 4.82), text(size: 7.2pt)[（以配置与代码形式存在，可被 $Phi$ 直接读写、版本化与回滚）])
    // Model
    rect((0.7, 2.7), (9.1, 4.3), ..boxstyle, name: "model")
    content((4.9, 3.95), text(size: 8pt, weight: "bold")[模型 $Theta$：自我改进的*对象之一*])
    content((4.9, 3.4), text(size: 7.5pt)[VLA 策略权重 · 世界模型 · 奖励/验证模型（经数据与优化器更新）])
    // ---- 环境 ----
    rect((0.4, 0.2), (9.4, 2.0), fill: softbg, stroke: 0.9pt + gray.darken(30%), radius: 0.12, name: "env")
    content((4.9, 1.5), text(size: 8pt, weight: "bold")[环境：物理世界与仿真器])
    content((4.9, 0.95), text(size: 7.5pt)[部分可观测 · 不可逆 · 有磨损与安全成本；仿真提供可重置的「试验场」])
    // ---- 独立评估器 E ----
    rect((10.1, 3.2), (13.3, 6.0), fill: bluebg, stroke: 0.9pt + accent2, radius: 0.12, name: "eval")
    content((11.7, 5.35), text(size: 8pt, weight: "bold")[独立评估器 $E$])
    content((11.7, 4.7), text(size: 7.5pt)[在系统之外])
    content((11.7, 4.25), text(size: 7.5pt)[固定回归集])
    content((11.7, 3.8), text(size: 7.5pt)[防止自指验证])
    // ---- 箭头 ----
    line((4.9, 7.55), (4.9, 7.15), mark: (end: ">"), stroke: 0.9pt + accent2)
    content((5.75, 7.38), text(size: 7.5pt, fill: accent2.darken(10%))[修改 $m$])
    line((2.0, 2.65), (2.0, 2.05), mark: (end: ">"), stroke: 0.9pt + accent)
    content((2.55, 2.37), frame: "rect", fill: white, stroke: none, padding: 0.07, text(size: 7.5pt)[动作 $a$])
    line((7.8, 2.05), (7.8, 2.65), mark: (end: ">"), stroke: 0.9pt + accent)
    content((7.3, 2.37), frame: "rect", fill: white, stroke: none, padding: 0.07, text(size: 7.5pt)[观测 $o$、奖励 $r$])
    line((9.45, 4.7), (10.05, 4.7), mark: (end: ">",), stroke: (dash: "dashed", paint: accent2, thickness: 0.8pt))
    content((9.85, 4.98), text(size: 7.5pt)[证据])
    line((11.7, 6.05), (8.6, 8.0), mark: (end: ">"), stroke: (dash: "dashed", paint: accent2, thickness: 0.8pt))
    content((11.2, 6.6), text(size: 7.5pt, fill: accent2.darken(10%))[放行 / 否决])
  }),
  caption: [Harness 与 Agent / Model / Environment 的分层关系。Harness $cal(H)$ 是模型 $Theta$ 与环境之间的接线总和，与 $Theta$ 共同构成 Agent；改进程序 $Phi$ 作用于 $(cal(H), Theta)$ 整体，而独立评估器 $E$ 在系统之外把关「什么算改进」（四元组形式化见 @sec:formulation）。],
) <fig:harness-layers>

@fig:harness-layers 给出这套分层，三个要点值得记下。其一，Harness 是自我改进最自然的载体：以代码与配置形式存在，可读、可写、可版本化、可回滚@zhang2025dgm @li2026embodiedevo，权重反而是最难安全修改的一层。其二，Harness 与模型的改进可以耦合：SIA 同时更新脚手架与权重@hebbar2026sia。其三，Harness 与环境的边界在具身场景需要重新勘定：安全联锁与证据链属于物理域的新组件【本书推断】。

#remark(title: [Harness 是载体，不是目标])[最危险的混淆是把「harness 被更新了」误读为「能力进化了」：频繁修改可能只是原地打转甚至退化@lin2026huc。本书始终区分：Harness 是改进的*载体与记账单位*，能力 $U$ 的提升才是改进的*目标*；评估对着能力及其变化率，而非修改活动的繁忙程度。]

=== 自我改进与递归自我改进

设系统在第 $t$ 代的全量可修改状态为 $A_t in cal(A)$（含权重、代码、提示、技能库、记忆策略等），能力度量 $U : cal(A) -> RR$（例如固定回归集上的成功率），改进算子 $Phi : cal(A) -> 2^(cal(A))$。

#definition(title: [自我改进（SI）])[称系统在代数 $t$ 上发生自我改进，若 $A_(t+1) in Phi(A_t)$ 且
$ U(A_(t+1)) > U(A_t), $ <eq:si>
其中不等式在经验意义下以规定置信度成立（统计化判据见第 4 章）。只要 $Phi$ 本身不被更新，无论作用于哪一层，都只是一阶改进。]

#definition(title: [递归自我改进（RSI）])[记 $I_t subset.eq A_t$ 为负责产生改进的改进器子系统（在本书框架中即改进程序 $Phi$ 的实现）。称系统发生递归自我改进，若除 @eq:si 外，还存在改进器度量 $V$ 使
$ V(I_(t+1)) > V(I_t), $ <eq:rsi>
即「改进的能力本身也在改进」@yampolskiy2015seed @duan2026lastai。据此判据：固定元智能体改进下游智能体只是 SI；改进器以自身为输入（如 DGM）才构成递归。]

两个经验注记防止误读。第一，自我改进*非单调*：Gödel Agent 百次自改试验中约 14% 的修改使性能低于起点@yin2024godelagent，@eq:si 的不等式因此须以置信度措辞并要求验证门控。第二，递归性声明有强弱谱系：STaR 式自举属弱 SI；改进器以自身为输入才进入递归；把「修改元层级的规则」也开放为可编辑对象是目前最强的操作化@zhang2026hyperagents。

RSI 的概念谱系远比 LLM 悠久：Good 在 1965 年即论证「智能爆炸」@good1965speculations；理论上的极端形态是 Gödel machine——仅在能*证明*重写后期望效用严格更高时才改写自身@schmidhuber2003godel。它确立了贯穿全书的根本张力：*可证则不可计算，可计算则只能经验验证*。2026 年的审计研究给出冷峻注脚：声称 RSI 的九十篇论文中仅 22% 审计过完整循环的两次以上重跑@chen2026auditing。「递归」是一个必须自证的声明，这是本书写作的第一纪律。

== 问题形式化预告：Physical RSI 四元组与九环节闭环 <sec:formulation>

本节只做预告式陈述，先固定记号与全貌；完整展开留给第 2–4 章与后续章节。

=== Physical RSI 四元组与 L0–L5 分级

《Who Improves the Robot?》提出的形式化@zhou2026physicalrsi 是本书的直接出发点。按其框架，一个 Physical RSI 系统由四元组刻画：

$ "PRSI" := (cal(H), Theta, Phi, E), $ <eq:prsi>

其中 $(cal(H), Theta)$ 为任务执行系统（即 @sec:concepts 的 Agent）；$Phi$ 为改进程序，内含 Adapt（提议修改）、Train（执行训练）、Ver（验证修改）三阶段，且 $Phi$ 自身的实现也在可修改范围内（递归性的落点）；$E$ 为独立评估器，位于系统之外，以固定回归集裁定「什么算改进」，防止系统自指地签发进步证书。这把 Gödel machine 的「证明后修改」在物理域替换为「证据门控后发布」@wang2026regenharness @schmidhuber2003godel。

在此骨架上，框架按「改进发生在哪一层、增益跨越何种范围」给出 L0–L5 分级@zhou2026physicalrsi：

#figure(
  table(
    columns: (1.1cm, 3.4cm, 5.6cm, 4.4cm),
    align: (center, left, left, left),
    [级别], [名称（本书译名）], [判据], [现状（2026-10）],
    [L0], [无自我更新], [系统上线后任何成分不自动改变], [绝大多数部署中的机器人],
    [L1], [单任务能力级更新], [$cal(H)$ 或 $Theta$ 更新，单任务内表现提升；$Phi$ 固定], [已有多例：@bousmalis2023robocat @xiao2025pld 等],
    [L2], [单任务元级更新], [改进程序 $Phi$ 在单任务上被更新], [少数雏形],
    [L3], [跨任务能力级更新], [改进带来的能力增益跨任务迁移], [有初步证据：@li2026embodiedevo @song2026embodiedrsi],
    [L4], [跨任务元级更新], [$Phi$ 的改进跨任务迁移并累积], [仅有雏形],
    [L5], [真递归增益], [L4 之上，另要求「逐轮改进收益递增」的独立受控证据], [*尚无任何系统达到*],
  ),
  caption: [Physical RSI 的 L0–L5 分级（据 @zhou2026physicalrsi 整理转述；「现状」一栏为本书综合 @chen2026auditing @wang2026agenticrobotics 的判断）],
) <tab:levels>

两条轴值得强调。第一，「能力级 vs 元级」精确对应 @eq:si 与 @eq:rsi 的区分：多数自称 RSI 的系统停留在 L1–L3——产物在变好，改进程序却固定@chen2026auditing。第二，L5 的判据苛刻得近乎无情：它要求独立受控的证据表明*改进的速率本身在增长*，正是「智能爆炸」叙事的可操作化@good1965speculations。该框架宣布无人达到 L5，并给出四大优先方向——可靠反馈、因果归因、安全保持、基准建设@zhou2026physicalrsi，本书章节组织与之同构。

=== Embodied RSI 九环节闭环（本书提出）

四元组回答了「系统由什么构成」，但还没有回答「每一轮改进实际流过哪些环节」。【本书提出】把一轮完整的 Embodied RSI 分解为九个环节：

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let r = 4.6
    let w = 2.2
    let h = 0.72
    let labels = (
      [① 任务生成], [② 实验设计], [③ 仿真执行],
      [④ 数据分析], [⑤ 失败归因], [⑥ 提出改进],
      [⑦ 修改系统], [⑧ 验证改进], [⑨ 经验积累],
    )
    let groups = (0, 0, 1, 1, 1, 2, 2, 3, 3)
    let cols = (accent, accent, accent2, accent2, accent2, gray.darken(25%), gray.darken(25%), accent.darken(20%), accent.darken(20%))
    // 环形箭头（相邻节点边缘连线）
    for i in range(9) {
      let a1 = 90deg - i * 40deg
      let a2 = 90deg - (i + 1) * 40deg
      let c1 = (r * calc.cos(a1), r * calc.sin(a1))
      let c2 = (r * calc.cos(a2), r * calc.sin(a2))
      let dx = c2.at(0) - c1.at(0)
      let dy = c2.at(1) - c1.at(1)
      let nrm = calc.sqrt(dx * dx + dy * dy)
      let off = 1.25
      let p1 = (c1.at(0) + dx / nrm * off, c1.at(1) + dy / nrm * off)
      let p2 = (c2.at(0) - dx / nrm * off, c2.at(1) - dy / nrm * off)
      line(p1, p2, mark: (end: ">", scale: 1.6), stroke: 1pt + accent)
    }
    // 节点
    for i in range(9) {
      let a = 90deg - i * 40deg
      let x = r * calc.cos(a)
      let y = r * calc.sin(a)
      let c = cols.at(i)
      rect((x - w / 2, y - h / 2), (x + w / 2, y + h / 2), radius: 0.12, fill: softbg, stroke: 0.9pt + c)
      content((x, y), text(size: 8pt, weight: "bold")[#labels.at(i)])
    }
    // 中心
    circle((0, 0), radius: 1.55, fill: bluebg, stroke: 0.9pt + accent)
    content((0, 0.35), text(size: 8.5pt, weight: "bold")[Embodied RSI])
    content((0, -0.15), text(size: 7.5pt)[九环节闭环])
    content((0, -0.6), text(size: 7.5pt)[（本书提出）])
    // 分组注记
    content((5.95, 4.35), text(size: 7.5pt, fill: accent)[• 做什么：提议与试验])
    content((-6.2, -0.2), text(size: 7.5pt, fill: accent2)[• 学到什么：诊断与归因])
    content((5.95, -4.55), text(size: 7.5pt, fill: gray.darken(25%))[• 留下什么：修改与固化])
  }),
  caption: [Embodied RSI 九环节闭环总览（本书提出）。⑨ 回流①，构成递归的外层循环；三个语义分组对应「做什么 / 学到什么 / 留下什么」。],
) <fig:loop9>

九个环节各自对应一条已有的技术线：①②决定「练什么、先做什么实验」@wang2024robogen @song2026embodiedrsi；③的吞吐由并行仿真与世界模型推高@yang2026rise；④⑤定位失败并归因到组件，是当前最薄弱的环节@zhou2026physicalrsi；⑥⑦即 $Phi$ 的 Adapt 与 Train；⑧由证据门控与独立评估器把关@wang2026regenharness；⑨把教训固化为可继承的工件@li2026embodiedevo @karten2026continual。⑨ 回流①，闭环成立；当⑨积累的经验改变 $Phi$ 的决策质量时，递归性才真正发生——这就是 L4–L5 的工程含义。

#remark(title: [闭环视角的两个推论])[(i) *闭环不是管线*：失败归因可以回到任务生成，验证失败必须触发回滚而非硬上线。(ii) *各环节自动化程度极不均衡*：①③已高度自动化，⑤⑧的「归因与验证」几乎全靠人——RSI 的瓶颈在验证器与归因器，这一判断将贯穿全书。]

== 与相邻概念的关系与边界 <sec:boundary>

Embodied RSI 与四个相邻纲领共享技术组件，边界必须划清。*AutoML/AutoRL* 在人定空间内搜索超参与架构@parkerholder2022autorl，改进器不在空间内，是一阶改进。*终身学习* 关心模型在任务流上不遗忘地累积能力@liu2023libero，但改参数、不改学习算法，只对应九环节中的⑦⑨两段。*开放式学习* 追求「不断产生新奇且可解的问题」@wang2019poet @hughes2024openendedness，但可以原地开花而不变强；RSI 优化能力的复合增长，须接受 $U$ 与 $V$ 的双重审计。*AI-Scientist* 把改进对象移到知识生产本身@lu2024aiscientist，是 RSI 在「科学发现」域的实例化，差别在验证结构：它以模拟评审为终点，Embodied RSI 以物理任务上经独立评估器确认的能力增长为终点。

综上，【本书推断】Embodied RSI 的边界由三条联合判据划定：(i) 改进发生在系统自身的 $(cal(H), Theta)$ 上；(ii) 改进程序 $Phi$ 在可修改范围内（递归性）；(iii) 「什么算改进」由独立评估器裁定，递归声明须提交过程性证据@zhou2026physicalrsi @chen2026auditing。三条缺一，即为相邻概念而非本书主题。

== 全书地图与阅读路线 <sec:roadmap>

本书共十七章加三个附录，按「问题与理论—架构—闭环—前沿与展望」组织。*第一部分（第 1–4 章）*：第 2 章补足数学地基（MDP/POMDP、强化学习与控制）；第 3 章引入元学习、自动化科学发现与贝叶斯实验设计；第 4 章展开 RSI 形式化理论，给出 $U$ 与 $V$ 的完整构造。*第二部分（第 5–9 章）*：把 @fig:harness-layers 的分层逐层工程化——Agent 与 Harness 概念分离、四大子系统解剖、世界模型与任务生成、自我修改机制、评估与改进验证协议@chen2026auditing。*第三部分（第 10–13 章）*：第 10 章把四元组扩展为 $(cal(H), Theta, Phi, M, L)$ 五元组并陈述闭环不变量，是全书理论顶点；第 11–12 章处理仿真基础设施与 VLA 主线；第 13 章逐篇审计机器人实验自动化系统。*第四部分（第 14–17 章及附录）*：开放式进化与计算成本、工程实践与端到端示例、安全风险与治理、开放问题与路线图；附录 A–C 汇集符号表、改进验证协议清单与 2026 下半年前沿大事记。

贯穿全书的三条红线：*证据纪律*——引用性能数字时统一标注评测 harness、基准版本与时点；*归因纪律*——「哪个改动带来增益」必须经对照设计回答@meng2026rsigym；*安全纪律*——自我修改的每层自由度扩张都同步扩大失控面，护栏是架构组件而非附录话题。阅读路线：(i) *理论导向*：第 1→2→3→4→10→17 章；(ii) *系统导向*：第 1→5→6→8→9→15 章；(iii) *快速通览*：第 1、4、10、17 章；(iv) *具身实践导向*：第 1→11→12→13→15 章。
