#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 仿真基础设施与大规模并行实验

前面各章把具身 RSI 拆解为改进算子、评估协议、任务生成与实验编排，本章下沉到它们共同的物理底座：仿真。在具身 RSI 闭环中，仿真器不是"训练用的工具"，而是*可重复试验假设的工程实现*——第 7 章的每个"实验"最终都要实例化为某引擎上的一批并行 episode。2025–2026 年该底座发生结构性变化：MuJoCo/MJX、Isaac Lab、Genesis 与 Linux Foundation 托管的 Newton 完成引擎层"合流"，吞吐以数量级跃升，瓶颈上移到任务/监督合成与真实世界的验证吞吐。

== 仿真在 RSI 闭环中的位置

Physical RSI 的形式化 @zhou2026physicalrsi 把系统拆为任务执行系统 $(cal(H), Theta)$、改进程序 $Phi$ 与独立评估器 $E$，其中隐含执行载体问题：$Phi$ 提议的每个修改 $m$ 都须经受控试验才能被 $E$ 采信。物理域中唯一可无限重复、可随机化、可精确复位且廉价的试验场就是仿真，其 RSI 功能有三条：*可重复性*（同一假设可在统计独立的 episode 上重复评估，改进声明具备误差棒 @miller2024errorbars）、*可干预性*（物理参数与扰动皆为可编程变量）、*可扩展性*（吞吐只受算力约束）。真实世界三条全败：时间不可加速、状态不可复位、干预不可完全控制。

=== 吞吐 × 保真度 × 成本三角

仿真选型受三元权衡支配：*吞吐*（每秒环境步数）、*保真度*（接触/渲染/传感与真实的偏差）、*成本*（算力、许可证与工程人力），三者不能同时取极值。两次突破改变了三角的形状：Brax 把刚体动力学用 JAX 重写并与训练算法同设备编译 @freeman2021brax；Isaac Gym 把端到端驻留 GPU 的 RL 推到约 54 万步/秒（4096 环境、单张 A100）@makoviychuk2021isaacgym；MuJoCo Playground 在单 GPU 上报告含渲染的 CartPole 约 40.3 万步/秒 @mujoco_playground2025——吞吐顶点已高到多数研究问题不再受其约束。成本校准（本书推断）：一条仿真 episode 在 MJX 级引擎约 $10^(-4)$ 美元量级，含渲染的高保真栈约 $10^(-2)$ 美元量级，真实 episode 普遍在 1–10 美元量级，各差约两个数量级——编排器的目标因此天然是"单位真机成本的信息量"。当吞吐不再是瓶颈，闭环约束上移到任务/监督合成 @wang2024robogen @hua2024gensim2 与真实验证吞吐两处：*仿真从 RSI 的成本中心转变为假设消化器*，设计目标从"快"转向"可编程、可审计、可回流"（@fig:stack）。

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let layer = (radius: 0.12, stroke: 0.8pt + accent, fill: softbg)
    let layer2 = (radius: 0.12, stroke: 0.8pt + accent2, fill: bluebg)
    let head(y, t) = content((5.3, y), text(size: 7.3pt)[#t])
    // 四层栈（自下而上）
    rect((0, 0.2), (10.6, 1.6), ..layer, name: "l1")
    head(1.16, [*物理引擎层*：Newton · MuJoCo/MJX · Brax · PhysX · Genesis])
    head(0.72, text(size: 6.4pt, fill: gray.darken(30%))[MJWarp · Kamino · VBD/iMPM])
    rect((0, 2.0), (10.6, 3.4), ..layer, name: "l2")
    head(2.96, [*向量化层*：环境向量化 · GPU 驻留 rollout · 批量渲染 · 可微通道])
    head(2.52, text(size: 6.4pt, fill: gray.darken(30%))[vmap/数据并行 · Madrona/RTX])
    rect((0, 3.8), (10.6, 5.2), ..layer, name: "l3")
    head(4.76, [*编排层*：实验队列 · 异步调度 · 预算分配 · 随机化/DR 注入])
    head(4.32, text(size: 6.4pt, fill: gray.darken(30%))[陈旧度控制 · 保真度阶梯])
    rect((0, 5.6), (10.6, 7.0), ..layer2, name: "l4")
    head(6.56, [*agent / harness 层*：策略 · 改进算子 · 课程 · 独立评估器])
    head(6.12, text(size: 6.4pt, fill: accent2.darken(10%))[$pi_theta$ · $Phi$ · 任务生成 · $E$])
    // 下行：假设与配置
    line((5.3, 5.6), (5.3, 5.2), mark: (end: ">"), stroke: 0.8pt + accent2)
    line((5.3, 3.8), (5.3, 3.4), mark: (end: ">"), stroke: 0.8pt + accent2)
    line((5.3, 2.0), (5.3, 1.6), mark: (end: ">"), stroke: 0.8pt + accent2)
    content((5.3, 3.58), frame: "rect", fill: white, stroke: none, padding: 1pt, text(size: 7pt, fill: accent2)[假设 $m$ · 任务参数 · DR 分布 · 预算])
    // 上行：证据
    line((8.6, 1.6), (8.6, 2.0), mark: (end: ">"), stroke: (dash: "dashed", paint: accent, thickness: 0.8pt))
    line((8.6, 3.4), (8.6, 3.8), mark: (end: ">"), stroke: (dash: "dashed", paint: accent, thickness: 0.8pt))
    line((8.6, 5.2), (8.6, 5.6), mark: (end: ">"), stroke: (dash: "dashed", paint: accent, thickness: 0.8pt))
    content((8.6, 5.36), frame: "rect", fill: white, stroke: none, padding: 1pt, text(size: 7pt, fill: accent)[证据：轨迹 + 指标 + 渲染])
    // 真机
    rect((11.4, 0.2), (14.4, 1.6), radius: 0.12, stroke: 0.8pt + gray.darken(30%), fill: redbg, name: "real")
    content((12.9, 0.9), text(size: 7pt)[真实世界\ 验证吞吐瓶颈\ 不可复位/不可逆])
    line("l1.east", "real.west", mark: (end: ">"), stroke: 0.7pt + gray.darken(20%))
    content((12.9, 1.78), text(size: 7pt, fill: gray.darken(30%))[sim-to-real])
    // 真机回流
    line("real.north", (12.9, 6.3), "l4.east", mark: (end: ">"), stroke: (dash: "dashed", paint: gray.darken(30%), thickness: 0.7pt))
    content((13.05, 3.9), anchor: "west", text(size: 7pt, fill: gray.darken(30%))[真实证据\ 回流 $E$])
  }),
  caption: [仿真栈分层图（本书提出）：实线为假设与配置流，虚线为证据流；真实世界悬于栈外，其验证吞吐是闭环的最终瓶颈。],
) <fig:stack>

仿真证据应分三级采信（本书提出）：*机制性证据*——修改 $m$ 在受控条件下改变了学习动态，与域差基本无关；*排序性证据*——候选修改的优劣排序，经仔细对齐后可与真实排序显著相关 @li2024simplerenv，但对初始化分布与视觉差异敏感 @song2025mindthegap；*数值性证据*——直接预测真实性能数值，2026 年没有任何公开证据支持其跨域成立。把第二级当第三级使用是"自我欺骗式改进"最常见的来源。

== 引擎谱系与 2025–2026 合流

2025 年之前，GPU 仿真器沿三条谱系演化：*DeepMind 系*以 MuJoCo（凸接触模型，接触任务事实标准 @todorov2012mujoco）为根，衍生出 JAX 重写、可微可 vmap 的 MJX 及环境层 MuJoCo Playground @mujoco_playground2025；*NVIDIA 系*以 PhysX 为根，Isaac Gym 首创端到端 GPU 驻留 RL @makoviychuk2021isaacgym，经 Orbit @mittal2023orbit 演化为具备 manager-based API 与 DR 工具链的 Isaac Lab @isaaclab2025；*社区系*包括 Brax @freeman2021brax、ManiSkill3 @tao2025maniskill3 与统一多求解器的 Genesis @genesis2024（其宣传的 4300 万 FPS 开自碰撞后降至约 29 万）。引擎层的决定性事件是*合流*：Newton 作为 Linux Foundation 项目（NVIDIA × DeepMind × Disney Research）把 MuJoCo 接触模型的 Warp 原生实现（MJWarp）与 NVIDIA 的 GPU 编译基础设施放进同一框架，统一收容闭链与可变形体求解器，支持可微仿真 @kamino2026 @newton2025；Isaac Lab 3.0 把物理后端抽象化（PhysX/Newton 多后端）并与 RTX 渲染解耦 @isaaclab2025；MJX 一脉则证明"引擎可换、抽象层常驻"。合流对 RSI 有三点含义：*引擎锁定风险解除*（换引擎从重写工程变为配置切换，实验描述第一次可跨引擎移植）、*可微仿真平价化*（基于梯度的系统辨识不再需要自研求解器）、*治理集中化*（中立托管利于逐轮改进审计）。本书推断：引擎竞争焦点将从吞吐转向*证据导出能力*——这才是闭环验证真正消耗的东西。

== 大规模并行实验架构

GPU 时代并行化的关键转变是*环境即张量程序*：$N$ 个环境的状态堆叠为批次维度，一次内核调用推进全部环境——JAX 系用 `vmap` 编译期向量化 @freeman2021brax，PyTorch/Warp 系用数据并行张量与 CUDA 内核 @isaaclab2025。由此产生两个 RSI 相关性质：*批量随机化免费*（每环境可携带不同 $xi$）；*复现性需要显式设计*（GPU 浮点非结合性要求回放保存完整种子与配置）。其产物化形态是"Learning to Walk in Minutes"的腿足流水线（并行 PPO + DR，单 GPU 分钟级）@rudin2022walk；agentic RL 系统把同构思想推广到长时程交互，以版本管理器控制策略陈旧度 @agentrl2025 @rollart2025。大规模并行并非免费加速：超过任务多样性所能支撑的并行度后边际收益急剧下降，故*并行度应按实验的假设结构分配*——检验"修改 $m$ 是否改变学习曲线"需要跨种子的独立重复而非同一配置的海量副本；且须保证同一实验内策略版本一致，否则陈旧度污染归因。五年间端到端吞吐提升约四至六个数量级，而真实机器人吞吐没有变化；这个剪刀差决定了*仿真侧可以挥霍，真实侧必须节俭*，吞吐富余应用于*证据密度*。

== Domain randomization 与 sim-to-real

仿真与真实的差异可以参数化：设 $xi in Xi$ 为仿真参数向量（摩擦、质量、执行器增益、传感器延迟、纹理与光照等），$M_xi$ 为参数取 $xi$ 的仿真 MDP。Domain randomization（DR）不做单点参数校准，而是指定一个分布 $cal(P)(Xi)$，在其期望意义上优化策略：

$ J_"DR" (theta; cal(P)) = EE_(xi ~ cal(P)(Xi)) [ EE_(tau ~ pi_theta, M_xi) [ sum_(t=0)^T gamma^t r_t ] ] $ <eq:dr>

其原理直觉是：若真实参数 $xi^*$ 落在 $cal(P)$ 的支撑集内且策略在整个支撑集上表现良好，则可迁移到真实世界。视觉 DR @tobin2017dr、动力学 DR @peng2018dynamics 与课程化的自动域随机化（ADR）@mehta2020adr 是其三条奠基性工作线。与 @eq:dr 相对的鲁棒变体 $max_theta min_(xi) J(theta; xi)$ 追求最坏情形保证：期望目标样本效率更高，鲁棒目标在安全攸关部署中更可控，构成 DR 设计的第一对旋钮。

DR 的弱点是支撑集必须人工圈定：过窄则 $xi^*$ 落在分布外，过宽则策略学到保守的"平均化"行为。系统辨识（sysID）走相反路线——用真实数据反推参数点估计：

$ hat(xi) = argmin_(xi in Xi) EE_((s_t, a_t, s_(t+1)) ~ cal(D)_"real") [ norm( s_(t+1) - f_xi (s_t, a_t) )^2 ] $ <eq:sysid>

可微引擎使 @eq:sysid 可用梯度法求解，但接触参数可辨识性有限。两条路线合流为三个可复用组件：(i) *DR 为主、sysID 圈界*；(ii) *在线自适应*——RMA 把"辨识"移入部署时 @kumar2021rma；(iii) *real-to-sim-to-real*——真实场景重建加少量真实微调 @torne2024rialto。更进一步，DrEureka 把奖励函数与 DR 分布同时交给 LLM 进化式搜索，无需人工调参即完成新任务迁移 @ma2024dreureka @ma2024eureka。本书把这一演进概括为 sim-to-real 的闭环化（@fig:sim2real）：真实侧失败经系统辨识与分布更新回流到仿真配置，唯一未自动化的环节是"失败归因到仿真参数"的映射（本书推断为最待自动化的子问题）。DR 分布与第 7 章的课程分布在数学上同族——前者扩大支撑集以覆盖 $xi^*$，后者选择遗憾最大的参数 @dennis2020paired @jiang2021plr；本书提出在 RSI 闭环中把两者统一为同一演化对象，按"课程提议、DR 否决"合成最终采样分布。

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let b = (radius: 0.12, stroke: 0.8pt + accent, fill: softbg)
    let b2 = (radius: 0.12, stroke: 0.8pt + accent2, fill: bluebg)
    // 上排
    rect((0.2, 3.6), (3.4, 4.9), ..b, name: "train")
    content("train", text(size: 8pt)[仿真内并行训练\ $pi_theta$ on $EE_(xi ~ cal(P))$])
    rect((4.6, 3.6), (7.8, 4.9), ..b2, name: "dr")
    content("dr", text(size: 8pt)[DR 分布 $cal(P)(Xi)$\ （宽度/支撑集为设计变量）])
    rect((9.0, 3.6), (12.6, 4.9), ..b, name: "deploy")
    content("deploy", text(size: 8pt)[真机部署\ （稀缺槽位 · 安全联锁）])
    // 下排
    rect((9.0, 0.4), (12.6, 1.7), ..b2, name: "data")
    content("data", text(size: 8pt)[真实证据回流\ 轨迹 + 失败模式 + 指标])
    rect((4.6, 0.4), (7.8, 1.7), ..b, name: "sysid")
    content("sysid", text(size: 8pt)[系统辨识 $hat(xi)$（@eq:sysid）\ real-to-sim 场景重建])
    rect((0.2, 0.4), (3.4, 1.7), ..b2, name: "update")
    content("update", text(size: 8pt)[分布更新\ $cal(P) arrow.l$ 移位/扩宽/课程化])
    // 环
    line("train.east", "dr.west", mark: (end: ">"), stroke: 0.8pt + accent)
    line("dr.east", "deploy.west", mark: (end: ">"), stroke: 0.8pt + accent)
    line("deploy.south", "data.north", mark: (end: ">"), stroke: 0.8pt + accent)
    line("data.west", "sysid.east", mark: (end: ">"), stroke: 0.8pt + accent)
    line("sysid.west", "update.east", mark: (end: ">"), stroke: 0.8pt + accent)
    line("update.north", "train.south", mark: (end: ">"), stroke: 0.8pt + accent)
    // 失败归因（未自动化）
    line("data.north-west", (8.4, 2.9), (4.0, 2.9), "update.south-east", mark: (end: ">"), stroke: (dash: "dashed", paint: accent2, thickness: 0.8pt), name: "attr")
    content((6.2, 2.55), text(size: 7.5pt, fill: accent2)[失败归因 → 参数修正方向（2026 年仍主要靠人工，本书推断为最待自动化环节）])
    // 在线自适应旁路
    rect((13.2, 3.6), (14.8, 4.9), radius: 0.12, stroke: (dash: "dashed", paint: gray.darken(30%), thickness: 0.7pt), fill: softbg, name: "rma")
    content("rma", text(size: 7.5pt)[在线自适应\ （RMA 式）])
    line("deploy.east", "rma.west", mark: (end: ">"), stroke: (dash: "dashed", paint: gray.darken(30%), thickness: 0.7pt))
  }),
  caption: [sim-to-real 闭环（本书综合）：实线环为已工程化的主回路；赭色虚线为尚未自动化的失败归因环节；灰色虚线框为在线自适应旁路 @kumar2021rma。],
) <fig:sim2real>

== 面向 RSI 的仿真接口设计（本书提出）

现有引擎的 API 为"训练一个策略"设计，而 RSI 需要的是"运行并审计一个改进循环"。本书提出四个设计原则。第一，*任务参数化*：任务是结构化规范（场景程序、目标谓词、成功判据、初始分布）而非硬编码类，使 LLM 任务提议器能把"造任务"写成参数空间的采样与变异 @wang2024robogen @hua2024gensim2。第二，*可注入随机化*：DR 分布 $cal(P)(Xi)$ 是实验描述的一等字段，每次 rollout 的 $xi$ 采样连同种子一并记录，供事后按参数切片归因。第三，*证据导出*：每次实验产出轨迹、逐分量指标（带置信区间）与渲染三类证据，以不可变工件归档供独立评估器 $E$ 消费。第四，*世界模型接口*：保真度阶梯的最低一级是世界模型而非物理引擎，接口须允许同一任务描述降级实例化到学到的动力学模型并标注保真度等级，使"低保真否决、高保真批准"可机器执行。整个过程中 agent 只读证据、只写提议——修改的"提拔"由 $E$ 而非 $Phi$ 决定 @zhou2026physicalrsi。参考实现骨架如下：

```python
@dataclass
class TaskSpec:                 # 原则一：任务参数化
    scene_program: str          # 场景生成程序（可执行）
    goal_predicate: str         # 成功判据（可机检）
    init_dist: dict             # 初始状态分布
    horizon: int

@dataclass
class RandomizationSpec:        # 原则二：可注入随机化
    param_space: dict           # Ξ：摩擦/质量/延迟/纹理……
    dist: str                   # 𝒫(Ξ)："uniform"/"adr_curriculum"/"sysid_centered"
    seed: int                   # 每次 rollout 记录采样种子

@dataclass
class Experiment:               # 一个实验 = 假设 m 的受控实例化
    hypothesis_id: str          # A/B 结构的处理臂标识
    task: TaskSpec
    rand: RandomizationSpec
    fidelity: str               # "world_model" | "mjx" | "isaac_lab" | "real"
    n_episodes: int
    budget: float

class SimBackend(Protocol):     # 引擎无关接口：MJX/Isaac/Newton 可互换
    def instantiate(self, task, rand, n_envs: int) -> "VectorEnv": ...
    def export_evidence(self, env) -> "Evidence": ...

@dataclass
class Evidence:                 # 原则三：证据导出（不可变工件）
    trajectories: Any           # 轨迹流（含每环境 ξ 样本与种子）
    metrics: dict               # 逐分量指标 + 置信区间
    renders: dict               # 关键帧/视频（抽样）
    fidelity: str               # 保真度标签，供审批协议消费
    provenance: dict            # 引擎版本与配置哈希

class WorldModelBackend(SimBackend):  # 原则四：世界模型作为保真度 0 级
    # 同一 TaskSpec 降级实例化；其证据仅具否决权，无批准权
```

骨架中省略的两处恰是工程难点：`Evidence` 必须对受试 agent 只读（评估联锁），`fidelity` 的语义必须被编排层强制执行——这两个约束写在协议里而非文档里，是接口设计对 RSI 安全的直接贡献。

== 最新进展与未解决问题

*世界模型接管仿真叙事。* Genie 3 被定位为"训练具身智能体的仿真器" @deepmind2025genie3，Dreamer 系证明策略可在潜空间想象中训练 @hafner2025dreamerv3，RISE 与 VLAW 演示世界模型支撑的试错与共改进 @yang2026rise @guo2026vlaw；但世界模型在可重复性、可干预性、可审计性三条 RSI 功能上均不达标，本书判断中期格局是*双栈并存*。*仿真内 RSI 飞轮出现雏形*：EmbodiedSmith 演示仿真内数据飞轮 @qin2026embodiedsmith，RSIGym 把训练/rollout/评测打包为带预算与权限的服务 @meng2026rsigym；而没有任何系统展示 L5 级递归增益 @zhou2026physicalrsi，仿真正是产出此类证据的唯一可行场所。*未解决问题*：跨引擎可复现性、失败归因自动化、厂商吞吐数字的第三方复核、世界模型证据的校准，以及并行实验的统计纪律（预注册式声明须嵌进编排层）。

== 本章小结

#keybox(title: [本章要点])[
- 仿真对 RSI 的价值是可重复、可干预、可扩展三功能的工程实现；仿真证据按机制性/排序性/数值性三级采信；世界模型三条均不达标，中期格局双栈并存。
- 引擎合流（Newton、Isaac Lab 3.0 多后端、MJX 可微通道）解除了引擎锁定；厂商吞吐数字须绑定配置引用。
- 仿真吞吐五年提升四至六个数量级而真实吞吐不变：以真实证据为稀缺量反推仿真预算，富余用于证据密度。
- DR 是参数分布上的期望优化，与课程分布同族，应以"课程提议、DR 否决"统一演化；sim-to-real 闭环化后唯"失败归因→参数修正"环节仍靠人工。
- 仿真接口四原则：任务参数化、可注入随机化、证据导出、世界模型接口；安全约束须写在协议里。
]