#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= LLM 驱动的机器人实验自动化：从奖励设计到闭环系统

本章把前面各章的 RSI 概念落到一个实证战场：*LLM 如何把机器人学中的实验自动化掉*——设计奖励函数、生成任务与场景、合成监督信号、编排真实数据收集、乃至改写训练代码。2022 年 SayCan 把 LLM 用作开环任务规划器 @ahn2022saycan；到 2026 年 10 月，EmbodiedRSI、SEAR 与 Physical RSI 立场论文同月出现，"LLM 作为机器人实验者"已自命名为一个子领域 @song2026embodiedrsi @wang2026sear @zhou2026physicalrsi。本章依次给出三级角色框架与谱系、Eureka 与 DrEureka 的实质分析、七段闭环覆盖矩阵、2026 下半年爆发的解读与四个缺失环节。

== 谱系总览：从 LLM 作规划器到 LLM 作实验者

完整的具身 RSI 闭环含七段：①*任务/课程提议*；②*监督信号合成*；③*策略训练*；④*执行与验证*；⑤*经验固化*（权重、代码、技能库、记忆）；⑥*元改进*（改进流程自身的更新）；⑦*安全护栏*。本章以此七段为统一坐标系。

#definition(title: [LLM 在具身闭环中的三级角色])[
*L-P（规划器）*：LLM 只出现在执行时的任务分解层，学习发生在环外（如 SayCan）；*L-C（组件设计者）*：LLM 离线设计闭环某一环节的工件（奖励代码、任务配置、DR 分布），验证器通常是可执行环境（如 Eureka、RoboGen）；*L-E（实验者）*：LLM agent 自主提议假设、运行实验、读取反馈并决定下一步（如 ENPIRE、EmbodiedRSI）。三级的本质区别在于：谁拥有"下一步做什么实验"的决策权。
]

*三代系统。* 第一代（2022，L-P）确立了"语言模型可以接地到机器人"——SayCan 用"有用度×可供性"相乘选技能 @ahn2022saycan，CaP/VoxPoser 让 LLM 生成策略代码与三维价值图 @liang2023cap @huang2023voxposer——但每条指令开环：执行成败不回流为任何持久更新。第二代（2023–2024，L-C）自动化闭环单段组件：Eureka/DrEureka 的奖励与 DR 进化 @ma2024eureka @ma2024dreureka（§13.2 详析）、RoboGen/GenSim 的任务—场景—监督生成 @wang2024robogen @wang2024gensim、AutoRT 编排 20 余台机器人收集 7.7 万条真实 episode @ahn2024autort、RoboCat 首次演示权重级自我改进 @bousmalis2023robocat；游戏域 Voyager 的"自动课程+技能库+自我验证"是 L-E 设计的概念原型 @wang2023voyager。第三代（2025–2026，L-E）中 agent 指导改进过程本身：ENPIRE 直接修订训练代码 @xiao2026enpire，RHO/HARBOR 把 harness 变为优化对象 @elmaaroufi2026rho @li2026harbor。Agentic Robotics 综述给出独立佐证：*17 例 agent 主导的改进（相当于 L-E）中 16 例出现在 2026 年* @wang2026agenticrobotics。谱系见 @fig:timeline13。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let acc = rgb("#0f5c5c")
    let acc2 = rgb("#8c5a2b")
    let sl = rgb("#d9d4c8")
    // 时间轴：2022 初 → 2026.10
    let tx = (t) => 0.6 + (t - 2022.0) / (2026.85 - 2022.0) * 13.8
    // 三条泳道：L-P（上）、L-C（中）、L-E（下）
    let lanes = ((6.2, [L-P 规划器]), (3.7, [L-C 组件设计者]), (1.2, [L-E 实验者]))
    for (y, name) in lanes {
      line((0.5, y), (14.5, y), stroke: 0.5pt + sl)
      content((0.1, y), anchor: "west", text(size: 7.5pt, fill: acc, weight: "bold")[#name])
    }
    // 刻度
    for yr in (2022, 2023, 2024, 2025, 2026) {
      let x = tx(yr + 0.0)
      line((x, 0.45), (x, 6.85), stroke: 0.35pt + sl)
      content((x, 0.15), text(size: 7pt, fill: gray.darken(20%))[#str(yr)])
    }
    content((14.75, 0.08), anchor: "east", text(size: 7pt, fill: gray.darken(20%))[2026.10])
    // 系统散点：(时间, 泳道 y, 名, 标签 x, 标签 y)
    let sys = (
      (2022.30, 6.2, [SayCan], 2.1, 6.48), (2022.55, 6.2, [InnerMon.], 2.5, 5.78), (2022.72, 6.2, [CaP], 3.0, 6.48), (2023.52, 6.2, [VoxPoser], 5.0, 6.48),
      (2023.40, 3.7, [Voyager], 3.7, 3.98), (2023.45, 3.7, [RoboCat], 3.6, 3.28), (2023.75, 3.7, [Eureka], 4.9, 3.98), (2023.78, 3.7, [GenSim], 5.2, 2.95),
      (2023.85, 3.7, [RoboGen], 5.3, 4.32), (2024.05, 3.7, [AutoRT], 6.1, 3.28), (2024.45, 3.7, [DrEureka], 6.6, 3.98), (2024.75, 3.7, [GenSim2], 7.0, 2.95),
      (2025.70, 3.7, [SE-FM], 10.5, 3.98),
      (2026.10, 1.2, none, 0, 0), (2026.48, 1.2, none, 0, 0), (2026.50, 1.2, none, 0, 0),
      (2026.75, 1.2, none, 0, 0), (2026.77, 1.2, none, 0, 0), (2026.78, 1.2, none, 0, 0),
    )
    for (t, y, name, lx, ly) in sys {
      let x = tx(t)
      circle((x, y), radius: 0.07, fill: if y > 5 { acc2 } else if y > 2 { acc } else { rgb("#a04a3a") }, stroke: none)
      if name != none {
        content((lx, ly), text(size: 6.5pt, fill: ink)[#name])
      }
    }
    // 2026 下半年标签集中在一行，避免与散点争空间
    content((7.6, -0.55), text(size: 7pt, fill: gray.darken(25%))[2026 H2：RISE · ASPIRE · RSIGym · EmbodiedRSI · SEAR/EmbodiedEvo · ENPIRE/RHO/HARBOR])
    content((7.5, 7.25), text(size: 8pt, fill: gray.darken(30%))[2022 → 2026.10：LLM 在具身闭环中的角色从规划器（棕）经组件设计者（青）迁移到实验者（红）])
  })),
  caption: [系统谱系时间线（2022 → 2026.10）。纵轴为三级角色；L-E 泳道在 2026 年下半年急剧加密，与综述的统计吻合 @wang2026agenticrobotics。],
) <fig:timeline13>

提醒："闭环了一段"≠"闭合了整环"：Physical RSI 立场论文的 L0–L5 审计结论是*现有系统尚未达到其框架定义下的 Physical RSI* @zhou2026physicalrsi。

== Eureka 与 DrEureka：可执行验证器驱动的组件进化

*Eureka（ICLR 2024）*是本章最重要的系统：它第一个证明*当验证器可执行时，LLM 可以在机器人学习组件上做出超越人类专家的自动化设计* @ma2024eureka。方法：把奖励函数 $r(s, a)$ 表示为可注入环境源码的可执行代码，用 LLM 做进化式搜索；关键创新是*奖励反射*——把各奖励分量的数值轨迹、策略回报与成功指标整理成文本摘要，反馈给 LLM 作为变异依据。结果：Isaac Gym 29 个任务、10 种机器人形态中 83% 的任务生成奖励优于人类专家（平均 +52%），并实现 Shadow Hand 转笔等灵巧行为。算法思想如下（据原文算法 1 重构）。

```python
# Eureka：LLM 驱动的奖励进化（据原文算法 1 重构）
def eureka(env_code, task_desc, T=5, K=16):
    pool = llm.sample_rewards(env_code, task_desc, n=K)   # 零样本生成 K 个奖励代码
    best = None
    for t in range(T):
        stats = []
        for r in pool:                                     # 每个候选：可执行验证
            if not compiles(r): stats.append((r, -inf, "")); continue
            pi = train_ppo(isaac_gym, reward=r)            # GPU 并行，分钟级
            F = fitness(pi)                                # 任务适应度（如成功率）
            refl = reward_reflection(r, pi)                # 分量值/回报/成功指标摘要
            stats.append((r, F, refl))
        stats.sort(key=lambda x: -x[1])
        best = max(best, stats[0], key=lambda x: x[1]) if best else stats[0]
        # 上下文内进化：top 候选 + 奖励反射 → 下一代变异
        pool = llm.mutate(stats[:m], reflections=[s[2] for s in stats], n=K)
    return best                                            # (r*, F*, 反思记录)
```

用本书记号，Eureka 求解的是
$ r^* = argmax_(r in cal(R)_"llm") F(r), quad F(r) = EE_(tau ~ pi_theta^(r))[G(tau)], $ <eq:eureka>
其中 $cal(R)_"llm"$ 是 LLM 可表达的奖励代码空间。与经典进化策略的区别不在搜索算子，而在*变异算子是语义的*：奖励反射把数值反馈翻译成自然语言，使变异有方向。从闭环坐标系看，Eureka 闭环了②×③×④，且④的验证器是环境本身：可执行、免人工、无校准问题——这正是它成为后续工作之锚的原因。局限：任务集固定（缺①）、每任务产一件奖励工件即停（⑥仅有弱形式）、无真实世界验证 @wang2026agenticrobotics。

*DrEureka（RSS 2024）*把搜索对象从奖励扩展到"奖励 + 域随机化（DR）分布"，直击 sim-to-real 手工调参环节 @ma2024dreureka。难点：奖励与 DR 分布耦合使人工调参代价极高，而 LLM 直接搜索 DR 参数会因物理盲选频繁产生不可学的配置。关键方法是先训*奖励感知物理先验*（RPA）策略并对物理参数做敏感性扫描，只把"奖励敏感"的参数子集交给 LLM 设计随机化区间；随后沿用同一进化环联合搜索，即 @eq:eureka 的推广 $(r^*, phi^*) = argmax_(r, phi) F_"dr"(r, phi)$。结果：四足瑜伽球平衡行走、上坡越障等新任务无需人工调参即完成 sim-to-real，成功率与人工专家相当或更高。局限：RPA 仍依赖人工仿真管线；真实侧只有一次"终验"，没有"真机失败 → 修改仿真参数"的回流。

其余系统在七段坐标中的位置与天花板：Text2Reward/L2R 证明奖励代码可横跨"RL 训练"与"MPC 直接用"两种管线 @xie2024text2reward @yu2023l2r；RoboGen 首次串起①②③段但技能不回流（缺⑥）@wang2024robogen；AutoRT 把①④推进到真实世界并最早实例化⑦（"机器人宪法"），但环只闭到"数据" @ahn2024autort；RoboCat 演示自生成数据训出更强下一代策略（权重级⑤），但只跑一轮、任务由人选 @bousmalis2023robocat；Self-Improving EFM 把④从环境解耦为可学习的冻结检查点 @ghasemipour2025selfimproving；ENPIRE 首次让 agent 迭代修订*训练管线本身*（触到⑥），但无 held-out 与回归测试 @xiao2026enpire。

#remark(title: [共同的结构性事实])[
*验证器的可得性决定了闭环能闭到哪一段。* 仿真内环节可免费执行，闭环就地成立；真实世界环节必须借道学到的奖励模型、冻结检查点、人工评分或限时 agent 监督。验证器从"环境免费赠送"到"必须被构造与被信任"的转变，是④段系统性缺口的根源。
]

== 七段闭环覆盖矩阵

逐篇分析压缩为一张矩阵（●= 实质性闭环；◐= 部分覆盖；—= 未覆盖）：行是系统，列是七段闭环外加"真实机器人"列。@tab:coverage 汇总十个代表系统。

#figure(
  table(
    columns: 10,
    inset: (x: 3.5pt, y: 2.6pt),
    [系统（年份）], [①任务], [②监督], [③训练], [④验证], [⑤固化], [⑥元改进], [⑦安全], [真实], [闭环段],
    [SayCan '22 @ahn2022saycan], [—], [—], [—], [◐], [—], [—], [—], [●], [0.5],
    [Voyager '23 @wang2023voyager], [●], [◐], [—], [●], [◐], [◐], [—], [—(游戏)], [3.5],
    [Eureka '23 @ma2024eureka], [—], [●], [●], [●], [◐], [◐], [—], [—], [3.5],
    [RoboCat '23 @bousmalis2023robocat], [—], [●], [●], [●], [●], [—], [—], [●], [4],
    [RoboGen '23 @wang2024robogen], [●], [●], [●], [◐], [—], [—], [—], [—], [3.5],
    [AutoRT '24 @ahn2024autort], [●], [—], [—], [●], [—], [—], [◐], [●], [2.5],
    [DrEureka '24 @ma2024dreureka], [—], [●], [●], [●], [◐], [—], [—], [●], [3.5],
    [ENPIRE '26 @xiao2026enpire], [◐], [●], [●], [●], [●], [●], [—], [●], [5.5],
    [HARBOR '26 @li2026harbor], [◐], [◐], [●], [●], [●], [●], [—], [◐], [5],
    [EmbodiedRSI '26 @song2026embodiedrsi], [●], [—], [—], [●], [●], [●], [—], [●], [5],
  ),
  caption: [七段闭环覆盖矩阵（本书整理；依据各原文与 2026 年综述审计 @wang2026agenticrobotics）。"闭环段"列按 ● 计 1、◐ 计 0.5 粗略求和，仅作密度指示。],
) <tab:coverage>

三个读法。第一，*每一列都至少有一个 ●*——这就是"各段皆有原型"。第二，*没有任何一行全部 ●*，且覆盖率最高的 2026 年系统恰在证据纪律列失分：ENPIRE 无 held-out 与回归测试，HARBOR 的等预算对照（迄今唯一一次"agent 主导 vs 固定流程"实验）未能证明 agent 主导更优 @li2026harbor。第三，*⑦列近乎全空*——安全护栏从未被集成进自改进环。这就是"整环无人闭合"。三份独立证据背书：Physical RSI 的 L0–L5 审计（无系统达 L5 @zhou2026physicalrsi）、评估审计论文（多数证据只证明*产物*变好，未证明*递归过程*变强 @chen2026auditing）、综述统计（17 例 agent 主导改进中仅 1 例提拔前跑回归测试 @wang2026agenticrobotics）。

【本书推断】①×⑤×⑥×真实④的四元组合最难，原因在成本结构的乘法性：自主课程承担课程风险方差，权重固化每次付出全量训练成本，真实验证按"秒/条"付费且不可逆，元改进要求归因到流程级改动——四者预算互相相乘，而轨迹数据不可再生（与语言语料差 5–6 个数量级 @oxe2023 @khazatsky2024droid）。仿真吞吐已不再是瓶颈，瓶颈上移到"自动监督的合成"与"真实世界的验证吞吐"。

== 2026 下半年爆发：系统密度的爆发，不是证据等级的爆发

2026 年 7–10 月该方向自命名为子领域，10 月单周内五个系统集中出现（本节数字均为原文自报口径）。

*EmbodiedRSI（2026-10）*是"harness 自进化"目前最强的实证 @song2026embodiedrsi：围绕冻结机器人基础模型的自进化 agentic harness——假设图维护相互竞争的代码/技能假设，*信息价值（VoI）实验选择*挑选最能区分假设的物理实验，代码-技能-记忆协同进化。结果：RoboCasa365 总成功率 77.0%（最强基线 40.1%），零样本迁移真机 71.3%。它示范了长期被忽视的*实验选择*环节：①段从"生成更多任务"升级为"选择信息量最大的实验"；基础模型冻结则意味着改进完全发生在 harness 层，与软件域"权重冻结、脚手架进化"路线同构 @zhang2025dgm。

*EmbodiedEvo（2026-10）*让自进化 coding agent 直接作为闭环策略 @li2026embodiedevo：episode 内经验蒸馏为可复用代码 Skills 与诊断 Lessons 并跨模型迁移（强模型经验提升弱执行器 5.5–8.9 个百分点），RoboDojo-Sim 成功率 37.82% 登顶，执行成本降 53%；作者自陈未隔离单一工件的因果效应。*RSIGym（2026-10）*把训练/推理/评测/沙箱打包成带预算与权限的服务（EaaS），支持数据/harness/联合三条改进轨道并配套 RSI-Index；最佳运行在 500 美元内把 SWE-bench Verified 从 17.7% 推到 50.3% @meng2026rsigym——轨道分离是对因果归因的第一个工程回应。

同期的 SEAR（330 仿真 + 5 真实任务 @wang2026sear）发现：简单任务上"重掷短尝试"与持续学习打平——*持续改进并非无条件划算*。RISE 以组合世界模型做"想象空间自我进化"（真机动态分拣 95% @yang2026rise）：④段的第三条路线，验证在与策略同源的想象里，自指风险需外部校准。横向看，自主闭环程度沿*改进对象的抽象层级*与*验证器的独立性*两轴拉开——改进对象越全局，验证归因越困难。审计论文与 L0–L5 分级共同判定：没有任何系统提供"递归过程本身在变强"的 L5 证据 @chen2026auditing @zhou2026physicalrsi。

== 缺失环节分析：从覆盖矩阵到协议需求

四个系统性缺失环节及其协议映射。

*缺失一：验证器校准。* 学到的验证器（RoboCat 奖励模型、冻结检查点、世界模型想象）解决了"有没有"，没解决"准不准"：未校准验证器产生自我欺骗式改进——系统优化的是验证器的错误而非任务本身 @skalse2022rewardhacking；世界模型路线还叠加同源训练的自指风险。协议映射：验证器须纳入泛化面板并周期性在独立真机标注子集上校准审计，想象验证与物理终验按预算比例交替。

*缺失二：因果归因。* harness、数据、奖励、权重同时可变时"哪个改动带来增益"无法归因：EmbodiedRSI 的消融停在组件级，EmbodiedEvo 自陈未隔离单一工件效应 @zhou2026physicalrsi。正面雏形：RSIGym 用权限边界强制归因，SEAR 用对照分离"经验留存"与"重复尝试"。协议映射：证据账本记录改动面与配对差分；*单因子提拔门*限制同轮改动的通道数。

*缺失三：回归测试与遗忘审计。* 17 例 agent 主导改进仅 1 例提拔前跑回归测试 @wang2026agenticrobotics；"持久修改 ≠ 持续改进"。权重通道的抗遗忘证据在 2026 年转暖（预训练 VLA 对持续学习遗忘相当鲁棒 @hu2026vlacl），但代码、记忆、技能通道的退化无任何系统做过跨代审计。协议映射：每个被提拔改动在*历史任务全集*上复测；泛化面板显式包含"代际面板"。

*缺失四：真实世界吞吐与不可逆性。* 真实 episode 以"秒/条"计费且有磨损与安全成本（ENPIRE 每轮 0.7–5 小时、亿级 token @xiao2026enpire）；不可逆后果要求护栏与自改进环集成（证据门控与版本化 rollout/rollback @wang2026regenharness），而这刚刚起步。协议映射：真实实验建模为带预算与风险约束的实验选择问题，改动提拔以其安全属性不被削弱为前提。

#remark(title: [四缺失的统一视角])[
四缺失的共同根源：*闭环的验证侧（④）没有跟上生成侧（①②③）的自动化*。生成侧成本已被 LLM 压到近零，验证侧成本由物理世界、统计噪声与归因困难刚性支撑；第 9、10 章协议的实质就是把验证侧工程化到同等自动化程度。
]

== 本章小结

本章沿 L-P → L-C → L-E 谱系审计了 2022–2026 年的代表系统。Eureka 证明可执行验证器就位时 LLM 能在奖励设计上超越人类专家（83% 任务、平均 +52%），DrEureka 把搜索扩到奖励+DR 并直通真机；覆盖矩阵给出核心判断——*各段皆有原型、整环无人闭合*；2026 下半年的爆发把⑤⑥推进到 harness 与代码层并示范了 VoI 实验选择，但①×⑤×⑥×真实④仍无示范，且无 L5 级递归增益证据；四个缺失环节映射到第 9、10 章协议，构成后续章节的实证动机。

#keybox(title: [本章要点])[
1. 三级角色：L-P → L-C → L-E；17 例 agent 主导改进中 16 例出现在 2026 年 @wang2026agenticrobotics。
2. Eureka 范式的精髓是*可执行验证器 + 语义变异算子*的进化环（@eq:eureka）；奖励反射使变异有方向。
3. 覆盖矩阵：各段皆有原型、整环无人闭合；⑦安全护栏覆盖最差。
4. 2026 爆发是系统密度而非证据等级的爆发：最强实证 EmbodiedRSI（77.0% vs 40.1% @song2026embodiedrsi）仍无 L5 证据。
5. 四缺失的共同根源是验证侧自动化落后于生成侧。
]
