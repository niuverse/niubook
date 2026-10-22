#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= Agent 与 Harness：概念分离、系统解剖与平台化转身

具身递归自我改进（Embodied RSI）的可操作空间，大部分不在模型权重之内，而在权重之外的运行时基础设施中。本章为这一论断建立概念地基与工程地图：分离 "agent""model""harness" 三个术语（5.1 节），解剖生产级 agent 系统的趋同结构（5.2 节），考察 harness 作为一等优化对象的代表方法（5.3 节），再给出具身 harness 的特殊要求（5.4 节）、一条关键实证警告（5.5 节）与本书提出的 Agent-Native Harness 四原则（5.6 节）。

== 概念分离：Model、Harness 与评测装置

"agent"一词曾至少有三种互不兼容的用法：指模型本身、指提示词模板加一次工具调用、或指持续运行的软件系统。用词含混直接导致评估含混：得分翻倍时无法回答分数属于模型还是围绕模型的软件。2025–2026 年间收敛到清晰的分层【已有成果】：

$ "Agent" = "Model" + "Harness" $

即 $cal(A)_"llm" = (M, cal(H))$；Anthropic 的等价表述是：agent 不过是"语言模型在循环中基于环境反馈使用工具"。

#definition(title: [模型（Model）])[
模型 $M$ 是无状态的文本到文本函数：每次调用相互独立，无跨调用记忆；只能#emph[表达]调用工具的意图，不能真正执行动作。
]

#definition(title: [Harness（支架/挽具）])[
Harness $cal(H)$ 是围绕模型、把模型变成 agent 的一切软件基础设施的总和：主循环、工具分发、上下文管理、记忆持久化、执行沙箱、权限门、防护栏。
]

三个近义词需辨析：#strong[scaffold] 是 harness 中"塑造模型如何看待世界"的行为定义层（提示、工具描述、输出格式）；#strong[evaluation harness] 职责相反——目的是#emph[测量]而非#emph[完成]任务（见 5.5 节）；#strong[workflow] 是控制流的静态拓扑，为结构搜索方法的优化对象 @zhang2025aflow @shang2025agentsquare。

形式化地，设 harness 维护的上下文状态为 $C_t$（对话历史、记忆指针、技能索引等），POMDP 中 agent 的闭环可写为【本书推断，综合 @zelikman2024stop @yang2024sweagent 的形式化传统】：

$ h_(t+1)", " a_t &= "Loop"(M, C_t, T, P) \
  o_t", " r_t &= "Env"("Sandbox"(a_t)) \
  C_(t+1) &= "ManageContext"(C_t, a_t, o_t) $ <eq:harness-loop>

其中 $"Loop"$、$T$、$P$、$"ManageContext"$、$"Sandbox"$ 全部属于 $cal(H)$，只有 $M$ 是模型。@eq:harness-loop 揭示关键事实：#strong[自我改进的绝大多数可操作空间位于 harness 一侧]——模型权重通常冻结，而 harness 是纯软件：可文本化、可版本化、可回归测试。STOP 最早把这一点做成系统 @zelikman2024stop；Voyager 证明程序性记忆可以纯代码形式在 harness 层积累 @wang2023voyager。

这一分离也是评估方法论的前提：同一底座下，精心设计的 Agent-Computer Interface 比默认基线高 10.7 个百分点 @yang2024sweagent。#strong[同一模型在不同 harness 下得分可差数倍]，基准分数应标注为"模型 × harness × 评测装置"三元组的联合属性 @jimenez2024swebench @merrill2026terminalbench。

#remark(title: [为什么分离对 RSI 至关重要])[
改进算子 $Phi$ 若把 agent 系统当作整体修改，收益归因不可解。概念分离使三类可审计的实验设计成为可能：固定 $M$ 改 $cal(H)$、固定 $cal(H)$ 改 $M$、或两者按协议交替（5.3 节 Co-Harness）；本书后续 RSI 协议都要求改动落在三个格子之一。
]

== 生产 Harness 解剖：七件套与平台化转身

《Harness Engineering》对 11 个生产级编码 agent 系统做了源码级解剖 @harnessengineering2026，三项发现构成本节骨架。

第一，#strong[趋同]。所有对象收敛到同一工件形态——本书称之为#strong[七件套]：loop（主循环）、tools（工具分发）、skills（技能库）、sub-agents（子代理）、hooks（事件钩子）、MCP（对外协议）、sessions（会话持久化）（@fig:seven-piece）。趋同是可追踪的模仿（Codex 逐字采用 Claude Code 的 hook 事件词汇），功能差异化的半衰期"以周计"——耐久的是结构型论断而非功能清单。

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 外框：Harness
    rect((0.2, 0.0), (13.8, 7.0), radius: 0.2, fill: bluebg, stroke: 1pt + softline)
    content((7.0, 6.68), text(size: 9pt, weight: "bold", fill: accent)[Harness $cal(H)$：模型之外的一切运行时基础设施])
    // 七件套：六个卫星 + 中央 loop
    rect((5.0, 5.3), (9.0, 6.25), radius: 0.12, fill: softbg, stroke: 0.8pt + accent)
    content((7.0, 5.78), text(size: 8pt)[MCP / 对外协议接口])
    rect((0.7, 3.55), (3.7, 4.55), radius: 0.12, fill: softbg, stroke: 0.8pt + accent)
    content((2.2, 4.05), text(size: 8pt)[工具分发 Tools])
    rect((0.7, 1.35), (3.7, 2.35), radius: 0.12, fill: softbg, stroke: 0.8pt + accent)
    content((2.2, 1.85), text(size: 8pt)[技能库 Skills])
    rect((10.3, 3.55), (13.3, 4.55), radius: 0.12, fill: softbg, stroke: 0.8pt + accent)
    content((11.8, 4.05), text(size: 8pt)[子代理 Sub-agents])
    rect((10.3, 1.35), (13.3, 2.35), radius: 0.12, fill: softbg, stroke: 0.8pt + accent)
    content((11.8, 1.85), text(size: 8pt)[钩子 Hooks])
    rect((3.7, 0.35), (6.7, 1.25), radius: 0.12, fill: softbg, stroke: 0.8pt + accent)
    content((5.2, 0.8), text(size: 8pt)[会话持久化 Sessions])
    rect((7.5, 0.35), (10.5, 1.25), radius: 0.12, fill: softbg, stroke: 0.8pt + accent2)
    content((9.0, 0.8), text(size: 8pt)[执行沙箱 Sandbox])
    // 中央 loop
    rect((4.2, 2.7), (9.8, 4.95), radius: 0.15, fill: white, stroke: 1.1pt + accent)
    content((7.0, 4.5), text(size: 8pt, weight: "bold", fill: accent)[主循环 Loop（控制流 + 上下文）])
    rect((5.6, 3.05), (8.4, 4.15), radius: 0.12, fill: softbg, stroke: 0.9pt + accent2)
    content((7.0, 3.6), text(size: 8pt)[模型 $M$（无状态策略 $pi_theta$）])
    // 连线
    line((7.0, 4.95), (7.0, 5.3), mark: (start: ">", end: ">"), stroke: 0.7pt + accent)
    line((4.2, 4.1), (3.7, 4.05), mark: (start: ">", end: ">"), stroke: 0.7pt + accent)
    line((4.2, 3.1), (3.7, 1.85), mark: (start: ">", end: ">"), stroke: 0.7pt + accent)
    line((9.8, 4.1), (10.3, 4.05), mark: (start: ">", end: ">"), stroke: 0.7pt + accent)
    line((9.8, 3.1), (10.3, 1.85), mark: (start: ">", end: ">"), stroke: 0.7pt + accent)
    line((5.9, 2.7), (5.4, 1.25), mark: (start: ">", end: ">"), stroke: 0.7pt + accent)
    line((8.3, 2.7), (8.9, 1.25), mark: (start: ">", end: ">"), stroke: 0.7pt + accent)
    // 环境（harness 之外）
    rect((7.5, -1.35), (10.5, -0.45), radius: 0.12, fill: white, stroke: 0.9pt + ink)
    content((9.0, -0.9), text(size: 8pt)[环境 Env（返回 $o_t, r_t$）])
    line((9.0, 0.35), (9.0, -0.45), mark: (start: ">", end: ">"), stroke: 0.7pt + accent2)
    content((10.9, -0.08), text(size: 6.5pt, fill: accent2)[动作 $a_t$ / 观测 $o_t$])
  }),
  caption: [生产级 agent harness 的七件套解剖图（据 @harnessengineering2026 综合绘制）。沙箱是 harness 与环境之间的唯一受控通道。],
) <fig:seven-piece>

第二，#strong[平台化转身]。各家 Agent SDK 相继发布，harness 从私有管线变成可 import 的库，甚至出现编排 11 家厂商 harness 的 meta-harness；同时#strong[行为策略正从 prompt 散文迁移到配置与代码]——确定性的 hook 与 guard 取代自然语言劝告。

第三，#strong[外环的出现]。解剖发现了一个此前无名的模式：#emph[outer verification loop]——OpenHands 的 `/goal` 端点用 LLM judge 审计内环运行并决定重提示还是停止；Hermes 的 verify-on-stop 可否决内环的退出请求 @harnessengineering2026。内环是"模型在环境中行动"（@eq:harness-loop），外环是"系统对自身运行进行验证与再调度"——本书将此视为 RSI 的工程胚胎。

压缩成一个判断：loop、tools、sessions 让 agent #emph[跑起来]，skills、sub-agents、MCP 让它#emph[跑得久、跑得宽]，hooks 与沙箱让它#emph[跑得可信]——只有执行边界被确定性机制（而非模型的善意）把守时，"让 agent 改写自己的运行时"才是可讨论的命题。

== Harness 作为优化对象：2026 年的谱系爆发

自我改进的对象在三年内逐层下沉【已有成果，谱系综合自 @gao2025selfevolvingsurvey @zhang2025dgm】：2023 年改提示（DSPy、TextGrad @khattab2023dspy @yuksekgonul2024textgrad），2024–25 年改 agent 结构与源码（ADAS、DGM 等 @hu2025adas @zhang2025aflow @robeyns2025sica @zhang2025dgm），2026 年把 #strong[harness 整体]确立为一等可学习对象——其结构化解剖使修改可#emph[局部化]、验证可#emph[分层化]、归因可#emph[定位化]。以下实质分析四个代表方法。

#strong[Self-Harness]（2026-06）把"agent 改进自身 harness"形式化为三段式流水线 @zhang2026selfharness：#emph[Weakness Mining] 从执行轨迹聚类出模型特定的失败模式；#emph[Harness Proposal] 生成最小化修改；#emph[Proposal Validation] 用 held-in/held-out 双重回归门判决——修复一个 case 但打破旧 case 的编辑被拒绝。Terminal-Bench-2.0 上 9 个组合全部提升（最大相对 +132%），不动任何权重；"回归门"由此成为默认接受判据。

#strong[Harness-R1]（2026-08）首次把 harness 工程能力变成#emph[可训练的模型]：一个 9B "harness engineer" 读取成批失败轨迹，生成挂在四个生命周期钩点上的可执行补丁；目标 agent 权重冻结，以补丁重跑同批任务的#emph[实际性能差分]为奖励做 GRPO @shao2026harnessr1。三基准平均 +9.3 个百分点，可泛化到 20 个未见目标模型；手工固定策略反而平均#emph[降低] 2.6 个百分点——干预必须"按失败模式抓药"。

#strong[Co-Harness]（2026-07）把改进面扩展到权重侧：HarnessCritic 提出经校验的局部 harness 更新，模型随后在改进后 harness 产生的高质量轨迹上微调，把有效脚手架"蒸馏"进参数，两者#emph[交替进行] @chen2026coharness @hebbar2026sia。

#strong[HarnessX]（2026-06）代表"harness 工厂"形态：类型化原语经替换代数组合，进化引擎把 harness 进化映射为符号空间上的 MDP，预测出三类类似 RL 的病理（reward hacking、灾难性遗忘、探索不足）并配以架构性防御——#emph[seesaw constraint]（使已解决任务回退的编辑被确定性拒绝）、变体隔离等 @chen2026harnessx。五基准平均 +14.5%，局限是未评估 held-out 泛化。

其余路线各补一块拼图：Meta-Harness 检视全部历史候选，迭代返回 Pareto 前沿 @lee2026metaharness；AHE 主张进化需组件/轨迹/决策#emph[三级可观测性]配套 @lin2026agenticharness；Continual Harness 取消 episode 边界、边行动边修订自身 @karten2026continual，但无重置带来"没有干净回归点"与早期行为自我写回的#emph[自我污染]风险 @shinn2023reflexion，实用形态将是"在线提案、批量验证"（本书推断）。@tab:selfimprove 从"改什么、何时改、如何验证"三轴对比本节方法。

#figure(
  table(
    columns: (2.5cm, 3.6cm, 2.8cm, 6.0cm),
    text(size: 8pt)[方法], text(size: 8pt)[改什么], text(size: 8pt)[何时改], text(size: 8pt)[如何验证（接受判据）],
    text(size: 8pt)[Self-Harness @zhang2026selfharness], text(size: 8pt)[针对弱点聚类的最小 harness 补丁], text(size: 8pt)[任务间（离线）], text(size: 8pt)[held-in/held-out 双重回归门],
    text(size: 8pt)[Harness-R1 @shao2026harnessr1], text(size: 8pt)[四生命周期钩点上的可执行补丁], text(size: 8pt)[任务间（RL 训练 engineer）], text(size: 8pt)[冻结目标重跑同批任务的实际差分奖励（GRPO）],
    text(size: 8pt)[Co-Harness @chen2026coharness], text(size: 8pt)[harness 局部更新 + 模型权重交替], text(size: 8pt)[交替双环], text(size: 8pt)[HarnessCritic 提案 + 非回归校验后入库],
    text(size: 8pt)[HarnessX @chen2026harnessx], text(size: 8pt)[类型化原语组合 + harness—模型信号], text(size: 8pt)[任务间（多 agent 进化轮）], text(size: 8pt)[seesaw 确定性门 + 变体隔离 + 跨 harness GRPO],
    text(size: 8pt)[Continual Harness @karten2026continual], text(size: 8pt)[prompt/子代理/技能/记忆 +（可选）权重], text(size: 8pt)[任务内（无重置在线）], text(size: 8pt)[连续运行中的里程碑进展；教师重标注闭环],
  ),
  caption: [Harness 自改进方法对比：改什么、何时改、如何验证。],
) <tab:selfimprove>

== 具身 Harness 的特殊性：证据门控与本体模型

把编码域的解剖学搬到物理世界，会撞上三类数字域不存在的约束：#strong[不可逆性]（动作可能损坏硬件）、#strong[实时性]（控制环有硬时延预算）、#strong[证据链]（"控制器停止输出"不代表"任务完成"）。

#strong[RegenHarness]（2026-09）是首个面向机器人 agent 的证据门控（evidence-gated）harness @wang2026regenharness，要点有四。其一，#strong[三类事件严格分离]：模型提议、控制器终止、经验证的任务完成是不同事件，禁止以前者冒充后者。其二，#strong[版本化技能契约]：技能调用绑定前置条件、效果、证据要求与恢复策略——技能不是代码，而是可审计的合同。其三，#strong[角色隔离与 commit gate]：规划、验证等角色持有隔离上下文，验证者#emph[不继承]规划者的完成声明，只有通过证据校验的结论才写入共享状态。其四，#strong[RSI 协议自我约束]：跨任务修订须经固定回归集、安全契约保持、预声明指标改进与发布授权四道门，全部版本化以支持 rollback；最要害的是——#strong[更新器无权弱化自己的验收谓词]，这是 Gödel 机"可证有益才修改"原则 @schmidhuber2003godel 在物理域的工程化替身。批评同样值得记录：其实验仅证明实机流程贯通，尚无多轮迭代收益的独立受控证据（L5 判据）@zhou2026physicalrsi——"门控正确"不等于"递归增益存在"。

另一项具身特有需求是#strong[本体模型]：具身 harness 的环境包括机器人自己的身体，而身体会变（磨损、换装、漂移）。Know Your Body 用 VLM harness 维护可查询、可修订的本体模型，agent 持续核对"我以为的身体"与"观测到的身体"并把差异写回 @lou2026knowyourbody。本体模型可视为七件套之外的第八件：没有它，进化提案将基于过时的身体假设做验证，回归门再严也是把锁装错了门。

== 实证警告：Harness Updating ≠ Harness Benefit

《Harness Updating Is Not Harness Benefit》（KDD 2026 Oral）把 harness 自我进化拆成两种必须分别测量的能力：#strong[harness-updating]（产出有用更新）与 #strong[harness-benefit]（从更新中实际获益）【已有成果，本节数字全部来自 @lin2026huc】。7 evolver × 6 solver × 3 基准的矩阵实验发现：

#enum(
  [#strong[更新曲线（HUC）近乎平坦：] 强弱模型产出的 harness 更新增益相当——写补丁并不强烈依赖基础模型能力。],
  [#strong[获益曲线（HBC）非单调：] 弱模型几乎不获益（技能载入率 0.25 对强模型 0.96）；#emph[中档模型获益最大]（+19.3 个百分点）；最强模型已近天花板（+2.6 个百分点）。],
)

这推翻了"harness 工程只为旗舰模型服务"的默认假设：最大边际收益落在中档模型上；弱模型需要的不是自然语言劝告，而是确定性的 hook 与可执行 guard。对具身 RSI 的含义是直接的：写更新的可以是云端强模型，运行 harness 的端侧模型往往是中小模型——#strong[评估必须按端侧模型的载入率与遵循度分层报告]；只报"进化后总分"的实验无法区分"工程师变强了"与"执行者更会用了"，大量自称"递归自我改进"的论文也未审计递归过程本身 @chen2026auditing。本书据此确立纪律：#strong[每一代 harness 都须在 held-out 任务族上回归，修改谱系、更新算力与模型版本随分数一同报告]。

== Agent-Native Harness 设计原则（本书提出）

综合上述解剖与证据，本书提出面向自我改进场景的 harness 设计四原则【原创设计】。判据是：harness 是否"agent-native"，不看它让 agent 跑得多好，而看它是否让#emph[改进 agent] 本身可工程化。

#definition(title: [Agent-Native Harness 四原则])[
设 $cal(H)$ 接受改进算子 $Phi$ 的修改 $m$，验证集 $cal(D)_"val"$，验收谓词 $V$。$cal(H)$ 是 agent-native 的，当且仅当同时满足：
+ #strong[可观测性]：每次模型调用、工具执行与决策分叉都产生结构化记录，粒度覆盖组件级、轨迹级、决策级 @lin2026agenticharness；
+ #strong[可修改性]：$cal(H)$ 由类型化、可组合原语构成，任何 $m$ 可表达为局部 diff，且修改面对 $Phi$ 显式开放；
+ #strong[可验证性]：存在与 $Phi$ 隔离的验收谓词 $V$ 与固定回归集，$cal(H) plus m$ 仅当 $V$ 通过且不违反安全契约时提交；$Phi$ 无权修改 $V$ 本身 @wang2026regenharness；
+ #strong[可追溯性]：全部修改带版本、谱系与证据链，支持任意时刻的 diff、审计与 rollback @zhang2025dgm @wang2026regenharness。
]

四原则彼此咬合：没有可观测性，可验证性退化为盲测；没有可修改性，诊断无法转化为行动；没有可追溯性，信任在一次错误提交后归零。任何一条答"否"，自我改进回路就应保持 human-in-the-loop 而非闭合。

== 本章小结

本章确立了 $"Agent" = "Model" + "Harness"$ 的分离及其闭环形式化（@eq:harness-loop）；给出七件套解剖与平台化转身，指出 outer verification loop 是 RSI 的工程胚胎；梳理了 harness 作为优化对象的代表路线与具身 harness 的证据门控、本体模型两项特殊要求，以"HUC 平坦、HBC 非单调"校准乐观预期，凝练为 Agent-Native Harness 四原则。未解决问题包括跨任务元级改进、机器人域可验证奖励来源 @zhou2026physicalrsi、模型—harness 共进化的归因。

#keybox(title: [本章要点])[
+ Agent $=$ Model $+$ Harness；harness 是自我改进的主要可操作面。
+ 评测记账必须是"模型 × harness × 评测装置"三元组；同一模型换 harness 得分可差数倍。
+ 生产 harness 已趋同为七件套并完成平台化转身；outer verification loop 是 RSI 的工程胚胎。
+ 代表路线：Self-Harness（回归门）、Harness-R1（RL 训练补丁工程师）、Co-Harness（harness—权重交替）、HarnessX（类型化原语工厂）、Continual Harness（无重置在线）。
+ 具身 harness 额外要求：证据门控（角色隔离、commit gate、更新器无权弱化验收谓词）与本体模型。
+ Harness updating $eq.not$ harness benefit：更新能力近乎平坦，获益能力非单调、中档模型最大。
+ Agent-Native Harness 四原则（本书提出）：可观测、可修改、可验证、可追溯。
]
