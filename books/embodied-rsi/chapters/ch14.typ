#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 开放式进化、AutoRL 与计算成本

本章追问具身 RSI 闭环的三个深层问题：*燃料*从何而来（14.1）；*搜索*如何组织——QD 与 AutoRL 分别从"保持多样垫脚石"与"自动化优化决策"作答，2025–2026 年 LLM 接管进化算子的浪潮把两者融合为程序空间上的开放式搜索（14.2–14.4）；*账本*如何平衡——标度律刻画收益递减，具身场景的成本瓶颈在验证层（14.5–14.6）。

== 开放式学习：RSI 的持续性条件

"开放式"长期是口号：自然进化持续产出新颖复杂的产物，人工进化总在有限代后停滞。新颖性搜索最早给出反直觉实证——放弃适应度目标、只奖励"行为上的不同"，反而找到目标导向搜索找不到的解 @lehman2011novelty。迄今最一般的定义由 Hughes 等人给出 @hughes2024openendedness。

#definition(title: [开放式系统（Hughes et al., 2024）])[
从观察者 $O$ 的视角，系统 $S$ 是开放式的，当且仅当其产物序列持续同时满足：(i) *新颖性*——产物落在观察者预测分布的低概率区域；(ii) *可学习性*——观察者能通过研究产物更新自身的世界模型。
]

该定义的关键在于开放式是*观察者相对*的属性。本书采纳其工作版本：RSI 闭环是开放式的，当且仅当其任务生成器与改进算子持续产出"对人类评估者既意外又能从中学习"的任务与解。

POET 是开放式 RL 的奠基系统 @wang2019poet：环境与策略*成对*共同进化，新环境须满足*最小标准*（对当前最优策略不太难、不太易），策略定期跨环境迁移"嫁接"能力；Enhanced POET 进一步要求新环境"提出新问题"以保证对抗多样性 @wang2020enhancedpoet。POET 首次实证：直接在困难环境上训练会失败，而"问题与解共进化"的垫脚石链条能到达。Clune 的 AI-GA 论文论证通用智能将来自三个支柱（可学习架构、元学习算法、开放式探索）的自动发现 @clune2019aiga；OMNI 与 ASAL 用基础模型蒸馏"有趣性"判据，补上了第三支柱缺失的环节 @zhang2024omni @kumar2024asal。

为什么开放式是 RSI 的燃料？【本书推断】若任务集固定，改进算子 $Phi$ 的每轮输出只能在该集上锐化性能分布，根据"锐化而非创造信息"的理论（见 14.6 节），改进必然在数轮后饱和；只有任务生成器持续产出落在能力前沿之外的新颖可学任务，每一轮才有新信息源注入。换言之，*开放式不是 RSI 的装饰性目标，而是其持续性条件*——只优化固定任务集的系统不是 RSI 系统，只是一个很大的优化器。

== 质量多样性：把垫脚石变成显式缓存

质量多样性（QD）算法不只优化 $f(x)$，还要在*行为描述子*空间 $cal(B)$ 上"照亮"整个搜索空间。MAP-Elites 将 $cal(B)$ 离散为网格并维护档案 $cal(A)$：

$ cal(A)(c) = argmax_(x : b(x) = c) f(x), quad "QD-score"(cal(A)) = sum_(c in cal(B)) f(cal(A)(c)) $ <eq:mapelites>

目标是最大化 QD-score 与覆盖率而非单一最优。@fig:mapelites 给出示意。档案的 RSI 意义由 Cully 等人的经典实验给出最强实证：预建步态多样性档案的六足机器人腿部损伤后，*两分钟之内*即可从档案检索出补偿步态而非从头重学 @cully2015robots——损伤适应从"学习问题"变成"检索问题"，档案是应对未知扰动的冗余储备。工程侧，QDax 把 MAP-Elites 等算法用 JAX 重写并硬件加速，使种群级 QD 实验从数天压缩到数分钟 @lim2022qdax。

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 行为空间网格 6x4
    let nx = 6
    let ny = 4
    let cw = 1.35
    let ch = 0.95
    let ox = 0.9
    let oy = 1.0
    // 精英格子 (col,row)
    let elites = ((0,0),(1,0),(3,0),(5,0),(0,1),(2,1),(4,1),(5,1),(1,2),(3,2),(2,3),(4,3),(5,3))
    let best = (3,2)
    for i in range(nx) {
      for j in range(ny) {
        let p = (ox + i*cw, oy + j*ch)
        if elites.contains((i,j)) {
          rect(p, (ox + (i+1)*cw, oy + (j+1)*ch), fill: softbg, stroke: 0.5pt + softline)
          circle((ox + (i+0.5)*cw, oy + (j+0.45)*ch), radius: 0.14, fill: accent, stroke: none)
          content((ox + (i+0.5)*cw, oy + (j+0.78)*ch), text(size: 6.5pt, fill: accent)[精英])
        } else {
          rect(p, (ox + (i+1)*cw, oy + (j+1)*ch), fill: white, stroke: 0.5pt + softline)
        }
      }
    }
    // 最优精英高亮
    rect((ox + best.at(0)*cw, oy + best.at(1)*ch), (ox + (best.at(0)+1)*cw, oy + (best.at(1)+1)*ch), fill: bluebg, stroke: 1.1pt + accent2)
    circle((ox + (best.at(0)+0.5)*cw, oy + (best.at(1)+0.45)*ch), radius: 0.14, fill: accent2, stroke: none)
    content((ox + (best.at(0)+0.5)*cw, oy + (best.at(1)+0.78)*ch), text(size: 6.5pt, fill: accent2)[全局最优])
    // 轴
    line((ox, oy), (ox + nx*cw + 0.55, oy), mark: (end: ">"), stroke: 0.8pt + ink)
    line((ox, oy), (ox, oy + ny*ch + 0.5), mark: (end: ">"), stroke: 0.8pt + ink)
    content((ox + nx*cw + 0.7, oy - 0.05), text(size: 8pt)[$b_1$])
    content((ox - 0.15, oy + ny*ch + 0.55), text(size: 8pt)[$b_2$])
    content((ox - 0.15, oy - 0.35), text(size: 7.5pt, fill: gray.darken(20%))[行为描述子空间 $cal(B)$ 的离散化])
    // 右侧流程
    let bx = 10.6
    rect((bx, 4.35), (bx + 3.6, 5.35), radius: 0.1, fill: softbg, stroke: 0.8pt + accent, name: "pop")
    content("pop", text(size: 8pt)[亲本采样：从档案\ 均匀/偏好采样 $x$])
    rect((bx, 2.95), (bx + 3.6, 3.95), radius: 0.1, fill: softbg, stroke: 0.8pt + accent, name: "mut")
    content("mut", text(size: 8pt)[变异算子 $x' = M(x)$\ （随机 / LLM）])
    rect((bx, 1.55), (bx + 3.6, 2.55), radius: 0.1, fill: softbg, stroke: 0.8pt + accent, name: "eval")
    content("eval", text(size: 8pt)[评估 $(f(x'), b(x'))$\ （仿真 / 可执行评估器）])
    line("pop.south", "mut.north", mark: (end: ">"), stroke: 0.8pt + accent)
    line("mut.south", "eval.north", mark: (end: ">"), stroke: 0.8pt + accent)
    // 插入档案
    line((bx, 2.05), (8.1, 2.05), mark: (end: ">"), stroke: (thickness: 0.8pt, paint: accent2, dash: "dashed"))
    content((9.2, 1.72), text(size: 7.5pt, fill: accent2)[按格插入：更优则替换])
    // 反馈：档案驱动下一轮亲本
    line((5.4, 5.0), (5.4, 5.35), (bx, 4.85), mark: (end: ">"), stroke: (thickness: 0.8pt, paint: accent, dash: "dashed"))
    content((7.3, 5.45), text(size: 7.5pt, fill: accent)[档案 $cal(A)$ 即亲本分布])
  }),
  caption: [MAP-Elites 档案示意（本书绘制）。左：行为描述子空间 $cal(B)$ 离散为网格，每格保存该行为模式下适应度最高的精英解（@eq:mapelites）；右：采样—变异—评估—按格插入的迭代循环，档案同时充当亲本分布与多样性缓存。],
) <fig:mapelites>

在 RSI 视角下重读 @eq:mapelites，QD 的本质是*维护多样化的改进提案库*而非追踪单个最优。LLM 时代直接继承了这一视角：DGM 的智能体档案、EoH-S 的互补启发式集合都是 MAP-Elites 档案在程序空间的对应物，EoH-S 的超模性证明更为"档案式改进"提供了组合优化理论锚点 @zhang2025dgm @liu2025eohs。当前短板：行为描述子通常需人工设计。【本书推断】具身 RSI 中档案的最佳落点是*任务—技能对*空间（行是技能类型、列是任务难度区间），同时充当课程记忆与改进提案库。

== AutoRL：把优化决策本身变成优化对象

AutoRL 综述把 RL 系统设计中的全部人为决策写成双层优化 @parkerholder2022autorl：

$ max_(lambda in Lambda) Phi(lambda) = "Eval"("RL-Train"(lambda)) $ <eq:autorl>

其中 $lambda$ 涵盖超参、奖励塑形、课程分布、探索策略乃至算法组件本身；内层是一次完整 RL 训练，外层在配置空间 $Lambda$ 上搜索，核心难点是外层目标评估昂贵且噪声大。@eq:autorl 与 RSI 闭环严格同构：内层对应任务执行系统，外层对应 $Phi$，$"Eval"$ 对应评估器 $E$；差别在于 AutoRL 的 $Lambda$ 是人工划定的有限空间且 $"Eval"$ 与优化目标同源，RSI 则要求 $Lambda$ 可扩展、$E$ 独立且抗操纵。【本书推断】精确分界因此是：*AutoRL 是固定的 $Phi$ 在固定 $Lambda$ 上的优化；RSI 是 $Phi$ 与 $Lambda$ 同时进入改进闭包*。

三个自动化方向与 RSI 的关系不对称：*自动奖励设计*（Eureka/DrEureka，见第 13 章 @ma2024eureka @ma2024dreureka）证明 in-context 进化已足以超越专家工程；*自动课程*的理论锚点是 UED 的 minimax regret 目标 @dennis2020paired，PAIRED→PLR→ACCEL 谱系把 POET 的洞见蒸馏进单智能体预算 @jiang2021plr @parkerholder2022accel，而 Rutherford 等人证明常用遗憾代理实际与成功率相关、应按 $p(1-p)$ 采样 @rutherford2024noregrets；*自动算法发现*在 $lambda$ 扩展到算法组件本身时与下节的程序进化合流。超参优化只移动效率参数，奖励与课程的自动化改变的则是*信号与经验的内容*，属信息源级别的改进。

== LLM×进化：2025–2026 年的重心

ELM 的论断是起点：代码语料上训练的 LLM 是*学习到的变异分布*，其 diff 采样有语义目的性 @lehman2022elm。FunSearch 把它工程化：程序模板 + 可执行评估器 $epsilon$ + islands 程序数据库，LLM 以 top-$k$ 程序为上下文生成变体、$epsilon$ 打分入库，即 $max_p epsilon(p)$ 且 $M(p) = "LLM"("prompt"(cal(A)_"top-k", "模板"))$；cap set 与在线装箱结果超越已知最优构造，确立"语义变异 + 自动评估"范式 @romeraparedes2024funsearch。AlphaEvolve 是其工业化放大：混合提案、全代码库 diff 级进化，成果包括 4×4 复数矩阵乘法 48 次标量乘法（打破 Strassen 以来的 49 次纪录）、训练 kernel 加速 23%、Borg 调度回收 0.7% 全球算力 @novikov2025alphaevolve，并于 2026 年产业化 @deepmind2026alphaevolveimpact。

但批判性标注必须记录在案：这些部署收益*不构成*"闭合了重训提案模型自身"的证据——AlphaEvolve 的提案模型（Gemini）不在进化闭包之内，它仍是*有界优化器*而非完全体 RSI（本书认同此判断）。开源侧 CodeEvolve 以岛屿 GA + 灵感交叉 + 元提示在部分 AlphaEvolve 基准上反超并完整开源 @assumpcao2025codeevolve。两条机制线回应进化搜索的最大痛点：*样本效率*上 ShinkaEvolve 的亲本采样、新颖性拒绝与 bandit 模型选择把圆装箱刷到 SOTA 仅用 150 次评估（AlphaEvolve 需数千次）@lange2025shinkaevolve；*反馈通道*上 GEPA 让一次失败 rollout 返回整段文本轨迹而非标量奖励，LLM 读轨迹做"反思变异"，以最多 35× 更少的 rollout 超过 GRPO @agrawal2025gepa——标量奖励一次失败只给 1 bit 级方向信息，文本轨迹携带"哪一步、为什么、怎么改"的高维信号。

CORAL 代表 2026 年的范式声明：把检索、提议、评估、更新的控制权从固定进化算子交还给长程自主 agent（多 agent 异步执行、共享持久记忆、"心跳干预"做元层调控、隔离工作区做护栏 @qu2026coral）；结果上 10/11 个任务 SOTA，4 个共进化 agent 找到单 agent 用 4 倍算力也找不到的解。配合 DGM/HGM/Mendel-GM 谱系把进化载体从"解空间中的程序"换成"智能体自身的 scaffold 代码" @zhang2025dgm @wang2025hgm @liu2026mgm，统一视角清晰：*进化算子正被 LLM 接管，进化对象正从外部工件转向系统自身*——这是滑向 RSI 的临界面。所有系统都是"档案—生成—评估—选择"四件套的实例化，该循环与 RSI 闭环同构：档案即自我状态，生成即 $Phi$，评估即 $E$。

== 失败归因：闭环的最短板

上节的进化循环有一个隐含前提：选择环节拿到的反馈足以定位"改哪里"。对长程 agentic 系统与具身策略，失败原因散布在几十步轨迹中，标量回报几乎不携带定位信息。*失败归因*是连接轨迹证据与进化信号的必要中介，也是当前闭环的最短板。

Who&When 给出首个 LLM 多智能体失败归因基准（184 条人工标注轨迹，定位"谁+何时"），最强模型的 *step 级准确率仅约 13–16%* @zhang2025whowhen；MAST 的 14 类失败模式分类学提供模式库但不解决定位 @cemri2025mast。2026 年：TraceElephant 指出 Who&When 只给输出不给输入造成部分可观测性缺陷，补充输入侧字段后 *agent 级*准确率从约 51% 升至 62% @zhang2026traceelephant；POIROT 用多智能体"质询"协议做故障定位并自建 BLAME 基准 @poirot2026blame。现状可压缩为一个区间：*自动归因的 step 级准确率目前在 13%–62% 之间*，且随粒度细化急剧下降——具身场景要求的"哪个接触事件、哪段控制窗口"比 step 级更细，尚无对应基准。工程启示：归因能力首先受*轨迹记录的信息架构*约束——日志里不存在的因果证据，再强的 LLM 也读不出来。归因不准意味着改进信号被稀释为"全局重训"，定向变异退化为随机游走。【本书推断】最高杠杆的结合点是*归因驱动的课程与变异*，目前仍由人工完成。

== 计算成本经济学：改进何时不再划算

RSI 的"递归"承诺隐含改进可无限继续的预期，但 RL 计算的经验标度律给出相反图景。ScaleRL 用超 40 万 GPU 小时拟合出 *sigmoid 标度律* @khatri2025scalerl：

$ R(C) = A / (1 + e^(-B (log C - C_0))) $ <eq:scalerl>

其中 $A$ 是渐近性能，$B$ 控制中段斜率，$C_0$ 是拐点。两个关键结论：(i) 多数设计选择影响*效率*而非渐近线 $A$；(ii) 曲线可从训练早期外推十万 GPU 小时量级的终点——"收益递减点"因此是可操作的外推问题。理论侧证据链一致：锐化机制证明自我改进不能创造模型中不存在的信息 @huang2024sharpening；"Mind the Gap"证明改进幅度由生成—验证差距控制，纯自反馈约 2–3 轮后饱和 @song2025mindthegap；生成与验证间存在计算最优分配 @singhi2025solveverify，自验证有系统性局限 @stechly2025selfverify；有外部可验证信号时自我改进可超越蒸馏教师 @singh2024beyondhuman——持续增长的充分条件是回路中存在独立于模型的信息源，开放式任务生成正是"持续购入增量信息"的机制化途径。

*具身反转：瓶颈在验证层而非生成层。* 纯软件 RSI 的成本大头在生成层（提案与程序评估都可并行扩展）；具身场景反过来：GPU 并行仿真把 rollout 成本压到极低（ManiSkill3 仿真加渲染超 3 万 FPS @tao2025maniskill3），但*真机验证的边际成本不随并行化下降*——每台机器人、每次物理复位都是串行的稀缺资源。【本书推断】具身 RSI 的成本结构因此是*验证层瓶颈*；这也是 Physical RSI 把独立评估器 $E$ 置于系统之外的经济学理由 @zhou2026physicalrsi——评估不只是可信性要求，也是最稀缺的预算科目。

【本书提出】把第 $t$ 轮预算分为生成预算 $B_t^g$ 与验证预算 $B_t^v$，期望改进为

$ Delta_t (B^g, B^v) approx min{ G_t(B^g), V_t(B^v) } dot q_t $ <eq:budget>

其中 $G_t$ 是生成层能产出的候选改进量，$V_t$ 是验证层能可信确认的改进量，$q_t in [0,1]$ 是归因—反馈链路的*信号保留率*。边际等值条件的推论：*预算应持续移向验证层与信号保留率，直到 $V_t$ 不再是紧约束*；且当 $V_t$ 为紧约束时，改进速率对归因准确率 $q_t$ 的弹性大于对任何生成层投资的弹性——提升归因能力是预算回报最高的单项投资。停止规则取三个信号之二（本书推断）：(i) sigmoid 渐近线 $A$ 逼近当前性能；(ii) 生成—验证差距实测闭合；(iii) held-out 效应量置信区间跨零——出现其二应停止或*换轴*，而非追加算力。最后，风险账不随轮次递减：每轮自我修改都引入新的行为面，安全暴露近似单调累积——这是具身 RSI 与纯软件 RSI 在会计结构上的本质差别。

== 本章小结

本章回答了具身 RSI 闭环的三个深层问题。燃料问题：Hughes 定义（新颖 ∧ 可学、观察者相对）把"开放式"变为可检验性质，POET 谱系实证了问题与解共进化的不可替代性，开放式生成是 RSI 的持续性条件（14.1）。搜索组织：MAP-Elites 档案把多样性变成显式缓存，损伤适应从学习变检索（14.2）；AutoRL 与 RSI 的分界在于外层循环是否自身可进化（14.3）。2025–2026 重心：FunSearch→AlphaEvolve→CORAL 谱系显示进化算子正被 LLM 接管、循环控制权移交自主多智能体，而"有界优化 ≠ 递归自我改进"的批判必须记录在案（14.4）。短板与账本：失败归因的 step 级准确率仅 13–62%，是闭环最薄弱环节（14.5）；sigmoid 标度律使收益递减可外推，具身场景的成本瓶颈在验证层，预算分配服从 @eq:budget 的边际等值条件（14.6）。

#keybox(title: [本章要点])[
- 开放式是 RSI 的持续性条件：任务分布不开放，改进必然在锐化极限处饱和。
- MAP-Elites 档案是"多样化垫脚石的显式缓存"；具身 RSI 中最佳落点是任务—技能对空间（本书推断）。
- AutoRL = 固定外层循环的双层优化；RSI = 外层循环自身进入改进闭包。
- LLM×进化的统一框架是"档案—生成—评估—选择"四件套；AlphaEvolve 的产业化收益是有界优化的证据，不是闭合递归的证据。
- 失败归因（step 级准确率 13–62%）是闭环最短板；归因驱动的课程与变异是最高优先级的开放结合点。
- sigmoid 标度律使改进终点可外推；具身 RSI 瓶颈在验证层；停止规则取"渐近线逼近 ∧ 差距闭合 ∧ 置信区间跨零"三中之二。
]
