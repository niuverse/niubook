#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 机器人学习：模仿学习、强化学习与 VLA

改进算子 $Phi$ 要在物理世界落地，必须穿过同一道窄门：机器人的策略参数如何被经验更新。本章梳理模仿学习、机器人强化学习与 VLA 三大范式及其自我改进路径，最后放回第 10 章的 Embodied RSI 框架中定位。贯穿全章的主线是：瓶颈已从「模型容量」转移到「经验的获取与验证成本」 @zhou2026physicalrsi，协变量偏移则换了四次面孔（误差复合、外推误差、分布对齐、想象偏差）。

== 模仿学习 <sec:il>

=== 行为克隆与协变量偏移

模仿学习把控制问题化归为监督学习：给定专家演示数据集 $cal(D)_E = {(o_t, a_t)}$，行为克隆（BC）直接最大化专家动作的似然，

$ theta_"BC" = argmin_theta EE_((o_t, a_t) tilde cal(D)_E) [ -log pi_theta (a_t | o_t) ]. $ <eq:bc>

这个化归的代价隐藏在分布假设里：训练时状态来自专家诱导的分布 $d_(pi^*)$，部署时却由学习策略自身诱导的分布 $d_(pi_theta)$ 产生——一旦偏离，策略就在未见状态上决策，误差改变下一步的状态分布，形成*协变量偏移*的级联。设策略在专家分布下出错概率为 $epsilon$，逐步展开可得 $|d_(pi)^t - d_(pi^*)^t|_1 <= 2 t epsilon$；若每步犯错招致常数级代价，时程 $T$ 的轨迹期望代价差为

$ |J(pi) - J(pi^*)| = O(epsilon T^2), $ <eq:bcbound>

即 BC 的次优性随时程*二次增长*——「误差复合」的经典结论，也是长时程任务上朴素 BC 崩溃的理论根源。按式 @eq:bcbound，任务长度加倍意味着难度约乘四——「抓取」与「收拾一间厨房」对 BC 是两个数量级不同的问题。

DAgger 的修复极为朴素：让学习者*自己*跑轨迹，遇到的状态由专家补标动作，数据聚合后重训 @ross2011dagger。理论保证：若监督学习器在累积数据上无后悔，性能界就降为 $O(epsilon T)$——DAgger 不是消除错误，而是*预演错误*。代价是需要可反复查询的在线专家，故其在软件域廉价、在物理域昂贵。这预示了后文两条路线的分工：提升 BC 表达力，或让奖励替代专家成为监督源。

=== Diffusion Policy：用生成建模重做模仿学习

Diffusion Policy 是模仿学习 2023 年后的分水岭 @chi2023diffusionpolicy。其核心观察是：演示的动作分布本质上是*多模态*的，回归式 BC 对多模态分布取均值会产生两边都不对的折中动作；而条件去噪扩散过程可以原样表达多峰分布。策略不再输出单步动作，而是对长度 $H$ 的动作序列 $A_t$ 做去噪生成，训练目标是噪声预测

$ cal(L)_"DP" (theta) = EE_(k\, epsilon\, (O_t, A_t^0) tilde cal(D)_E) [ norm(epsilon - epsilon_theta (sqrt(bar(alpha)_k) A_t^0 + sqrt(1 - bar(alpha)_k) epsilon,\, k,\, O_t))^2 ], $ <eq:dp>

推理时从高斯噪声迭代去噪得到动作块，以滚动时域方式执行——只执行前若干步即重新规划，兼顾多模态表达与闭环反应性。这一表示直接成为 $pi_0$、GR00T、RDT 等动作头 VLA 的先声；且去噪过程天然支持引导采样，模仿得到的策略不必是学习终点，而可以是后续自我改进的*基座*——这是 §12.4 全部故事的前提。

== 机器人强化学习 <sec:rl>

强化学习直接以回报优化策略，不依赖专家、可超越人类演示，但样本复杂度是其物理化的天花板。仿真内，天花板被工程击穿：并行 GPU 仿真 + PPO @schulman2017proximal + 域随机化把腿足训练压缩到分钟级 @rudin2022walk，瓶颈从算力转移到奖励设计与任务生成 @ma2024eureka。真实世界则是另一本账：episode 以秒计、不能批量重置、还有磨损与安全成本——五到六个数量级的吞吐落差决定真实世界 RL 只能是「精修」。转机出现在 2024 年前后：HIL-SERL 把人在环干预与样本高效的离策略在线微调结合，在电路板插装等精密任务上 1–2 小时真实训练即接近 100% 成功率 @luo2024hilserl；自主在线 RL 进一步把人也移出回路 @sharma2023selfimproving。

能否只用历史数据？离线 RL 的核心障碍是*外推误差*：Q 函数对分布外动作给出虚高估计，bootstrapping 又逐轮放大 @fujimoto2019offpolicy；CQL 等保守方法对未见动作的 Q 值施加惩罚 @kumar2020conservative。模型基方法则让策略在学到的世界模型潜空间中「想象」rollout @hafner2025dreamerv3 @wu2022daydreamer。两条线汇入同一叙事：*压缩真实交互的单价*。但结构性事实没变：RL 提供了*改进*的机制，却没有提供*先验*的来源——从零 RL 学通用操作仍不可行。这正是 VLA 的出场位置：先用 BC 蒸馏先验进权重，再用 RL 做边际改进。

== VLA 谱系 <sec:vla>

VLA 把视觉-语言模型的语义先验与动作生成整合进单一策略，谱系可按*动作表示*分为三代。*第一代是 token 式*：RT-1 首次证明「大规模真实数据 + 单一策略」可行 @brohan2022rt1；RT-2 把动作离散化为文本 token 与网页数据共同微调，确立 VLA 范式 @brohan2023rt2；开源的 OpenVLA（7B）在 Open X-Embodiment 约 97 万条轨迹上反超闭源 55B 的 RT-2-X @kim2024openvla @kim2025openvla_oft——但量化误差与自回归速度限制了高频精细控制。*第二代是 flow/diffusion 动作头*：$pi_0$ 以流匹配生成 50Hz 连续动作块 @black2024pi0；GR00T N1 面向人形机器人开源并提出「数据金字塔」配方 @bjorck2025grootn1；RDT-1B 统一了 46 个数据集的动作空间 @liu2024rdt。*第三代围绕「兼得」展开*：FAST 把动作序列压缩成频域 token 大幅提速 @pertsch2025fast；架构层面向*双系统*收敛——慢系统负责语义推理与规划、快系统负责高频反应式控制，$pi_0.5$ 首次展示端到端系统在未见真实住宅中完成收拾厨房等长时程任务 @pi2025pi05。对 RSI 而言，慢/快系统是*两个可分离的改进对象*，为「最小修改子集」提供了结构支点。

数据侧其一是跨形态汇集：Open X-Embodiment 汇集 22 种机器人形态、100 万余条轨迹，首次大规模证实跨形态正迁移（较单数据集基线高约 50%）@oxe2023。其二是数量级的绝望差距：轨迹数据与语言模型语料相差 5–6 个数量级，且轨迹*不可再生*——文本可以爬取，抓取轨迹必须逐条物理产生，这是后文「自动造数据」管线的根本动机。评估侧，主流基准几乎全是*成功率式、短视距*的静态测量——测「此刻的能力」而非「能力的变化率」；只有 SimplerEnv 认真校准仿真分数与真实表现的相关性 @li2024simplerenv。结论：静态成功率只能充当改进的*触发信号*，验收须依赖 held-out 分布与真实侧抽检。

== VLA 的自我改进路径 <sec:self-improve>

=== 路径一：RL 后训练与抗遗忘证据

把 agentic RL 的配方落到 VLA 上比 LLM 的 RLVR 更硬：动作连续高维，奖励稀疏，rollout 必须物理执行。VLA-RL 以轨迹级优势估计稳定信用分配，证明 RL 后训练可超过纯 SFT 上限 @lu2025vlarl；$pi_"RL"$ 为流匹配动作设计在线 RL 微调，使第二代 VLA 也能进入 RL 回路 @chen2026pirl；冻结的监督式检查点充当进度奖励与成功检测器，把「验证器」变成可学习模块 @ghasemipour2025selfimproving。真正改变格局的是 2026 年的*抗遗忘证据*：灾难性遗忘（后训练吃掉预训练先验，自我改进变成自我抹除）长期被视为 VLA 使用中学习的拦路虎。《Vision-Language-Action Models are Natural Continual Learners with Reinforcement Learning》发现：RL 微调天然缓解持续后训练中的遗忘——on-policy 采样把梯度约束在模型自身分布附近，不像 SFT 那样被外部数据强拉 @hu2026vlacl；独立团队同期给出同向证据 @vla2026noforget。本书推断：持续 RL 后训练可以作为默认的权重更新机制。

=== 路径二：PLD——三段式自我改进管线

PLD（Probe–Learn–Distill）是「VLA 自我数据收集」路线最完整的示范 @xiao2025pld，其结构（@fig:pld）如下。*探测（Probe）*：冻结 VLA 主干，在其输出上训练轻量残余 RL 专家专攻基策略的失败区——残余结构保证「改进」与「既有能力」参数隔离。*学习/采集（Learn）*：残余专家与基策略混合 rollout，自动采集成功数据；混合比例偏向基策略的高频状态，使新数据与部署分布对齐——相当于把 DAgger 的「在线专家」替换成了「自我训练的残余专家」。*蒸馏（Distill）*：新数据以 SFT 蒸馏回 VLA 权重，能力固化后残余专家退役，下一轮在更新后的 VLA 上重新探测新失败区。成绩包括 LIBERO 近饱和的 99%、SimplerEnv 提升 50 个百分点、真机 GPU 插拔连续 1 小时无人工干预 100% 成功 @xiao2025pld。

PLD 是 RoboCat 的成熟化 @bousmalis2023robocat：后者首次演示「自生成数据让下一代权重更强」，但只跑了一轮、任务由人选择；PLD 把任务定位、数据采集与固化全部自动化，且残余专家 + 蒸馏的交替结构天然支持多轮迭代——每轮残余专家只需学习*当前*通用模型的残余误差，问题难度随基座变强而自适应收缩。两个设计细节对本书有直接教益：残余专家是*可抛弃的探针*（通用权重只在蒸馏一步被动修改，回滚成本极低）；混合 rollout 的分布对齐把协变量偏移从「训练隐患」转化为「采集目标」。对照第 10 章的闭环要求，PLD 仍有三处敞口：*任务源*（失败区属于人给定的任务集）、*验收*（依赖人工抽查而非自动回归集）、*元层*（管线自身不学习）。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let acc = rgb("#0f5c5c")
    let acc2 = rgb("#8c5a2b")
    let sbg = rgb("#f6f4ef")
    let bbg = rgb("#eef3f5")
    rect((0, 1.7), (4.2, 3.5), radius: 0.15, fill: bbg, stroke: 1pt + acc)
    content((2.1, 3.12), text(size: 8.5pt, weight: "bold", fill: acc)[① Probe：残余 RL 探测])
    content((2.1, 2.6), text(size: 7.8pt)[冻结 VLA 主干，训练轻量残余])
    content((2.1, 2.18), text(size: 7.8pt)[RL 专家，专攻基策略失败区])
    rect((5.4, 1.7), (9.6, 3.5), radius: 0.15, fill: bbg, stroke: 1pt + acc)
    content((7.5, 3.12), text(size: 8.5pt, weight: "bold", fill: acc)[② Learn：自动数据采集])
    content((7.5, 2.6), text(size: 7.8pt)[残余专家 + 基策略混合 rollout，])
    content((7.5, 2.18), text(size: 7.8pt)[偏向高频状态做分布对齐])
    rect((10.8, 1.7), (15.0, 3.5), radius: 0.15, fill: bbg, stroke: 1pt + acc)
    content((12.9, 3.12), text(size: 8.5pt, weight: "bold", fill: acc)[③ Distill：蒸馏固化])
    content((12.9, 2.6), text(size: 7.8pt)[新数据 SFT 回通用 VLA 权重，])
    content((12.9, 2.18), text(size: 7.8pt)[能力固化后残余专家退役])
    line((4.2, 2.6), (5.4, 2.6), mark: (end: ">"), stroke: 1pt + acc)
    line((9.6, 2.6), (10.8, 2.6), mark: (end: ">"), stroke: 1pt + acc)
    line((12.9, 1.7), (12.9, 0.7), stroke: 1pt + acc2)
    line((12.9, 0.7), (2.1, 0.7), stroke: 1pt + acc2)
    line((2.1, 0.7), (2.1, 1.7), mark: (end: ">"), stroke: 1pt + acc2)
    content((7.5, 0.38), text(size: 7.8pt, fill: acc2)[下一轮迭代：在更新后的 VLA 上重新探测新的残余失败区])
    rect((0.8, 3.85), (14.2, 4.55), radius: 0.12, fill: sbg, stroke: 0.7pt + softline)
    content((7.5, 4.2), text(size: 8pt, fill: acc)[实测：LIBERO 99% · SimplerEnv +50pp · 真机插拔 1 小时无干预 100%])
  })),
  caption: [PLD（Probe–Learn–Distill）三段式自我改进管线],
) <fig:pld>

=== 路径三：世界模型 × VLA 的共进化

第三条路径把「试错」从物理世界搬进想象空间：RISE 让 VLA 同时学习组合式世界模型，策略在想象中试错改进，真机动态分拣达 95% @yang2026rise；VLAW 让 VLA 策略与世界模型迭代共改进 @guo2026vlaw。其深层贡献在于*验证器的模型化*：RoboReward 把通用视觉-语言奖励模型作为一等公民训练 @lee2026roboreward，Genie 3 类实时交互世界模型被定位为「训练具身智能体的仿真器」 @deepmind2025genie3 @wmrsurvey2026。本书推断，「世界模型当试验场 + 奖励模型当裁判 + VLA 当被改进对象」的三件套是具身 RSI 闭环最可能的近期形态。其软肋同样必须讲透：策略会学会利用世界模型的物理错误而非提升真实能力——外推误差 @fujimoto2019offpolicy 在递归设定下的复活；想象与真实的偏差如何被定期校正，目前没有任何工作给出保证。

== 在 Embodied RSI 框架中的角色 <sec:role>

回到第 10 章的四元组 $(cal(H), Theta, Phi, E)$：本章技术可精确安放为 *VLA 是被改进对象 $Theta$，harness $cal(H)$ 是包裹它的数据-训练-部署基础设施，$Phi$ 沿四条通道作用于 $Theta$，$E$ 由基准与奖励模型共同承担*。*数据通道*：PLD 的混合 rollout 采集 @xiao2025pld、跨形态汇集 @oxe2023、数据金字塔 @bjorck2025grootn1，都是对 $cal(D)$ 的自动扩充。*奖励通道*：HIL-SERL 的人工干预信号 @luo2024hilserl、RoboReward 的奖励模型 @lee2026roboreward、Eureka 式 LLM 奖励合成 @ma2024eureka 为 RL 后训练供监督——奖励模型的校准性直接决定这条通道的诚实度。*课程通道*：残余 RL 专家对失败区的自动定位 @xiao2025pld、RoboGen 式任务生成 @wang2024robogen，是「下一步练什么」的自动化，也最不成熟。*结构通道*：FAST 分词器、双系统分层、动作专家的挂载 @pertsch2025fast @bjorck2025grootn1 属于对 $Theta$ 结构的修改 $m$，目前由人完成。两点结构性观察：四条通道的验收都收敛到「held-out 基准 + 真实侧抽检 + 奖励模型」的同一验证底座，使 $E$ 成为复用度最高也最脆弱的组件；双系统与残余专家机制则为「修改的权限分级」提供了天然接口——快反射层适合自动更新，慢推理层适合人审更新。最后必须诚实标注差距：现有系统无一达到经独立验证的递归增益（L5） @zhou2026physicalrsi，17 个 agent 主导改进的系统中仅 1 个在提拔改动前跑回归测试 @wang2026agenticrobotics；抗遗忘证据消解了「权重持续更新」的旧障碍 @hu2026vlacl，但因果归因、跨代回归测试、真实世界验证吞吐仍是组装完整闭环时最先撞上的三堵墙。

== 本章小结

#keybox(title: [本章要点])[
- BC 的协变量偏移使次优性随时程二次增长（$O(epsilon T^2)$）；DAgger 以在线专家降为线性；Diffusion Policy 以动作序列去噪生成表达多模态分布，是动作头 VLA 的先声。
- 机器人 RL 分工已定型：仿真内并行 PPO 预演，人在环在线 RL 收尾真实世界，离线桥梁与世界模型压样本复杂度。
- VLA 动作表示三代演化：离散 token（RT-2/OpenVLA）→ 流/扩散头（$pi_0$/GR00T/RDT）→ FAST 压缩与双系统分层；数据与语言模型差 5–6 个数量级。
- 三条自我改进路径：RL 后训练（伴抗遗忘证据）、PLD 三段式管线、世界模型 × VLA 共进化。
- 在 $(cal(H), Theta, Phi, E)$ 框架中 VLA 是 $Theta$；四条通道各有原型，但因果归因、回归测试与真实验证吞吐仍是闭环缺口。
]