#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 元学习、自动化科学发现与实验设计

第 2 章把"智能体—环境—学习—评估"链条数学化。本章回答两个问题：*学习系统能否学会"如何学习"？能否学会"如何做实验"？* 前者是元学习的主题——优化对象从"任务上的策略"上移为"跨任务的学习算法"本身；后者是自动化科学发现与贝叶斯实验设计（BED）的主题。主线：元学习是 RSI 的最小形式（3.1–3.2 节），自动化科学发现是其在"知识生产"域的预演（3.3 节），期望信息增益（EIG）是"实验设计"环节的数学核心（3.4 节），最后折叠回具身 RSI（3.5 节）。

== 元学习问题定义

元学习学习"从数据到学习器"的映射：系统面对一整族任务，在外层循环中反复经历"拿到新任务—快速适应—评估适应质量"，把"如何快速适应"本身学好。

#definition(title: [元学习问题（任务分布上的双层优化）])[
设任务空间 $cal(T)$ 上存在任务分布 $p(cal(T))$。每个任务 $cal(T)_i$ 由支持集 $cal(D)_i^"tr"$、查询集 $cal(D)_i^"te"$ 与损失函数 $cal(L)_i$ 组成。元学习系统由*内层适应规则* $U_omega$ 与*元参数* $omega$ 构成，外层目标是使适应后的泛化损失在任务分布上的期望最小：
$ min_omega J^"meta" (omega) = EE_(cal(T)_i ~ p(cal(T))) [ cal(L)_i^"te" ( U_omega (cal(D)_i^"tr"), cal(D)_i^"te" ) ] . $ <eq:metaobj>
内层优化求解"这个任务怎么做"，外层优化求解"怎样安排学习，才能使任意新任务都做得快"。
]

@eq:metaobj 有三个要素值得推敲。其一，*任务分布* $p(cal(T))$ 是元学习的"环境供给"——本书推断，这正是 RSI 闭环必须自带"任务生成"环节的根本理由。其二，*双层结构*使"学习"第一次成为可优化的对象：外层梯度必须"穿过"内层适应过程。其三，*元泛化*：评估标准是未见过任务上的适应速度——同样地，"学会了改进"须在新情境下检验。

=== MAML：对适应过程本身求导

MAML @finn2017model 给出双层优化最简洁的实例：内层适应规则取为一步梯度下降，元参数取为所有任务共享的初始化 $theta$。内层对任务 $cal(T)_i$ 做一步适应：
$ phi_i = theta - alpha nabla_theta cal(L)_i^"tr" (f_theta), $ <eq:maml-inner>
外层最小化适应后的查询集损失：
$ min_theta sum_(cal(T)_i ~ p(cal(T))) cal(L)_i^"te" (f_(phi_i)) = min_theta sum_(cal(T)_i) cal(L)_i^"te" ( f_(theta - alpha nabla_theta cal(L)_i^"tr" (f_theta)) ) . $ <eq:maml-outer>

外层更新需要对 @eq:maml-outer 求关于 $theta$ 的梯度。由于 $phi_i$ 本身是 $theta$ 的函数，链式法则给出元梯度
$ nabla_theta cal(L)_i^"te" (f_(phi_i)) = nabla_theta phi_i dot nabla_(phi_i) cal(L)_i^"te" (f_(phi_i)) = ( I - alpha nabla_theta^2 cal(L)_i^"tr" (f_theta) ) nabla_(phi_i) cal(L)_i^"te" (f_(phi_i)) . $ <eq:metagrad>

@eq:metagrad 是本章第一个关键公式。雅可比因子 $(I - alpha nabla_theta^2 cal(L)_i^"tr")$ 含有内层损失的 Hessian——元梯度必须对"梯度下降这一步"本身再求一次导，这就是"对学习过程求导"的精确含义。Hessian 项昂贵，一阶近似（FOMAML）将其丢弃而性能损失常很小。理论意义在于表达力："初始化 + 少步梯度"足以逼近一大类学习算法——学习算法被压缩进一个初值点。

#remark(title: [二阶项对 RSI 的启示（本书推断）])[
MAML 可元学习的前提是内层适应对外层目标可微；不可微时外层只能退化为进化搜索等零阶方法。对 RSI 的推广是直接的：*改进算子 $Phi$ 若要从"碰运气式的变异"升级为"有方向的改进"，就必须向外层回传某种梯度或效用信号*。
]

@fig:bilevel 给出其数据流总览。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let bs = (fill: softbg, stroke: 0.9pt + accent, radius: 0.12)
    let bs2 = (fill: white, stroke: 0.9pt + accent2, radius: 0.12)
    // 内层行（底部）
    rect((0, 0), (3.0, 1.4), ..bs)
    content((1.5, 0.7), text(size: 8pt)[任务分布 $p(cal(T))$])
    rect((4.3, 0), (7.3, 1.4), ..bs)
    content((5.8, 0.7), text(size: 8pt)[采样任务批 ${cal(T)_i}$])
    rect((8.6, 0), (13.4, 1.4), ..bs2)
    content((11.0, 0.7), text(size: 8pt)[内层适应#linebreak()$phi_i = theta - alpha nabla_theta cal(L)_i^"tr"$])
    // 外层行（顶部）
    rect((0, 3.4), (3.0, 4.8), ..bs2)
    content((1.5, 4.1), text(size: 8pt)[元参数 $theta$（共享初始化）])
    rect((4.3, 3.4), (8.3, 4.8), ..bs)
    content((6.3, 4.1), text(size: 8pt)[外层目标#linebreak()$min_theta sum_i cal(L)_i^"te" (f_(phi_i))$])
    // 内层行箭头
    line((3.0, 0.7), (4.3, 0.7), mark: (end: ">"), stroke: 0.9pt + accent)
    line((7.3, 0.7), (8.6, 0.7), mark: (end: ">"), stroke: 0.9pt + accent)
    // theta 注入内层（肘形）
    line((3.0, 4.1), (13.0, 4.1), stroke: 0.9pt + accent2)
    line((13.0, 4.1), (13.0, 1.4), mark: (end: ">"), stroke: 0.9pt + accent2)
    content((12.25, 3.3), text(size: 7.5pt, fill: accent2)[初始化注入])
    // 查询损失回传（肘形）
    line((9.8, 1.4), (9.8, 4.1), stroke: 0.9pt + accent)
    line((9.8, 4.1), (8.3, 4.1), mark: (end: ">"), stroke: 0.9pt + accent)
    content((10.75, 2.4), text(size: 7.5pt, fill: accent)[查询集损失])
    // 外层更新
    line((4.3, 4.1), (3.0, 4.1), mark: (end: ">"), stroke: 0.9pt + accent)
    content((3.65, 5.12), text(size: 7.5pt, fill: accent)[元梯度（外层更新，@eq:metagrad）])
  })),
  caption: [元学习双层优化的数据流。外层维护元参数 $theta$，内层对每个采样任务执行一步可微适应，查询集损失穿过内层过程回传元梯度。],
) <fig:bilevel>

=== RL² 与上下文学习：算法即记忆

大型 Transformer 的上下文学习（ICL）把 RL² @duan2016rl2 的"算法即记忆"谱系推到极致：模型在*完全没有参数更新*的前向传播中"学会"新任务。理论上，线性自注意力层可在前向传播中精确实现一步梯度下降 @vonoswald2023transformers，ICL 也可解释为隐式贝叶斯推断 @xie2022incontext——*预训练是外层元学习，前向推理是内层学习*。对 RSI 而言，"读实验日志后改进行为"正是 in-context 形式的自我改进 @shinn2023reflexion @ouyang2026reasoningbank；本书推断，改进算子 $Phi$ 应同时持有"上下文内适应"与"权重内适应"两端 @zhang2026agentic。

== “学会学习”与自我改进：概念桥梁

元学习与 RSI 之间不是类比关系，而是包含关系。*第一，优化对象上移*：元学习优化学习算法本身，系统中已存在依据内层结果改进内层学习的外层循环。*第二，元学习是 RSI 的最小形式*：双层元学习恰在做"改进自身的改进能力"的最小版本；与完全体的差别只有两处——外层循环只在训练期运行，且外层规则本身固定。*第三，递归化*：把外层循环解放到部署期持续运转，并允许外层规则自身成为改进对象，其不动点正是 RSI 完全体。

这条谱系的两端是：Schmidhuber 1987 年首次形式化"学习如何学习"的递归结构 @schmidhuber1987thesis，Gödel 机要求自我修改附带"可证明的改进" @schmidhuber2003godel；DGM 则用经验基准上的进化搜索替代可证明性 @zhang2025dgm @wang2025hgm @liu2026mgm。谱系整体可解读为：*Gödel 机的理论刚性被松弛为元学习式的经验可检验性*——只要求统计显著的留出基准改进。

【本书提出】操作性判据：称系统为 $k$ 阶自我改进系统，当且仅当存在 $k$ 层嵌套优化循环，第 $j$ 层优化第 $j-1$ 层的学习规则，且最外层循环在部署后仍在运转。按此判据，MAML 与 RL² 是 2 阶系统（训练期），DGM 类是部署期的经验化 2 阶系统，3 阶及以上仍只有雏形 @harnessmdp2026；该判据将在第 4 章与 L0–L5 分级对接 @zhou2026physicalrsi。AI-GA 三支柱 @clune2019aiga 补上注脚：完整的"学会学习"还要求*自动生成学习环境*——任务分布从给定条件变成设计变量。

== 自动化科学发现：假设—实验—分析的闭环

自动化科学发现把*提出假设 $arrow$ 设计实验 $arrow$ 执行观测 $arrow$ 分析数据 $arrow$ 修正假设*的闭环机器化。其中最难机器化的是"分析"——把数据变成*可理解的规律*。标志性工作 AI Feynman @udrescu2020aifeynman 先用神经网络拟合数据，再递归检测量纲一致性、对称性、可分性等结构，在"精度—复杂度"的 Pareto 前沿上筛选公式，复原了《费曼物理学讲义》全部 100 个方程。其方法论启示：*发现 = 拟合 + 结构归纳偏置 + 复杂度约束的搜索*，同一配方在程序空间中同样奏效 @romeraparedes2024funsearch @novikov2025alphaevolve。这把"归因"提升为*符号化的解释*——正是"失败归因"环节应追求的规范形式。

@fig:isomorphism 把科学发现闭环与具身 RSI 闭环并置：二者结构同构，逐环节存在可迁移的数学工具。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let top-style = (fill: softbg, stroke: 0.9pt + accent, radius: 0.12)
    let bot-style = (fill: white, stroke: 0.9pt + accent2, radius: 0.12)
    let xs = (0, 2.8, 5.6, 8.4, 11.2)
    let tops = ([假设生成], [实验设计#linebreak()（EIG 最大化）], [实验执行], [数据分析#linebreak()与解释], [假设修正])
    let bots = ([任务生成], [实验编排], [策略执行], [失败归因], none)
    // 顶行：科学发现闭环
    for i in range(5) {
      rect((xs.at(i), 3.2), (xs.at(i) + 2.5, 4.4), ..top-style)
      content((xs.at(i) + 1.25, 3.8), text(size: 8pt)[#tops.at(i)])
      if i < 4 {
        line((xs.at(i) + 2.5, 3.8), (xs.at(i) + 2.8, 3.8), mark: (end: ">"), stroke: 0.9pt + accent)
      }
    }
    // 底行：具身 RSI 闭环
    for i in range(4) {
      rect((xs.at(i), 0), (xs.at(i) + 2.5, 1.2), ..bot-style)
      content((xs.at(i) + 1.25, 0.6), text(size: 8pt)[#bots.at(i)])
      line((xs.at(i) + 2.5, 0.6), (xs.at(i) + 2.8, 0.6), mark: (end: ">"), stroke: 0.9pt + accent2)
    }
    rect((11.2, 0), (12.3, 1.2), ..bot-style)
    content((11.75, 0.6), text(size: 8pt)[修改])
    rect((12.6, 0), (13.7, 1.2), ..bot-style)
    content((13.15, 0.6), text(size: 8pt)[验证])
    line((10.9, 0.6), (11.2, 0.6), mark: (end: ">"), stroke: 0.9pt + accent2)
    line((12.3, 0.6), (12.6, 0.6), mark: (end: ">"), stroke: 0.9pt + accent2)
    // 顶行回路
    line((12.45, 4.4), (12.45, 5.1), stroke: 0.9pt + accent)
    line((12.45, 5.1), (1.25, 5.1), stroke: 0.9pt + accent)
    line((1.25, 5.1), (1.25, 4.4), mark: (end: ">"), stroke: 0.9pt + accent)
    content((6.85, 5.38), text(size: 7.5pt, fill: accent)[新假设驱动下一轮实验])
    // 底行回路
    line((13.15, 0), (13.15, -0.9), stroke: 0.9pt + accent2)
    line((13.15, -0.9), (1.25, -0.9), stroke: 0.9pt + accent2)
    line((1.25, -0.9), (1.25, 0), mark: (end: ">"), stroke: 0.9pt + accent2)
    content((7.2, -1.18), text(size: 7.5pt, fill: accent2)[验证通过的修改进入下一代智能体])
    // 同构对应虚线（双向）
    let labels = ([任务分布#linebreak()设计], [EIG#linebreak()最大化], [执行#linebreak()即实验], [归因#linebreak()即解释])
    for i in range(4) {
      line((xs.at(i) + 1.25, 1.2), (xs.at(i) + 1.25, 3.2), stroke: (dash: "dashed", thickness: 0.7pt, paint: gray.darken(10%)), mark: (end: ">", start: ">"))
      content((xs.at(i) + 1.42, 2.2), anchor: "west", text(size: 7pt, fill: gray.darken(20%))[#labels.at(i)])
    }
    line((11.75, 1.2), (11.75, 3.2), stroke: (dash: "dashed", thickness: 0.7pt, paint: gray.darken(10%)), mark: (end: ">", start: ">"))
    line((13.15, 1.2), (13.15, 3.2), stroke: (dash: "dashed", thickness: 0.7pt, paint: gray.darken(10%)), mark: (end: ">", start: ">"))
    content((11.0, 2.2), anchor: "west", text(size: 7pt, fill: gray.darken(20%))[改进与验证])
    // 行标题
    content((3.0, 4.78), anchor: "west", text(size: 8.5pt, fill: accent, weight: "bold")[科学发现闭环])
    content((3.0, -0.5), anchor: "west", text(size: 8.5pt, fill: accent2, weight: "bold")[具身 RSI 闭环])
  })),
  caption: [科学发现闭环（上）与具身 RSI 闭环（下）的同构对应：任务生成对应任务分布设计，实验编排对应 EIG 最大化（3.4 节），失败归因对应科学解释，修改与验证对应假设修正。],
) <fig:isomorphism>

【本书框架】该同构图不是修辞：科学发现闭环可严格写成"序贯贝叶斯实验设计 + 假设空间上的贝叶斯更新 + 主动假设生成"三件套，前两件有成熟定量理论（3.4 节），第三件由 LLM 先验承担。逐环节翻译，就得到自我改进过程的可分析版本。

== 贝叶斯实验设计

实验设计回答：*在所有可做实验中，下一个最值得做的是哪一个？* BED 把这一问题量化为信息论优化 @lindley1956measure @rainforth2024modern。BED 是 RSI 闭环"实验设计"环节的数学核心：每一次"试一试"都是一次实验，EIG 给出"该试什么"的可计算判据。本节中 $theta$ 为待推断的假设或参数；$xi in Xi$ 为设计变量；观测 $y$ 服从似然 $p(y | theta, xi)$。

#definition(title: [期望信息增益（EIG）])[
设计 $xi$ 的期望信息增益是观测前后假设熵的期望减少量：
$ "EIG"(xi) = EE_(p(y | xi)) [ H[p(theta)] - H[p(theta | y, xi)] ] . $ <eq:eig>
最优设计为 $ xi^* = argmax_(xi in Xi) "EIG"(xi) . $ <eq:optdesign>
]

#proposition(title: [EIG 的等价形式与基本性质])[
EIG 有三种等价写法：
$ "EIG"(xi) = I(theta; y | xi) = EE_(p(theta) p(y | theta, xi)) [ log frac(p(y | theta, xi), p(y | xi)) ] = EE_(p(theta)) [ D_"KL" ( p(theta | y, xi) \| p(theta) ) ] , $ <eq:eig-forms>
即：EIG 等于假设与观测在给定设计下的互信息；等于对数似然比的期望；等于从先验到后验的期望 KL 散度。由互信息的非负性，$"EIG"(xi) >= 0$，等号成立当且仅当实验结果与假设无关。链式法则使序贯设计的总 EIG 可分解为各步条件互信息之和，为多步规划提供记账规则。
]

@eq:eig-forms 的三种读法对应 RSI 闭环的三种记账视角：互信息度量"实验能缩小多少假设不确定性"；对数似然比度量"观测有多意外"；KL 散度度量"信念将移动多远"（归因的强度）。三者共用同一个量——实验、探索与归因价值记在同一本账上。

*计算与序贯化。* @eq:eig 的双重期望几乎总不可解析，现代方法用变分界逼近内层后验、把外层期望蒙特卡洛化 @rainforth2024modern。序贯 BED 中多步 EIG 的累积构成"纯信息回报"的序贯决策问题，Deep Adaptive Design 用策略网络摊销序贯设计，是 BED 与 RL 合流的标志 @foster2021dad。实验目的是直接优化黑箱目标时，对应工具是贝叶斯优化（BO）@shahriari2016taking；主动学习是 BED 在标注任务上的特化。分工随之清晰：*候选改进的生成*借 BO 编排，*实验的判别力*由 EIG 保证。

=== 2026 前沿：实验设计的 LLM 化与摊销化

2026 年下半年，BED 与 LLM 推理融合的代表是 AR-BED @arbed2026：把序贯实验设计摊销进推理型 LLM，策略被参数化为推理轨迹与设计的联合分布
$ pi_phi (z_t, x_t | h_(t-1)) = pi_phi (z_t | h_(t-1)) dot pi_phi (x_t | h_(t-1), z_t), $ <eq:arbed>
其中 $h_(t-1)$ 为实验历史，$z_t$ 为显式推理轨迹，$x_t$ 为第 $t$ 步设计；训练采用可验证奖励的强化学习，奖励即外部 oracle 似然评估出的 EIG。两个设计决策尤具启发性：*实验生成模型与 LLM 自身信念解耦*，避免依赖 LLM 校准很差的预测分布；*多步 EIG 累积为纯信息回报*，落地了"链式法则记账"的结构。

这组工作对 RSI 的意义是范式级的：*"提问/做实验"的能力本身是可学习的策略，而非固定启发式*。本书推断，下一步是把摊销设计策略直接用作具身 RSI 闭环的实验编排器：历史轨迹即改进账本，设计即下一次试验，EIG 奖励即改进的信息价值。

== 与具身 RSI 的对应：最新进展与未解决问题

把 3.1–3.4 节的工具折叠回具身 RSI，得到三重对应。*对应一：任务生成 = 任务分布设计。* 元学习把 $p(cal(T))$ 视为给定条件，具身 RSI 必须自己生成并演化它 @wang2019poet @dennis2020paired @jiang2021plr。【本书推断】任务生成器可统一形式化为任务空间上的外层策略，其效用函数有两个现成候选：遗憾（"学会做"）与 EIG（"学会改"），二者应同时记账。

*对应二：实验编排 = EIG 最大化。* 每一次试验都是一个设计变量 $xi$，其选择应以 @eq:optdesign 为准则：AR-BED 证明序贯实验设计可摊销进推理型 LLM @arbed2026；BO 的采集函数提供候选选择的现成引擎 @shahriari2016taking；RISE 把试错搬入世界模型的想象空间，使"实验"的边际成本趋近于零 @yang2026rise——世界模型正是 BED 的"实验生成模型"。

*对应三：失败归因 = 科学解释。* 归因的最高形式是产出可复用的符号化规律，而非仅报告误差。2026 年的具身系统正在逼近这一标准 @lu2026aspire @xiao2026enpire @li2026embodiedevo @wang2026regenharness，共性是：*归因产物被结构化为可检索、可复用、可审计的资产*。

*未解决的问题。* （i）*真递归增益尚无实例*：按 L0–L5 分级，尚无任何系统达到 L5，多数自称 RSI 的系统只是 L1–L3 @zhou2026physicalrsi；本章的 $k$ 阶判据与 L5 判据互补——前者数嵌套层数，后者验改进加速度。（ii）*具身域的 EIG 计算与奖励来源*：AR-BED 依赖外部似然 oracle @arbed2026，而机器人领域缺乏大规模可验证奖励；世界模型能否充当足够校准的"实验生成模型"，决定 EIG 编排能否迁入物理域。（iii）*任务分布自发设计的失控风险*：生成器可能生成容易任务以刷改进指标，这是 Goodhart 定律在任务生成环节的实例 @manheim2018goodhart。（iv）*验证强度需与修改风险匹配*：高置信离策略评估 @thomas2015high 与信赖域式单调改进 @schulman2015trust 提供了工具，但二者如何分层挂钩仍是开放问题。
