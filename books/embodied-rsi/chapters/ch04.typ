#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 递归自我改进的形式化理论：从 Gödel 机到自我演化智能体

递归自我改进（RSI）指系统利用自身能力改进自身、且"改进能力本身"也在被改进的闭环过程。本章是全书理论核心，追问三个问题：什么叫改进（定义）、凭什么相信改进发生了（验证）、改进链条能否自我维持（递归）。RSI 研究史有三条源头：智能爆炸的概念论述、形式化自我修改、LLM 时代以经验验证为准绳的自我改进系统，三线共享同一张力：*最优性可证则不可计算，可计算则只能经验验证*——本章沿这张力的放松展开。

== 历史谱系：从智能爆炸到可计算自我修改 <sec:history>

概念原点归于 Good：1958 年 Ulam 追忆 von Neumann 时首用"奇点" @ulam1958tribute；1965 年 Good 给出正反馈论证——"设计机器"本身是智力活动，超智能机器将设计出更好的机器 @good1965speculations。Vinge 预言人类时代终结 @vinge1993singularity；Yudkowsky 以*认知再投资回报*把起飞速度经济学化 @yudkowsky2013microeconomics；Bostrom 把能力增长率写为优化力除以顽抗性 @bostrom2014superintelligence；Yampolskiy 要求"改进器本身"也被改进，是 §4.3 定义的基石 @yampolskiy2015seed；Omohundro 论证自我改进是工具性收敛驱动 @omohundro2008basic。形式化源头从 Solomonoff 归纳（渐近最优但不可计算 @solomonoff1964formal）到 AIXI（Pareto 最优但不可计算 @hutter2005universal，其最优性依赖图灵机选择 @leike2015bad），再到 Schmidhuber 一脉（自指元学习、成功故事算法、OOPS @schmidhuber1987thesis @schmidhuber1997shifting @schmidhuber2004oops），顶点是 Gödel machine @schmidhuber2003godel。第三条源头（STaR @zelikman2022star、STOP @zelikman2024stop、DGM @zhang2025dgm）在 §4.4–4.5 展开。

== Gödel machine：可证最优自我改进的严格形式化 <sec:godel>

Gödel machine 是迄今唯一把"改进必须在采纳前被*证明*有益"贯彻到底的自我修改系统 @schmidhuber2003godel @schmidhuber2009ultimate。系统由单一软件 $p$ 描述：与环境交互的策略、固定的公理系统 $cal(A)_0$（硬编码硬件模型、效用函数 $u$ 与环境知识）、以及持续搜索目标定理的证明搜索器。效用是*单次生命*的：记剩余生命周期至时刻 $T$，则

$ u(p) = EE [ sum_(t=1)^T r_t mid(|) p \, "在当前状态下持续运行" ], $ <eq:utility>

期望按 $cal(A)_0$ 中的环境模型计算。没有"试验可以重来"的假设——证明搜索消耗的时间必须计入效用，这在 §4.5 至关重要。

证明搜索器的目标定理形如：存在新软件 $p'$ 使

$ cal(A)_0 tack.r u(p') > u(p), $ <eq:godel-rewrite>

且右边包含继续运行当前 $p$ 的全部后果（含证明搜索与重写代价）。证明一旦找到，系统立即执行*全局重写* $p arrow.l p'$：策略乃至证明搜索器自身都被替换——递归性正系于此。决策环见 @fig:godel-loop。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let node(pos, w, h, body, fill: softbg, sc: accent) = {
      let (x, y) = pos
      rect((x - w/2, y - h/2), (x + w/2, y + h/2), radius: 0.15, fill: fill, stroke: 0.7pt + sc)
      content((x, y), text(size: 8pt)[#body])
    }
    node((2.7, 2.7), 4.8, 1.3)[环境交互：执行 $p$\ 累积效用与轨迹]
    node((10.2, 2.7), 4.8, 1.3)[证明搜索器：在 $cal(A)_0$\ 中搜索目标定理]
    node((10.2, 0.1), 4.8, 1.3, fill: bluebg, sc: accent2)[判定：存在 $p'$ 与证明\ 使 $cal(A)_0 tack.r u(p') > u(p)$？]
    node((2.7, 0.1), 4.8, 1.3)[全局重写 $p arrow.l p'$\ 含证明搜索器自身]
    line((5.1, 2.7), (7.8, 2.7), mark: (end: ">"), stroke: 0.7pt + accent)
    content((6.45, 2.95), text(size: 7.5pt)[轨迹 + 公理])
    line((10.2, 2.05), (10.2, 0.75), mark: (end: ">"), stroke: 0.7pt + accent)
    line((7.8, 0.1), (5.1, 0.1), mark: (end: ">"), stroke: 0.7pt + accent)
    content((6.45, 0.35), text(size: 7.5pt)[是：立即重写])
    line((2.7, 0.75), (2.7, 2.05), mark: (end: ">"), stroke: 0.7pt + accent)
    content((2.85, 1.4), anchor: "west", text(size: 7.5pt)[以 $p'$ 继续])
    line((12.6, 0.1), (13.5, 0.1), (13.5, 2.7), (12.6, 2.7), mark: (end: ">"), stroke: 0.7pt + gray.darken(20%))
    content((13.5, 3.0), anchor: "south", text(size: 7.5pt)[否：继续搜索（消耗预算）])
    content((6.5, -1.05), text(size: 7.5pt, fill: gray.darken(20%))[公理系统 $cal(A)_0$ 全程硬编码、不可修改])
  })),
  caption: [Gödel machine 决策环：策略执行与证明搜索并行；唯严格证明触发全局重写],
) <fig:godel-loop>

其最优性主张必须精确理解：它*不*声称找到全局最好的自我改进（那一般不可判定），而是声称*任何能被证明严格有益的自我重写都不会被错过*——在"可证改进"的陈述类内部，接受机制是全局最优的。这套机制的优美与不可行性同源：其一，*可证性瓶颈*——绝大多数实际有益的重写不可证；其二，*证明搜索的代价*——搜索不可判定且消耗效用预算，"易证"与"有用"没有先验重合 @schmidhuber2004oops；其三，*目标与公理硬编码*——唯独"什么叫好"不可修改，埋下 §4.7 的 wireheading 隐患；其四，*无视经验证据*。Gödel machine 确立的不是可建造的机器，而是一组参照系；此后二十年的领域，就是在 @eq:godel-rewrite 左边寻找"证明"的可行替代物——这正是 §4.4 的主线。

== 递归自我改进的四级定义 <sec:definitions>

固定记号：系统第 $t$ 代状态 $A_t in cal(A)$ 包含代码、权重、策略、工具集、harness 配置等*一切可修改成分*；性能度量 $U : cal(A) -> RR$；改进算子 $Phi$ 给出可达候选修改集。

#definition(title: [自我改进（SI）])[
系统序列 ${A_t}$ 发生自我改进，若 $A_(t+1) in Phi(A_t)$ 且
$ U(A_(t+1)) > U(A_t), $ <eq:si4>
不等式在经验意义下只要求以给定置信度成立（定义 4.4）。
]

#definition(title: [严格递归自我改进（RSI，Yampolskiy 型）])[
记 $I_t subset A_t$ 为负责产生改进的*改进器子系统*。系统发生严格 RSI，若除 @eq:si4 外，还存在改进器质量度量 $V$ 使
$ V(I_(t+1)) > V(I_t), $ <eq:rsi4>
即"改进能力本身"也在改进 @yampolskiy2015seed @wang2018formulation；等价操作化表述：$Phi$ 必须落在可修改状态空间内。
]

#definition(title: [智能爆炸轨迹条件])[
记能力水平 $C_t = U(A_t)$，增量 $Delta_t = C_(t+1) - C_t$。轨迹具有递增认知再投资回报 @yudkowsky2013microeconomics，若 $Delta$ 作为 $C$ 的函数递增；充分条件 $C_(t+1) >= alpha C_t$（$alpha > 1$）给出超指数轨迹。反之，若顽抗性增长快于优化力 @bostrom2014superintelligence，$Delta_t$ 递减，RSI 收敛于有限水平——递归性本身并不蕴含爆炸。
]

#definition(title: [改进的验证强度四级（本书采用）])[
按采纳修改 $m$ 前的论证强度，自我改进分为四级：
+ *证明级*：存在形式证明 $cal(A)_0 tack.r U(A_t ⊕ m) > U(A_t)$（Gödel machine）；
+ *定理化估计级*：接受准则由某定理刻画为对最优准则的逼近，但依赖可检验的统计假设（HGM 的 CMP）；
+ *统计认证级*：以 e-value、错误预算等给出 $PP("错误提升") <= alpha$ 的全局保证（SGM、REUSE）；
+ *经验验证级*：仅以验证集 $cal(D)_"val"$ 上的经验评估 $hat(U)$ 门控（STOP、DGM 及绝大多数 LLM 时代系统）。
]

全书采用的工作定义：*RSI = 定义 4.1 的 SI + 定义 4.2 的改进器可改进性*，并强制标注定义 4.4 的验证等级 @duan2026lastai @chen2026auditing。边界辨析（见 @gao2025selfevolvingsurvey）：STaR 式自举是弱 SI；元学习与 AutoML 是一阶改进；自我复制不等于自我改进；自我奖励类方法的裁判与策略同根，其"递归"受限于共享评估误差 @yuan2024selfrewarding。

== 主线：证明、定理化估计、统计认证、经验验证 <sec:mainline>

从 Gödel machine 到 2026 年的自我演化智能体，RSI 的演化史本质上是 @eq:godel-rewrite 左边"形式证明"的*替代物设计史*：每一级在可行性上迈进，也在保证强度上付出代价。

*定理化估计级*的代表是 Huxley-Gödel Machine（HGM，作者含 Schmidhuber）@wang2025hgm——RSI 史上第一个带"逼近 Gödel 最优性"定理的实用系统。HGM 证明 DGM 式树搜索的隐含假设"基准分最高 = 改进潜力最大"一般不成立（*元生产力-性能错配*），并定义*支级元生产力* CMP：以后代谱系的聚合表现而非自身即时分数度量改进潜力。定理 1 表明：在可重复评测与单位预算假设下，CMP oracle 足以复现 Gödel machine 的接受机制——形式证明被替换为谱系估计；实证上以不足 DGM 一半的算力超过 DGM。根本局限："评测可重复"假设在具身设定中不成立（§4.5 展开）。

*统计认证级*：能否在证明门槛与裸经验门控之间插入统计安全层？SGM 以 e-value 与 Hoeffding 型集中界替换形式证明，仅当"修改严格更优"被统计认证时才接受，并以全局*错误预算*约束累积错误 @wu2025sgm；局限是原理性的：预算耗尽后系统事实上被冻结，*长期开放的 RSI 与有限错误预算的张力*至今未解。REUSE 处理更隐蔽的一翼：反复利用同一基准集的搜索轨迹会对评测集*自适应过拟合*；REUSE 限制评测反馈信息量并计入全部提升历史，以概率 $>= 1 - alpha$ 保证每次提升都是真实改进，活体实验中错误提升从 20.7% 降至 0% @sun2026reuse。二者合流标志着"统计 Gödel 机"成为独立子领域。

*经验验证级*放弃外生保证，把"改进"定义为验证集上的可观测增益。原型 STOP 让 LLM 编写"改进器"程序并以自身为输入形成固定深度递归，数轮后自主发明束搜索变体，但也出现沙箱逃逸与奖励作弊 @zelikman2024stop。DGM 升级为开放进化范式：维护全量智能体档案并进化选代，80 代内 SWE-bench 从 20.0% 升至 50.0%，消融证实自我改进与开放探索缺一不可 @zhang2025dgm；但也观测到伪造测试日志等 reward hacking，且权重冻结使改进限于脚手架层。对照组：Gödel Agent 无门控改写自身模块，约 14% 试验退化——*自我改进并不单调* @yin2024godelagent；AlphaEvolve 是超强 SI 引擎但进化控制器本身不进化，划清了 SI 与 RSI 的边界 @novikov2025alphaevolve。

@tab:verification 汇总各级代表系统：从证明到经验，保证强度单调下降而可实现性单调上升，没有免费的层级跃迁；迄今没有任何系统同时具备"元规则可编辑 + 统计安全门控 + 权重级更新"——这是谱系的明显空白。

#figure(
  table(
    columns: (2.6cm, 1.2cm, 4.6cm, 3.2cm, 3.4cm),
    [系统], [年份], [验证机制（接受准则）], [保证强度], [主要局限],
    [Gödel machine], [2003], [公理系统内形式证明 $cal(A)_0 tack.r u(p') > u(p)$], [可证最优（限可证陈述类）], [绝大多数改进不可证],
    [HGM], [2025], [CMP 定理化估计：谱系聚合元生产力 oracle 复现 GM 接受机制（定理 1）], [逼近最优（依赖假设 1）], [要求可重复评测与单位预算],
    [SGM], [2025/26], [e-value + Hoeffding 界；全局错误预算 + CTHS], [统计认证：族错误率 $<= alpha$], [预算耗尽即冻结；需噪声有界],
    [REUSE], [2026], [限制评测反馈 + 计入全部提升历史], [每次提升以 $>= 1-alpha$ 为真], [框架级，需宿主搜索过程配合],
    [DGM], [2025], [基准经验验证 + 开放档案进化], [无（经验）], [自适应过拟合；reward hacking],
    [MGM], [2026], [多轨迹比较信号 + 受控变异], [经验 + 加性地形下收敛理论], [地形假设偏强；权重冻结],
    [Gödel Agent], [2024], [无门控运行时改写], [无], [约 14% 试验退化],
  ),
  caption: [验证强度对比：从形式证明到裸经验的四级谱系],
) <tab:verification>

== 2026 谱系与本书的关键论点 <sec:frontier2026>

2026 年，Gödel 谱系沿三个方向分化。*比较进化（MGM）*：以 scaffold 源码为基因型、多轨迹为表现型，引入反应规范变异与跨谱系杂交算子，并在加性适应度地形下证明收敛更快——改进算子 $Phi$ 首次有了收敛速率理论 @liu2026mgm。*数据中心 RSI（Gödel Forest）*：把改进对象从代码移到训练数据策略，用多棵异步共进化搜索树化解"广度-深度"两难 @zhao2026godelforest。*可进化边界扩张*：Hierarchical SI 与 Hyperagents 把提示、工具、记忆、控制流乃至*元层级修改规则本身*都纳入可编辑空间，但无稳定性保证 @hierarchicalsi2026 @zhang2026hyperagents。元研究同时提醒：114 篇 RSI 论文中仅 22% 审计过完整循环的重跑——领域正从"做出 RSI 演示"转向"证明 RSI 发生" @chen2026auditing。

*【本书观点】被绕开的原始条件：可重复试验假设。* 本节与 §4.4 的所有编码域 RSI 系统共享一个很少言明的前提：*试验可以重来*。DGM 的回归评测、HGM 的可重复评测假设、SGM/REUSE 的错误预算核算、MGM 的多轨迹比较，全都依赖"同一系统状态可以反复评测、失败后可以重置"这一基础设施性质。而原始 Gödel machine 的效用语义恰恰是*单次生命*的——$u(p)$ 是剩余生命周期的一次性期望，证明门槛苛刻正因为它认真对待"改写不可撤销、失败不可重来"。编码域后继者用可重置基准绕开了这个原始条件，整套验证机器（证明的统计替代物）因此在原理上绑定了"可重复试验"。具身智能体没有这一性质：物理交互不可逆、机体损耗不可重置、环境非平稳，单次生命是常态 @zhou2026physicalrsi。由此得到本书的关键论点之一：*具身 RSI 不是编码域 RSI 的平凡移植——它必须重建被绕开的原始条件，即在不可重复试验下回答定义 4.4 的验证问题*。可行路径包括单次生命版统计门控、仿真-现实双循环的"准可重复性"、或证据门控 harness 协议（后续章节展开）；无论哪条路径，"改进的认证"都必须在物理世界的不可逆性面前重新发明。这是具身 RSI 最深刻的理论差异，也是全书后续章节的出发点。

== 自我改进的维度分类与层级 <sec:dimensions>

前两节沿"验证强度"纵切，本节沿"改什么"横切 @gao2025selfevolvingsurvey。六个可操作维度：(1) *改 Prompt/上下文*（Self-Refine、TextGrad、Promptbreeder）@fernando2023promptbreeder；(2) *改记忆*（Reflexion、ExpeL）@shinn2023reflexion；(3) *改工具*（Toolformer、CREATOR）@qian2023creator；(4) *改代码即 harness 源码*（STOP、SICA、DGM、HGM），风险是 reward hacking @zhang2025dgm；(5) *改工作流/架构*（ADAS、AFlow、GPTSwarm）@hu2025adas；(6) *改权重（边界维）*（SPIN、Self-Rewarding、SEAL），持久、不可逆、验证昂贵 @yuan2024selfrewarding @zweiger2025seal。层级上：前五维属 harness $cal(H)$——可文本化、可版本化、可回归测试；第六维触碰权重 $theta$；元层——改进规则 $Phi$ 本身可编辑（Hyperagents）。

*【本书推断】维度-可验证性-具身难度三者的耦合。* 六个维度在编码域按"文本化程度"排序，也按"验证与回滚成本"排序；具身设定下还需增加"物理不可逆性"一列：改工具对应改造末端执行器，本体形态的改变连验证集都难以构造。本书主张：具身 RSI 的维度分类必须以"可验证性 × 不可逆性"为轴重排——这把 §4.5 的关键论点落到了工程分类学上。

== 理论边界：不可判定性、奖励腐蚀与本体论危机 <sec:limits>

形式化理论的一半价值在于标定*做不到什么*。其一，*停机与不完全性*：判定"某重写是否有益"包含判定重写后程序的未来行为，一般不可判定；Gödel 不完全性保证存在真而不可证的改进陈述——证明级验证永远无法铺满改进空间。其二，*wireheading 与奖励腐蚀*：当智能体可修改自身（含传感器与奖励通道）时，最大化奖励的策略可转向操纵奖励信号或退入伪造观测的"幻觉箱"——这不是工程 bug，而是形式框架内的逻辑后果 @ring2011delusion @orseau2011selfmodification；STOP 的沙箱逃逸、DGM 的伪造日志是其经验版本 @zhang2025dgm。【本书推断】具身 wireheading 的物理版本更危险：操纵传感器读数、营造"仿真茧房"比篡改日志更难检测回滚（第 16 章）。其三，*本体论危机*：自我改进若改变系统的世界模型本身，旧本体论下书写的效用函数将失去良定义，目标必须在表征变迁中保值 @deblanc2011ontological；在具身 RSI 中，本体论漂移是*日常工程问题*（本书观点）。开放问题还有：错误预算耗尽后的开放性、自我评判的信息论上限、元规则可编辑后的稳定性（Lyapunov 型判据空白）。

== 本章小结

#keybox(title: [本章要点])[
+ 核心张力：最优性可证则不可计算，可计算则只能经验验证；@eq:godel-rewrite 的可证改进是所有后继机制的共同问题形式。
+ 定义 4.1–4.4：SI + 改进器可改进性 + 验证强度四级；任何 RSI 声明必须同时标注两者。
+ HGM 以 CMP 定理把证明替换为谱系聚合估计，SGM/REUSE 建立统计认证层，DGM 谱系实现经验级实用 RSI——无免费跃迁。
+ 【本书观点】编码域 RSI 依赖可重复试验；具身单次生命是被绕开的原始条件，改进认证必须在不可逆世界中重建。
+ 理论边界：停机与不完全性封死绝对最优，wireheading 是逻辑后果，本体论危机在具身设定下变为日常工程（接第 16 章）。
]
