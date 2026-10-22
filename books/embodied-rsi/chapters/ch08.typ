#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 自我修改机制：改什么、何时改、如何提交

本章处理机制设计的核心三问：具身 RSI 系统*改什么*（修改空间）、*何时改*（触发机制）、*如何生成并提交修改*（提案到入库的管线）。本章立场：自我修改不是一次性的"重写自身"，而是一条受门禁约束的*变更管理流水线*；Gödel machine 的"证明有益才修改"是其理想极限 @schmidhuber2003godel，DGM、Self-Harness、RegenHarness 等是它在经验验证下的可行近似 @zhang2025dgm @zhang2026selfharness @wang2026regenharness。

== 修改空间的形式化

设系统状态 $A_t$ 包含一切可被修改的成分——harness 代码、提示与配置、记忆库、工具集、工作流乃至模型权重。

#definition(title: [修改与修改空间])[
一次*修改* $m$ 是作用在系统状态上的变换，通常以补丁形式参数化：存在应用算子 $⊕$ 使 $A' = A ⊕ m$。*修改空间* $cal(M)$ 是所有可表达、可应用修改的集合，按作用对象分解为不相交子空间的并
$ cal(M) = cal(M)_"cfg" union cal(M)_"prompt" union cal(M)_"mem" union cal(M)_"tool" union cal(M)_"flow" union cal(M)_"code" union cal(M)_"w" . $ <eq:modspace>
]

*改进算子* $Phi : bb(A) times cal(E) arrow 2^(cal(M))$ 以系统状态与积累证据 $cal(E)$ 为输入，输出候选修改集合，内部由*触发器* $T$（是否调用）、*生成器* $G$（产生候选）与*提交器* $C$（是否保留）三段组成。一次完整的自我修改循环为
$ m_t in G(A_t, cal(E)_t), quad A_(t+1) = cases(A_t ⊕ m_t & "若" C(m_t, cal(D)_"val") = 1, A_t & "否则") $ <eq:loop>
其中 $cal(D)_"val"$ 为验证集，提交器 $C$ 即 8.3 节的门禁机制。

@eq:modspace 的七个子空间构成"改什么"的完整类型学：*配置与参数*（标量调优）；*提示与上下文*（DSPy @khattab2023dspy、TextGrad @yuksekgonul2024textgrad、ACE @zhang2026ace）；*记忆*（A-MEM @xu2025amem、ReasoningBank @ouyang2026reasoningbank，风险是错误教训固化）；*工具*（CREATOR @qian2023creator，Voyager 技能库是程序性记忆与工具创造的合流 @wang2023voyager）；*工作流与架构*（ADAS @hu2025adas、AFlow @zhang2025aflow）；*harness 源码*（DGM/SICA/HGM 的主战场 @zhang2025dgm @robeyns2025sica @wang2025hgm 及 harness 自改进浪潮 @zhang2026selfharness）；*模型权重*（Self-Rewarding @yuan2024selfrewarding、SEAL @zweiger2025seal、SIA @hebbar2026sia）。

七个子空间沿一条*可修改性谱系*排列：越靠近配置端，修改越廉价、越可逆、验证越快；越靠近权重端，越昂贵、越难回滚、风险越集中（@fig:pyramid）。权衡可用四属性刻画：生成成本 $c_"gen"(m)$、验证成本 $c_"ver"(m)$、可逆性与*爆炸半径*（失败时受损功能的最大范围）。【本书推断】默认原则是*把递归自我改进的主循环部署在谱系下段*，上段置于更严、更低频的门禁之后——RegenHarness 只修订 harness 配置并把验证门划出可编辑范围 @wang2026regenharness，DGM/HGM 编辑源码但权重冻结 @zhang2025dgm @wang2025hgm；反之 Gödel Agent 的无门禁 monkey patching 付出约 14% 性能退化的代价 @yin2024godelagent。根本原因在于 harness 层修改以文本/代码为载体，天然可 diff、可版本化、可回归，权重层三者皆缺 @harnessengineering2026。

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let names = ("配置 / 运行参数", "Prompt / 上下文", "记忆库", "工具集", "工作流 / 架构", "Harness 源码", "模型权重")
    let n = names.len()
    let h = 0.72
    let w0 = 9.4
    let wn = 1.4
    for i in range(n) {
      let wb = w0 - (w0 - wn) * i / n
      let wt = w0 - (w0 - wn) * (i + 1) / n
      let y = i * h
      let fillc = if calc.rem(i, 2) == 0 { rgb("#f6f4ef") } else { rgb("#eef3f5") }
      line((-wb/2, y), (wb/2, y), (wt/2, y + h), (-wt/2, y + h), close: true, fill: fillc, stroke: 0.8pt + rgb("#0f5c5c"))
      content((0, y + h/2), text(size: 8pt)[#names.at(i)])
    }
    line((5.4, 0.1), (5.4, n * h - 0.1), mark: (end: ">"), stroke: 0.9pt + rgb("#8c5a2b"))
    content((6.9, n * h - 0.5), text(size: 7.5pt, fill: rgb("#8c5a2b"))[修改成本·验证成本])
    content((6.9, n * h - 0.95), text(size: 7.5pt, fill: rgb("#8c5a2b"))[不可逆性·风险 递增])
    line((-5.4, n * h - 0.1), (-5.4, 0.1), mark: (end: ">"), stroke: 0.9pt + rgb("#0f5c5c"))
    content((-6.9, 1.1), text(size: 7.5pt, fill: rgb("#0f5c5c"))[修改频率·可逆性])
    content((-6.9, 0.65), text(size: 7.5pt, fill: rgb("#0f5c5c"))[触发粒度 递增])
  }),
  caption: [修改空间层级金字塔。自底向上从运行配置深入到模型权重；修改成本、验证成本与风险递增，修改频率与可逆性递减。工程默认：绝大多数修改集中在下半部（可文本化、可版本化、可回归的层），上半部施加最高规格门禁。],
) <fig:pyramid>

对具身系统，修改空间还包含两个编码域没有的对象（本书提出）：*技能契约*——技能绑定前置条件、效果、证据要求与恢复语义，修改实现、契约、验收谓词（须元级授权）是三个截然不同的类别 @wang2026regenharness；*本体模型*——智能体对自身形态与传感执行器配置的内部表征 @lou2026knowyourbody，其修订可能使旧效用定义失效，本体论危机由此变为版本管理问题 @deblanc2011ontological。

== 何时改：触发机制

触发器是证据流上的布尔函数 $T : cal(E)_t arrow {0,1}$，文献中有四类。*周期性触发*（STaR 式逐轮微调 @zelikman2022star）节奏可预测但对证据视而不见。*失败驱动触发*以失败事件为信号（Reflexion @shinn2023reflexion、Self-Harness 的弱点挖掘 @zhang2026selfharness），直觉是"边际改进集中在失败处"，风险是缺乏主动探索。*EIG 驱动触发*建立在期望信息增益 @lindley1956measure @chaloner1995bayesian 上：
$ "EIG"(m) = EE_(o)[ D_"KL" ( p(U | o, m) || p(U) ) ] , $ <eq:eig8>
触发条件为 $max_m "EIG"(m) \/ (c_"gen"(m) + c_"ver"(m)) > tau$；HGM 的 clade 级元生产力可视为其特化 @wang2025hgm。*遗憾驱动触发*把"是否发起修改"当作 bandit 手臂选择 @auer2002finite，用 UCB 式乐观策略平衡利用与探索 @zhao2026godelforest @qu2026coral；它理论性质最好、实践案例最少，天然适合作 EIG 的在线化实现（本书推断）。

验证成本不可省略——无门禁的自我修改已被证明会退化 @yin2024godelagent 或被 reward hacking 污染 @zhang2025dgm。设修改 $m$ 的真实效用增量为 $Delta U(m)$，触发—提交联合决策应满足期望净收益为正：
$ EE[Delta U(m) | cal(E)_t] > c_"gen"(m) + c_"ver"(m) + lambda dot.op R(m), $ <eq:netgain>
其中 $R(m)$ 为风险度量（爆炸半径的期望损失），$lambda$ 为风险价格。三个推论：第一，*验证成本决定可行的修改频率上限*——DGM 两周 80 代的成本几乎全花在候选验证上 @zhang2025dgm，"在何处花验证预算"比"花多少"更关键 @wang2025hgm。第二，*谱系位置与触发频率应当匹配*：配置/prompt 层验证廉价可任务内触发，权重层只适合低频大闸门。第三，*复用验证集有隐形成本*：反复在同一评测集上做自适应保留决策会使经验改进与真实改进脱节 @sun2026reuse。具身场景把这一权衡推向极端：真实世界验证趋于无穷贵，可行解法是*分层验证*——世界模型想象 @yang2026rise 或仿真 @meng2026rsigym 承担高频低置信验证，真实硬件只做低频高置信确认；触发机制于是在"是否改"与"在哪层验证"两维上同时决策（本书观点）。


== 如何生成与提交：从提案到入库的门禁管线

生成器 $G$ 把证据翻译成候选修改，三条范式按候选多样性的来源与信用分配粒度区分：*LLM 直接生成*（STOP 的改进器程序可作用于包括自身在内的任意代码 @zelikman2024stop；Self-Harness 是受约束版本 @zhang2026selfharness），语义理解强但多样性受底座模型"品味"限制；*进化生成*把 LLM 降级为变异算子、多样性由种群与档案保证（FunSearch @romeraparedes2024funsearch、AlphaEvolve @novikov2025alphaevolve、作用于自身代码的 DGM @zhang2025dgm），代价是评估开销与对可自动评分任务的依赖；*搜索式生成*把修改空间显式构造成树或图，高峰 HGM 以 Thompson 采样估计元生产力分配扩展预算 @wang2025hgm。【本书观点】三范式应随谱系分层选用（下段 LLM 生成、中段进化或搜索、上段实为数据合成）；混合架构——LLM 读懂证据、提案修改，进化/搜索保证多样性与预算纪律——是自然终点。

生成只产出候选；决定系统命运的是提交环节的五机制——版本化、commit gate、回归集门禁、canary 与 rollback（@fig:gate）。

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let acc = rgb("#0f5c5c")
    let acc2 = rgb("#8c5a2b")
    let softbg = rgb("#f6f4ef")
    let boxw = 2.05
    let boxh = 0.78
    let box(x, y, label, strokec) = {
      rect((x - boxw/2, y - boxh/2), (x + boxw/2, y + boxh/2), radius: 0.12, fill: softbg, stroke: 0.9pt + strokec)
      content((x, y), text(size: 7.5pt)[#label])
    }
    let arr(a, b, label: none, lc: acc, bend: 0deg, dashed: false) = {
      if dashed {
        line(a, b, mark: (end: ">"), stroke: (paint: lc, thickness: 0.8pt, dash: "dashed"))
      } else {
        line(a, b, mark: (end: ">"), stroke: 0.8pt + lc)
      }
    }
    box(1.1, 3.2, [触发#linebreak()证据积累], acc)
    box(3.6, 3.2, [提案生成#linebreak()（G）], acc)
    box(6.1, 3.2, [静态审查#linebreak()契约检查], acc)
    box(8.6, 3.2, [沙箱/仿真#linebreak()验证], acc)
    box(11.1, 3.2, [回归门禁#linebreak()固定回归集], acc2)
    box(8.6, 0.9, [金丝雀部署#linebreak()小流量试运行], acc2)
    box(11.1, 0.9, [提交入库#linebreak()版本 v+1], acc)
    box(3.6, 0.9, [拒绝归档#linebreak()记录谱系], acc2)
    box(6.1, 0.9, [回滚#linebreak()恢复 v], acc2)
    arr((2.05, 3.2), (2.65, 3.2))
    arr((4.55, 3.2), (5.15, 3.2))
    arr((7.05, 3.2), (7.65, 3.2))
    arr((9.55, 3.2), (10.15, 3.2))
    arr((11.1, 2.8), (8.9, 1.35))
    arr((9.55, 0.9), (10.15, 0.9))

    // 失败总线：走两排盒子之间的空白带，避免穿越标签
    line((11.1, 2.8), (11.1, 2.1), (1.35, 2.1), (1.35, 2.75), mark: (end: ">"), stroke: (paint: acc2, thickness: 0.8pt, dash: "dashed"))
    content((6.2, 1.94), frame: "rect", fill: white, stroke: none, padding: 1.4pt, text(size: 6.8pt, fill: acc2)[失败 → 修订 / 拒绝 / 回滚])

    // 异常 → 回滚：底排下方单独走线
    line((7.55, 0.9), (7.15, 0.9), mark: (end: ">"), stroke: (paint: acc2, thickness: 0.8pt, dash: "dashed"))
    line((11.1, 0.51), (11.1, 0.18), (6.1, 0.18), (6.1, 0.51), mark: (end: ">"), stroke: (paint: acc2, thickness: 0.8pt, dash: "dashed"))
    content((8.6, 0.02), frame: "rect", fill: white, stroke: none, padding: 1.4pt, text(size: 6.8pt, fill: acc2)[金丝雀 / 事后异常 → 回滚])
  }),
  caption: [提案→门禁→提交→回滚状态机。实线为正常流向；虚线为异常流向——各级失败回到提案生成或拒绝归档，金丝雀与事后异常触发回滚。拒绝的修改不入档，但其谱系与失败证据必须回流，供下一轮生成使用。],
) <fig:gate>

一切提交的前提是*版本化*：$A_t$ 必须可寻址、可 diff、可回滚 @zhang2025dgm，且具身系统的版本化范围还包括环境侧工件（技能契约、回归集与仿真器版本）。

*Commit gate* 是提交器 $C$ 的工程实现：修改只有同时通过身份检查（谁提议、改了哪层）、静态契约检查与动态验证才可入库。RegenHarness 给出最完整的具身实例：规划、技能、验证、恢复四角色隔离上下文，验证者不继承规划者的完成声明，RSI 修订配置须经回归集、安全契约、预声明指标与发布授权四道手续 @wang2026regenharness；Self-Harness 的回归门（修复一个 case 但打破任何旧 case 即拒绝，held-in/held-out 分割防过拟合）是其编码域对应物 @zhang2026selfharness。统计侧：SGM 以 e-value 与全局错误预算约束累积虚假接受风险 @wu2025sgm，REUSE 要求限制反馈信息量以防评测复用过拟合 @sun2026reuse。硬教训：提案者能读到验收测试时回归门退化为可 hack 目标，对策是隐藏校验函数 @zhang2025dgm @srikanth2026aide2。

通过门禁的修改只获得*有限信任*：*canary 部署*把新版本暴露给小流量真实任务（仿真先行、单台设备、低风险场景），观测预声明指标后才放量；*rollback* 要求每次提交附带可执行逆操作 @schmidhuber1997shifting。无重置设定的特殊困难在于环境不回滚、只有 harness 可回滚，canary 收益评估须把"环境已被旧版本改变"计入归因 @karten2026continual。

#theorem(title: [更新器—验收谓词分离原则（RegenHarness 原则）])[
在证据门控 RSI 协议中，任何修改提案均不得弱化验证自身的验收谓词：更新器无权修改自己的验收标准；验收谓词、回归集与安全契约的变更须走更高一级的授权通道。等价地，记验收谓词族为 $cal(V)$，提交函数满足
$ C(m) = 1 arrow.double m|_(cal(V)) = "id" $ <eq:separation>
即修改在验收层上为恒等映射，除非 $m$ 经元级授权通道显式批准。
]

该原则是 Orseau–Ring 形式化的工程转译：能改写奖励机制的理性智能体有动机改写之 @orseau2011selfmodification，验收层必须对更新器只读；STOP 与 DGM 的日志伪造 @zelikman2024stop @zhang2025dgm、AI Scientist 尝试延长运行时间 @lu2024aiscientist 都是该原则的反例验证。【本书推断】此原则应递归应用到元层级：修改"修改规则"的提案同样无权弱化元级门禁 @zhang2026hyperagents。

== 元层级问题：修改 harness 的 harness

提交管线自身也是一段程序：能改到第几层为止？把改进算子按作用对象分层：$Phi^((0))$ 修改任务行为层，$Phi^((1))$ 修改 $Phi^((0))$ 的生成与门禁规则，依此类推。历史系统各自固定在不同层级：Gödel machine 原则上允许无限层 @schmidhuber2003godel，STOP 是固定深度有限递归 @zelikman2024stop，DGM 的元机制手工固定 @zhang2025dgm，Hyperagents 则把元规则本身纳入可编辑范围 @zhang2026hyperagents。层级每上升一层，自由度与爆炸半径同步放大；Physical RSI 以独立评估器 $E$ 置于系统之外 @zhou2026physicalrsi，本质是承认递归必须终止于不受系统控制的信任锚点。

#proposition(title: [递归修改的分层终止（本书观点）])[
设层级 $ell$ 的修改须通过该层门禁 $cal(V)_ell$，则健全的元层级结构应满足：
(i) *信任根不可编辑*：存在有限层级 $L$ 使 $cal(V)_L$ 对系统只读，仅人类治理通道可变更；分离原则（@eq:separation）在每一层成立——$Phi^((ell))$ 无权弱化 $cal(V)_ell$；
(ii) *经济终止*：当某层的期望净收益（@eq:netgain 右端含该层更高的验证与风险成本）持续非正时，该层及以上停止触发；
(iii) *预算终止*：全局统计错误预算（SGM 式 @wu2025sgm）耗尽时，递归不再统计可信，系统冻结为只执行不修改。
]

三个条件分别对应安全、效率与认识论三条终止理由：(i) 是底线——没有信任根的递归修改没有可审计的不变量 @lin2026huc @chen2026auditing；(ii) 解释了现实系统递归深度为何都浅——元层验证成本随层级上升而收益递减；(iii) 把"长期开放性 vs 有限可信度"显式化——预算耗尽后系统转入以已验证形态运行的稳态。对具身 RSI，信任根部分在硬件里（安全联锁、急停、功率限制），天然不可被软件递归触及 @li2026embodiedevo @lou2026knowyourbody。最紧迫的未解决问题有四（本书观点）：修改频率、评测复用与错误预算的统一核算；无重置环境下 canary 收益的因果归因 @karten2026continual；元级门禁"不得弱化"的机器可检查规格语言；权重层修改的可审计性——权重 diff 无语义，管线在 $cal(M)_"w"$ 上退化 @zweiger2025seal @hebbar2026sia。

== 本章小结

本章把自我修改机制拆解为三个可工程化的问题。改什么：修改空间沿可修改性谱系分层（@fig:pyramid），主循环应部署在谱系下段。何时改：四类触发机制的统一判据是期望净收益为正（@eq:netgain），修改频率须受统计控制 @sun2026reuse。如何生成与提交：三范式按谱系分层选用；提交侧五机制构成变更管理流水线（@fig:gate），其内核是更新器—验收谓词分离原则。元层级递归必须终止于信任根、经济极限与错误预算三者之一——这一"分层信任递减"框架是本书对 Hyperagents 时代开放性问题的回答 @zhang2026hyperagents。

#keybox(title: [本章要点])[
- 修改空间七层类型学沿可修改性谱系排列；主循环在下段，上段配最高规格门禁。
- 触发四类型（周期/失败/EIG/遗憾）的统一判据：$EE[Delta U] > c_"gen" + c_"ver" + lambda R$。
- 生成三范式（LLM 生成 / 档案进化 / 树搜索）按谱系分层选用，混合架构为自然终点。
- 提交管线五机制：版本化、commit gate、回归门禁、canary、rollback；更新器无权弱化自己的验收谓词，该原则递归适用于每个元层级。
- 元层级递归以信任根、经济终止、预算终止收口；硬件安全层是信任根的物理实现。
]
