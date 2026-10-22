#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 世界模型、任务生成与实验编排

本章处理具身 RSI 闭环中三个彼此咬合的基础设施问题：经验在哪里"预演"（世界模型）、任务从哪里来（无监督环境设计）、实验如何被投进有限算力与真机机时（编排）。三者构成同一条流水线：任务生成器"出题"，世界模型充当可查询的环境替身，编排器把每份预算花在信息量最大的 rollout 上。

== 世界模型：从 Dreamer 到 Genie 3

具身 RSI 的成本结构与纯软件域有本质差异：真实 rollout 消耗机时、磨损硬件、占用安全监督，物理时间不可加速。世界模型的核心价值正在于改变这一成本结构——把"在环境中试错"替换为"在学到的模型中试错"。自 World Models @ha2018worldmodels 以降，Dreamer 系列将其发展为可扩展算法家族 @hafner2020dreamer @hafner2025dreamerv3，核心是循环状态空间模型（RSSM）：

$ h_t = f_psi (h_(t-1), s_(t-1), a_(t-1)), quad hat(s)_t tilde p_psi (s_t | h_t), quad s_t tilde q_psi (s_t | h_t, x_t) $ <eq:rssm>

策略与价值函数完全在潜空间想象展开上训练，全程不触碰真实环境。DreamerV3 以单一超参跨越 150 余任务并从零在 Minecraft 挖到钻石 @hafner2025dreamerv3；DayDreamer 把同一思路部署到真实机器人（四足一小时学会行走，无仿真器）@wu2022daydreamer。2025 年以后，Dreamer 4 证明仅从约 2500 小时录像即可离线学得世界模型 @hafner2025dreamer4，Genie 3 实现实时可交互、分钟级一致性的"生成模型即环境" @deepmind2025genie3，RISE 让 VLA 与世界模型共学习 @yang2026rise。评价这条谱系，本书建议以"每单位能力增益所需真实样本数"为贯穿度量轴：RSI 闭环的可持续性是其极限形式——第 $k$ 轮改进所需真实交互随 $k$ 衰减而能力增益不衰减，闭环才有长期运转的可能（本书推断）。

=== 世界模型在 RSI 闭环中的三重角色

本书提出，世界模型应被理解为"可查询的环境替身"，在 RSI 闭环中系统性承担三重角色。

其一，*预验证*。候选修改在消耗真实资源前先在世界模型中受控 rollout 评估，与第 6 章发布门控构成两级漏斗：预验证以极低边际成本淘汰明显劣化或危险的候选。RegenHarness 的证据门控协议是这一思想在机器人 harness 上的实现形态 @wang2026regenharness。

其二，*反事实归因*。"若第 $t$ 步动作换成 $a'_t$ 会怎样？"世界模型允许从失败轨迹的编码状态出发做分支 rollout、比较结局差异，把失败归因 @zhang2025whowhen 从"读日志推理"升级为"受控反事实实验"（本书推断）。当前模型分钟级的长程一致性尚不足以支撑接触级反事实，这是现实边界。

其三，*数据放大*。世界模型把有限真实数据压缩为可无限采样的生成器，使第 $k$ 轮改进的成本与真实交互近似解耦，瓶颈从"机时"转移为"模型保真度" @hafner2025dreamer4。

三重角色共享同一根本风险：*模型利用*——策略与评估都会利用世界模型的误差，预验证通过不等于真实通过；缓解手段包括不确定性感知惩罚、定期真实校准、以及"只否决、不批准"的保守用法（本书推断）。

== 无监督环境设计与任务生成

RSI 闭环要持续运转，必须持续获得"难而可解"的新任务。无监督环境设计（UED）把任务供给本身变成优化问题：设环境参数空间 $Theta$，折扣回报为 $J(pi, theta)$，决策理论锚点是最小化最大遗憾：

$ "REGRET"(pi, theta) = max_(pi') J(pi', theta) - J(pi, theta), quad pi^* = argmin_(pi) max_(theta in Theta) "REGRET"(pi, theta) $ <eq:minimax>

PAIRED @dennis2020paired 将其实现为三方博弈：对抗生成器生成环境 $theta$，主角 $pi$ 与对照者 $pi'$ 分别求解，生成器最大化遗憾代理 $J(pi', theta) - J(pi, theta)$；在纳什均衡处主角恰为 minimax regret 策略。机制设计的关键在于：直接最大化难度会奖励不可解环境（域随机化 @tobin2017dr 的固有退化），而最大化遗憾只奖励"别人能解、我不能解"的环境，不可能任务因双方回报同为零而天然被排除。PAIRED 最重要的遗产是一条原则：课程生成器必须是博弈论意义上理性的，而非任意的难度最大化器；其局限是生成器训练昂贵且易熵塌缩。PLR @jiang2021plr 去掉生成器，按遗憾代理对关卡回放缓冲加权采样，回放本身保有 minimax regret 鲁棒性保证 @jiang2021replay，但不能产生新关卡；ACCEL @parkerholder2022accel 对高遗憾关卡施加随机编辑变异再放回缓冲，以低约一个量级的算力逼近 POET 式环境—策略共进化 @wang2019poet。关键启示：变异—筛选式课程比从头生成稳定得多，且可堆叠在任意域随机化池之上。需诚实记录的是，"No Regrets"研究 @rutherford2024noregrets 证明常用遗憾代理实际与成功率而非真遗憾相关，并改按可学性前沿 $p(1-p)$ 采样：课程信号的估计质量本身就是闭环瓶颈。

2023 年以后，基础模型改写任务生成器形态：OMNI 用 LLM 蒸馏的"有趣性模型"选择有趣且当前可学的任务 @zhang2024omni；OMNI-EPIC 让基础模型直接生成可执行环境代码，把任务空间扩展到程序空间 @faldor2025omniepic；具身侧有 RoboGen、GenSim 等平行发展 @wang2024robogen @wang2024gensim。生成器自身的评估可用三条判据（本书提出）：覆盖度增长、可学性命中率稳定性、以及迁移增量（新课程策略在独立真实任务集上的表现增量，是最终外部证据）。


本书推断，2026 年最重要的结构性变化是 UED 向世界模型合流：OMNI-EPIC 用代码、Genie 3 用生成模型生成环境 @deepmind2025genie3，共享"环境程序"这一中间表示；世界模型又天然携带课程信号（不确定性指示可学之处、想象 rollout 成功率估计可学性前沿、反事实分支即最小成本关卡变异），足够好的世界模型可同时"出题"与"判卷"。代价是反馈自指风险：出题者与判卷者同为该模型时，课程可能被模型盲区带偏，必须在外部保留独立真实评估锚点 @zhou2026physicalrsi。

== 实验编排：带假设的受控 rollout 集合

#definition(title: [实验（本书提出）])[
一个*实验* $e = (cal(H), theta, pi_"cand", B, "prot")$ 是带假设的受控 rollout 集合：$cal(H)$ 为可证伪假设，$pi_"cand"$ 为受试对象，$B$ 为预算（rollout 数、墙钟时间、真机槽位），$"prot"$ 为协议（种子、初始状态分布、成功判据、安全终止条件）。实验的产物不是单一标量而是证据：轨迹、结局分布与置信区间。rollout 是执行的单位，实验是决策的单位。
]

编排器面对实验队列，目标是最大化单位预算下闭环获得的总证据价值，承担四项职责（本书提出）。*队列*：按期望信息价值、依赖关系（预验证未过者不得进真机队列）与截止时间排序，且可审计。*并行*：现代仿真器 @isaaclab2025 @tao2025maniskill3 @genesis2024 @freeman2021brax 提供单卡数万至数十万步每秒吞吐；agentic RL 基础设施的教训是，编排层瓶颈往往在版本管理与异构资源间的数据搬运而非仿真本身 @agentrl2025 @rollart2025。*预算*：实验须先用尽上一级保真度资源的证据才获准消耗下一级——多保真度序贯决策。*隔离*：实验间容器与版本隔离、评估侧与受试侧隔离——受试对象一旦能写代码，隔离失效即 reward hacking 入口 @wang2026harnesstampering。此外每个实验须绑定受试对象、环境/世界模型、评估器版本与种子的*版本指纹*，否则纵向轮次间无法公平比较，回流证据亦不可审计。

编排器是贝叶斯实验设计 @chaloner1995bayesian @lindley1956measure 的执行器：选择实验时最大化期望信息增益

$ "EIG"(e) = EE_(y tilde p(y | e)) [ D_"KL" ( p(psi | y, e) || p(psi) ) ] $ <eq:eig7>

队列优先级即"单位成本 EIG"的贪心排序，贝叶斯优化 @shahriari2016taking 为昂贵真机实验提供序列决策策略。两点衔接（本书推断）：世界模型为 EIG 提供廉价预测分布 $p(y | e)$，同时充当实验执行场地与实验设计的预测先验；而可学性前沿 $p(1-p)$ 恰好是参数辨识信息量最大的区域——课程设计与实验设计在数学上指向同一个采样分布。@fig:pipeline 汇总流水线结构。

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let b1 = (radius: 0.12, stroke: 0.8pt + accent, fill: softbg)
    let b2 = (radius: 0.12, stroke: 0.8pt + accent2, fill: bluebg)
    rect((0, 3.0), (2.5, 4.2), ..b1, name: "gen")
    content("gen", text(size: 8pt)[任务生成器\ UED / LLM\ （第 7.2 节）])
    rect((3.1, 3.0), (5.7, 4.2), ..b2, name: "orch")
    content("orch", text(size: 8pt)[实验编排器\ 队列·并行·预算·隔离])
    rect((6.3, 4.9), (9.5, 5.8), ..b1, name: "execc")
    content("execc", text(size: 8pt)[世界模型想象\ （近零成本）])
    rect((6.3, 3.6), (9.5, 4.5), ..b1, name: "execb")
    content("execb", text(size: 8pt)[GPU 仿真集群\ （高吞吐）])
    rect((6.3, 2.3), (9.5, 3.2), ..b1, name: "execa")
    content("execa", text(size: 8pt)[真机槽位\ （稀缺·门控）])
    rect((10.0, 3.0), (12.6, 4.2), ..b1, name: "eval")
    content("eval", text(size: 8pt)[评估与失败归因\ 独立评估器 $E$])
    line("gen.east", "orch.west", mark: (end: ">"), stroke: 0.7pt)
    line("orch.east", "execc.west", mark: (end: ">"), stroke: 0.7pt)
    line("orch.east", "execb.west", mark: (end: ">"), stroke: 0.7pt)
    line("orch.east", "execa.west", mark: (end: ">"), stroke: 0.7pt)
    line("execc.east", "eval.north-west", mark: (end: ">"), stroke: 0.7pt)
    line("execb.east", "eval.west", mark: (end: ">"), stroke: 0.7pt)
    line("execa.east", "eval.south-west", mark: (end: ">"), stroke: 0.7pt)
    line("eval.south", (11.0, 1.2), (1.2, 1.2), "gen.south", mark: (end: ">"), stroke: (dash: "dashed", paint: accent2, thickness: 0.8pt), name: "back")
    content((6.1, 0.8), text(size: 8pt, fill: accent2)[回流：数据放大 · 课程更新（遗憾/可学性） · 改进算子 $Phi$ 的新假设])
    line("execc.south", "execb.north", mark: (end: ">"), stroke: 0.6pt + gray.darken(20%))
    line("execb.south", "execa.north", mark: (end: ">"), stroke: 0.6pt + gray.darken(20%))
    content((7.7, 2.05), text(size: 7.5pt, fill: gray.darken(30%))[证据足够才升级保真度])
  }),
  caption: [任务生成 → 编排 → 分层执行 → 评估回流流水线。执行层按保真度分三级；赭色虚线为回流通道，把评估证据送回生成器与改进算子。],
) <fig:pipeline>

== 具身场景的特殊问题

具身 RSI 的执行层是一条保真度阶梯：世界模型想象 → 轻量物理 → 高保真物理加渲染 → 真机，相邻层级单步成本相差二至六个数量级，sim-to-real 差距使低保真证据预测力有限 @song2025mindthegap。编排器面对带相关性的多保真度背包问题，本书提出两条原则。第一，*低保真否决、高保真批准*：低层只用于淘汰（假阳性可容忍、假阴性不可容忍），批准权保留给最高可负担层级。第二，*预算向不确定性集中*：已取得高置信结论的实验不再追加预算，省下机时投向后验方差大者——正是 EIG 排序（@eq:eig7）在分层执行上的投影。阶梯不是静态的：编排器应维护*校准回路*（本书提出），定期用真机结果在各级低保真环境重放同一协议，把预测分歧度作为该级证据的折扣因子——每级阶梯由此获得随时间更新的"可信度价格"。

真机机时是最稀缺、不可加速且不可回滚的资源。其一，真机槽位按稀缺资源门控准入：只有携带完整低保真证据链、预声明成功判据与回滚预案的实验才能占用——AutoRT 的机器人队列为机队级编排的早期范式 @ahn2024autort。其二，统计分析必须小样本化，高置信度策略评估 @thomas2015high 应作标准组件。其三，每条真机轨迹应同时服务评估、世界模型校准与数据放大三重用途。此外两个常被忽略的成本项（本书提出）：*复位成本*——episode 间恢复场景往往比执行更耗时，协议应偏好"自复位任务链"；*损耗预算*——硬件磨损与安全员工时应计入 EIG 排序的成本分母，否则队列会系统性偏好"危险但信息量大"的实验。

当受试对象是能改写自身行为的系统时，编排器同时是最后一道安全边界，必须内建三类先于效率优化的联锁（本书提出）：*执行联锁*（真机 rollout 在独立运行时监视器下执行 @reachability2025llmrobot，违规即硬中断，不依赖受试策略配合）、*证据联锁*（状态提交与完成声明分离，更新者无权弱化自己的验收谓词 @wang2026regenharness）、*评估联锁*（评分与日志对受试对象只读 @wang2026harnesstampering）。Physical RSI 的 L0–L5 分级 @zhou2026physicalrsi 留下的三个未解决问题决定下一阶段格局：世界模型预验证的可信度校准、机器人域大规模可验证奖励来源的缺失、编排器自身可改进性的边界。

== 本章小结

本章沿"出题—预演—执行"流水线重构三个主题：世界模型把策略改进的边际成本从真实交互转移到模型内想象 @ha2018worldmodels @hafner2025dreamerv3 @deepmind2025genie3，在闭环中承担预验证、反事实归因与数据放大三重角色，边界是模型利用风险；任务生成以 minimax regret 为锚点 @dennis2020paired，PLR/ACCEL 给出低成本实现 @jiang2021plr @parkerholder2022accel，遗憾代理失真已被修正 @rutherford2024noregrets，OMNI/OMNI-EPIC 把任务空间扩展到语言与程序并与世界模型合流 @zhang2024omni @faldor2025omniepic；实验编排器是 EIG 驱动的贝叶斯实验设计执行器 @chaloner1995bayesian，具身场景叠加保真度阶梯、真机稀缺与安全联锁三重约束。

#keybox(title: [本章要点])[
- 世界模型是闭环的"成本结构"：预验证、反事实归因、数据放大三重角色共享模型利用风险，保守用法是"低保真否决、高保真批准"。
- UED 的正确目标是 minimax regret 而非难度最大化；遗憾代理已被证明与成功率相关失真。
- 任务生成器与世界模型正合流为同一"环境程序"表示；须外部保留独立真实评估锚点以防反馈自指。
- 实验 = 带假设的受控 rollout 集合；编排器按单位成本 EIG 排序，预算沿保真度阶梯逐级释放。
- 具身编排三硬约束：多保真度背包、真机槽位门控、安全联锁先于效率。
]
