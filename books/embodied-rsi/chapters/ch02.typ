#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 决策与学习的数学基础：MDP/POMDP、强化学习与最优控制

具身智能的递归自我改进（RSI）若要可分析、可保证，须先把"智能体—环境—学习—评估"链条数学化。本章是全书理论地基：交互形式化为（部分可观测）马尔可夫决策过程，学习形式化为 Bellman 不动点的随机逼近与策略参数的直接优化，执行形式化为最优控制，验证形式化为统计推断。统一符号：状态 $s in cal(S)$，动作 $a in cal(A)$，转移核 $P(s' mid s, a)$，奖励 $r(s,a,s')$，折扣 $gamma in [0,1]$，策略 $pi_theta (a mid s)$，目标为折扣回报
$ J(theta) = EE_(tau tilde pi_theta) [ sum_(t=0)^(infinity) gamma^t r_t ]. $ <eq:ch02-objective>
本章定理属【已有成果】；将其装配成 RSI 闭环的映射属【本书推断】。

== MDP 与 Bellman 压缩映射

#definition(title: [马尔可夫决策过程 @puterman1994markov])[
无限视界折扣 MDP 为五元组 $cal(M) = (cal(S), cal(A), P, r, gamma)$，Markov 性质要求未来只依赖当前状态与动作。给定策略 $pi(a mid s)$，定义回报 $G_t = sum_(k=0)^(infinity) gamma^k r_(t+k+1)$、值函数 $V^pi(s) = EE_pi [G_t mid s_t = s]$、动作值函数 $Q^pi(s,a)$ 与优势函数 $A^pi = Q^pi - V^pi$。对任意 $V: cal(S) -> RR$，Bellman 期望算子与最优算子为
$ (cal(T)^pi V)(s) = sum_a pi(a mid s) sum_(s') P(s' mid s,a)[r + gamma V(s')], \
  (cal(T) V)(s) = max_a sum_(s') P(s' mid s,a)[r + gamma V(s')]. $ <eq:ch02-bellman-opt>
$V^pi$ 与 $V^* = sup_pi V^pi$ 分别是 $cal(T)^pi$ 与 $cal(T)$ 的不动点 @bellman1957dynamic @sutton2018reinforcement。对具身智能体，$s$ 可含关节构型与任务上下文，$a$ 可为电机力矩或技能调用。
]

#theorem(title: [Bellman 算子的压缩性 @puterman1994markov])[
设 $gamma < 1$，则 $cal(T)$ 在上确界范数下是模为 $gamma$ 的压缩映射：$norm(cal(T)U - cal(T)V)_infinity <= gamma norm(U - V)_infinity$。由 Banach 不动点定理，$cal(T)$ 存在唯一不动点 $V^*$，且从任意 $V_0$ 出发的值迭代 $V_(n+1) = cal(T) V_n$ 以几何速率收敛。
]

#proof[
（梗概）固定 $s$，不妨设 $(cal(T)U)(s) >= (cal(T)V)(s)$，令 $a^*$ 为 $cal(T)U$ 在该状态的最优动作，则"去掉内层 max 只可能使差更大"：
$ 0 <= (cal(T)U)(s) - (cal(T)V)(s) <= gamma sum_(s') P(s' mid s, a^*) [U(s') - V(s')] <= gamma norm(U - V)_infinity. $
对 $s$ 取上确界即得压缩性；完备度量空间上的压缩映射有唯一不动点，迭代误差满足 $norm(V_n - V^*)_infinity <= gamma^n norm(V_0 - V^*)_infinity$。
]

压缩性一次性解决最优值函数的存在性、唯一性与可计算性：误差按 $gamma^n$ 衰减，$gamma -> 1$ 时有效视界 $1\/(1-gamma)$ 发散。值迭代（VI）直接迭代 $cal(T)$ 并贪心提取策略；策略迭代（PI）交替策略评估（解 $V^(pi_k) = (I - gamma P^(pi_k))^(-1) r^(pi_k)$）与策略改进（贪心化）。

#theorem(title: [策略改进定理 @sutton2018reinforcement @puterman1994markov])[
若确定性策略 $pi'$ 满足对一切 $s$ 有 $Q^pi(s, pi'(s)) >= V^pi(s)$，则 $V^(pi') >= V^pi$ 逐点成立；有限 MDP 中策略迭代在有限步内收敛到最优策略。
]

#proof[
（思路）由假设 $V^pi <= cal(T)^(pi') V^pi$ 逐点成立；$cal(T)^(pi')$ 单调且为压缩映射，反复作用取极限即得 $V^pi <= V^(pi')$。有限性来自确定性策略有限且单调改进不重复访问。
]

PI 每步昂贵但收敛步数少，VI 反之；改进型 PI 与 actor-critic 介于其间，异步更新是 Q-learning 证明的骨架。【本书推断】自我改进无终止态，平均回报准则更贴合 RSI 建模 @puterman1994markov。

== POMDP：信念状态与 PWLC 结构

真实具身系统几乎从不完全可观测。POMDP 引入观测核 $O(o mid s', a)$ @sondik1971optimal @kaelbling1998planning：智能体不观测 $s_t$，仅凭历史决策；信念状态 $b_t(s) = PP(s_t = s mid h_t)$ 是历史的充分统计量，由 Bayes 滤波递归更新（$eta$ 为归一化常数）：
$ b'(s') = eta dot O(o mid s', a) sum_s P(s' mid s, a) b(s). $ <eq:ch02-belief>
与 MDP 版的关键差别是智能体内部多出"信念更新"模块，策略作用在信念而非状态上。

#theorem(title: [Sondik 定理 @sondik1971optimal])[
POMDP 等价于以信念空间 $Delta(cal(S))$ 为状态空间的 belief-MDP；其最优值函数关于 $b$ 分段线性凸（PWLC），可表示为 $alpha$-向量的上包络：$V^*(b) = max_(alpha in Gamma) alpha^top b$。
]

#proof[
（思路）@eq:ch02-belief 表明 $b'$ 只依赖 $(b, a, o)$，故信念满足 Markov 性。PWLC 由归纳：一步值函数线性、$max$ 保凸、期望是线性拉回；压缩性把归纳推向无限视界。
]

PWLC 把连续信念空间上的函数压缩为一组 $alpha$-向量，但 $Gamma$ 随时视界指数增长 @kaelbling1998planning；点值迭代（PBVI）只在代表性信念点集上备份，是误差以 $O(epsilon_B \/ (1-gamma)^2)$ 收缩的 anytime 算法 @pineau2003point。复杂度上，有限视界 POMDP 策略评估已 PSPACE 完全，Dec-POMDP 达 NEXP 完全 @bernstein2002complexity。深度 RL 的对照路线以循环网络隐状态充当"学到的信念"：RL#super[2] 表明冻结权重下其激活动力学即可实现近似贝叶斯自适应学习 @duan2016rl2——_记忆就是信念_。【本书推断】对 RSI 的含义：信念维护（记忆、摘要、工作上下文）是决策的一部分而非工程细节。

== 强化学习：收敛保证、策略梯度与信赖域

去掉模型假设后，智能体只能凭采样逼近 Bellman 不动点或直接改进策略。Q-learning 的一步更新为
$ Q(s_t, a_t) arrow.l Q(s_t, a_t) + alpha_t [ r_(t+1) + gamma max_(a') Q(s_(t+1), a') - Q(s_t, a_t) ], $ <eq:ch02-qlearning>
括号中即 TD 误差 $delta_t$，度量"现实相对预期的意外度"，是信用分配（第 4、8 章）的天然信号。

#theorem(title: [Q-learning 收敛性 @watkins1992qlearning])[
设奖励有界、查找表表示、每个 $(s,a)$ 被无限次访问，步长满足 Robbins–Monro 条件 $sum_t alpha_t = infinity$、$sum_t alpha_t^2 < infinity$，则 $Q_n$ 以概率 1 收敛到 $Q^*$。
]

#proof[
（思路）把随机迭代改写为 $Q_(n+1) = Q_n + alpha_n (cal(T) Q_n - Q_n + w_n)$，$w_n$ 为条件零均值鞅差；两个步长条件分别保证"走得动"与"噪声方差有限"，结合 $gamma$-压缩性与随机逼近的鞅方法得几乎必然收敛。
]

保证的边界同样关键：定理只覆盖查找表；函数逼近、自举、off-policy 的"致命三元组"齐备时即使线性逼近也可发散（Baird 反例 @sutton2018reinforcement）。【本书推断】RSI"从历史日志改进策略"恰好触发三元组，离线保守化是安全底线。

=== 策略梯度定理及其推导

值函数方法先估值再贪心，策略梯度方法直接对 @eq:ch02-objective 求 $nabla_theta J(theta)$——连续控制与需要随机策略保持探索的场景（具身操作、LLM 智能体）非后者不可。以下推导是全书策略优化方法的共同源头。

#theorem(title: [策略梯度定理 @sutton2000policy])[
设 $J(theta) = EE_(s_0 tilde mu_0) [V^(pi_theta)(s_0)]$，则在常规可微性假设下
$ nabla_theta J(theta) = sum_s d^(pi_theta)(s) sum_a Q^(pi_theta)(s,a) nabla_theta pi_theta (a mid s) = EE_(s tilde d^(pi_theta), a tilde pi_theta) [ nabla_theta log pi_theta (a mid s) Q^(pi_theta)(s,a) ], $ <eq:ch02-pg>
其中 $d^(pi_theta)(s) prop sum_(t=0)^(infinity) gamma^t PP(s_t = s mid pi_theta)$ 为折扣占用测度。
]

#proof[
（完整推导）对 $V^(pi_theta)$ 的 Bellman 方程两边求梯度：
$ nabla_theta V^(pi_theta)(s) = sum_a [ nabla_theta pi_theta (a mid s) Q^(pi_theta)(s,a) + pi_theta (a mid s) nabla_theta Q^(pi_theta)(s,a) ]. $
展开 $Q^(pi_theta)(s,a) = sum_(s') P(s' mid s,a)[r(s,a,s') + gamma V^(pi_theta)(s')]$，注意 $r$ 与 $P$ 不依赖 $theta$，故 $nabla_theta Q^(pi_theta)(s,a) = gamma sum_(s') P(s' mid s,a) nabla_theta V^(pi_theta)(s')$。记 $phi(s) = sum_a nabla_theta pi_theta (a mid s) Q^(pi_theta)(s,a)$，代回得递推
$ nabla_theta V^(pi_theta)(s) = phi(s) + gamma sum_a pi_theta (a mid s) sum_(s') P(s' mid s,a) nabla_theta V^(pi_theta)(s'). $
对右端反复展开，第 $t$ 层贡献 $gamma^t sum_(s') PP(s_t = s' mid s_0 = s, pi_theta) phi(s')$；求和并对 $s_0 tilde mu_0$ 取期望即得 $nabla_theta J(theta) = sum_s d^(pi_theta)(s) phi(s)$，最后用 $pi_theta nabla_theta log pi_theta = nabla_theta pi_theta$ 写成期望形式，即 @eq:ch02-pg。
]

关键洞察：梯度表达式中_不出现_ $nabla_theta d^(pi_theta)$——访问分布变化的一阶影响被自洽吸收，故可用沿当前策略的轨迹构造无偏梯度（REINFORCE：$hat(g) = sum_t nabla_theta log pi_theta (a_t mid s_t) (G_t - b(s_t))$）。基线 $b(s)$ 不改期望只降方差（因 $sum_a b(s) nabla_theta pi_theta (a mid s) = 0$）；取 $b = V^(pi_theta)$ 即以优势函数为信号，导向 actor-critic @konda2000actor 与偏差—方差插值的 GAE @schulman2015gae。

=== 信赖域、离线 RL 与探索

朴素策略梯度对步长极敏感，TRPO 给出单调改进的替代目标：存在常数 $C$ 使
$ J(pi_theta) >= L_(pi_("old"))(pi_theta) - C dot D_("KL")^max (pi_("old") parallel pi_theta), quad L_(pi_("old"))(pi) = J(pi_("old")) + EE_(s tilde d^(pi_("old")), a tilde pi) [ A^(pi_("old"))(s,a) ], $ <eq:ch02-trpo>
故在 KL 信赖域内最大化替代目标 $L$ 可保证近似单调改进 @schulman2015trust。PPO 以裁剪重要性比率替代显式约束，无单调性保证但简洁稳定，成为 LLM 后训练与具身 RL 的默认选择 @schulman2017proximal；GRPO 以组内相对优势替代学到的 critic @shao2024deepseekmath。【本书推断】TRPO 式"局部可信、小幅、可证伪"的更新正是改进算子 $Phi$ 应有的形态——自我改进循环需信赖域式单调性条件以防"越改越差"。

离线 RL 只用固定的历史数据集，核心困难是分布偏移：数据外动作的 $Q$ 被外推高估并经自举放大。两类对策：行为约束（BCQ @fujimoto2019offpolicy）与值函数保守化（CQL 惩罚数据外动作的 $Q$，所得策略值是真实值的_下界_ @kumar2020conservative）——把"不知道"变成"往低估计"。探索理论回答"数据从哪来"：UCB 按"乐观面对不确定"选臂，遗憾界与 Lai–Robbins 下界同阶 @auer2002finite；MDP 推广为 UCRL2 @jaksch2010near 与后验采样 PSRL，共同骨架是_频率比_：置信集收缩速率决定遗憾增速。【本书推断】RSI 的任务生成与实验选择天然是探索—利用问题，UCB 式规则给出难度自适应课程的雏形。

== 最优控制：LQR 与"规划—学习"统一视角

最优控制是 MDP 在"模型已知、状态可观、代价最小化"下的特化，给出极少数解析可解的参照系。离散 LQR：$x_(t+1) = A x_t + B u_t$，代价 $sum_t (x_t^top Q x_t + u_t^top R u_t)$，$Q succ.curly.eq 0, R succ 0$。

#theorem(title: [LQR 的最优律与 Riccati 方程 @bertsekas2017dynamic])[
LQR 的最优控制为线性状态反馈 $u_t^* = -K x_t$，其中 $K = (R + B^top P B)^(-1) B^top P A$，$P$ 为离散代数 Riccati 方程（DARE）
$ P = Q + A^top P A - A^top P B (R + B^top P B)^(-1) B^top P A $ <eq:ch02-dare>
的唯一对称半正定解，最优值函数为二次型 $V^*(x) = x^top P x$。
]

#proof[
（推导）从终端反向归纳：设 $V_(t+1)(x) = x^top P_(t+1) x$，则 Bellman 最优方程为
$ V_t (x) = min_u [ x^top Q x + u^top R u + (A x + B u)^top P_(t+1) (A x + B u) ]. $
括号内是 $u$ 的严格凸二次型，对 $u$ 求导置零得 $u^* = -(R + B^top P_(t+1) B)^(-1) B^top P_(t+1) A x eq.colon -K_t x$；代回整理即 Riccati 递推 $P_t = Q + A^top P_(t+1) A - A^top P_(t+1) B K_t$，可稳性假设下收敛到 DARE 不动点。DARE 正是"Bellman 最优方程在二次型函数类上的特化"，Riccati 递推即值迭代。
]

对非线性动力学，iLQR/DDP 把 LQR 用作局部模板：沿标称轨迹线性化、代价二阶展开，反向传递传播局部 Riccati 修正、前向传递滚动新轨迹 @bertsekas2017dynamic。MPC 把全局求解换成每步有限视界在线重解：
$ min_(u_(0:H-1)) sum_(k=0)^(H-1) c(x_k, u_k) + c_f (x_H) quad upright("s.t.") quad x_(k+1) = f(x_k, u_k), space (x_k, u_k) in cal(X) times cal(U), $ <eq:ch02-mpc>
只执行第一个控制量再在下一状态重解。约束的一等公民地位是 MPC 独有优势；稳定性靠终端代价取局部 Lyapunov 函数、终端集取不变集保证 @rawlings2017model；硬件限位与碰撞约束可直接写入 @eq:ch02-mpc。

@fig:ch02-spectrum 把本章方法排在"模型可知性—求解方式"谱系上：左端全知模型在线重规划，右端无模型摊销策略，中间是学模型再规划的混合路线。这是精确的连续谱：MPC 可视为"在线版一步策略迭代"；model-based 与 model-free 共享同一套 Bellman 备份，差别只在数据来自环境还是学到的模型 @yang2026rise。【本书推断】RSI 在"改进速度 vs. 可保证性"间的权衡正是谱系上的选址：高风险修改走 MPC 侧（可验证、可回滚），低风险更新走摊销 RL 侧。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let boxstyle = (radius: 0.12, stroke: (paint: rgb("#0f5c5c"), thickness: 0.9pt), fill: rgb("#eef3f5"))
    // 轴线
    line((-7.0, 0), (7.0, 0), mark: (end: ">"), stroke: 0.9pt + rgb("#2b2b2b"))
    content((-6.95, -0.55), anchor: "west", text(size: 7.5pt, fill: rgb("#8c5a2b"))[模型完全已知 · 在线重规划])
    content((6.95, -0.55), anchor: "east", text(size: 7.5pt, fill: rgb("#8c5a2b"))[模型未知 · 摊销策略])
    let node = (x, y, title, sub) => {
      rect((x - 1.45, y - 0.42), (x + 1.45, y + 0.42), ..boxstyle)
      content((x, y + 0.14), text(size: 7.8pt, weight: "bold")[#title])
      content((x, y - 0.18), text(size: 7pt)[#sub])
      line((x, 0), (x, if y > 0 { y - 0.42 } else { y + 0.42 }), stroke: (paint: rgb("#d9d4c8"), thickness: 0.7pt, dash: "dashed"))
    }
    node(-5.6, 1.1, [VI / PI（动态规划）], [全模型 · 离线全局求解])
    node(-2.8, -1.15, [iLQR / MPC], [已知 $f$ · 每步在线重解])
    node(0, 1.1, [Dyna / 世界模型 RL], [学模型 · 想象中规划])
    node(2.8, -1.15, [TD / Q-learning], [无模型 · 自举估值])
    node(5.6, 1.1, [PG / TRPO / PPO], [无模型 · 直接改进 $pi_theta$])
    content((0, 2.05), text(size: 7.5pt, fill: rgb("#8c5a2b"))[规划深度 ＋ 模型依赖 递减，部署计算量递减])
  })),
  caption: [控制 / 规划 / 强化学习方法谱系：从"全知模型、在线重规划"到"无模型、摊销策略"。],
) <fig:ch02-spectrum>

@tab:ch02-compare 汇总五类方法的性质对比，供选择改进算子 $Phi$ 的实现形态时查阅。

#figure(
  table(
    columns: (1fr, 0.85fr, 1.1fr, 1.7fr),
    [方法], [模型需求], [求解对象], [收敛性 / 保证],
    [值迭代 VI], [需 $(P,r)$], [$V$（全盘扫描）], [几何收敛 $gamma^n$；唯一不动点],
    [策略迭代 PI], [需 $(P,r)$], [$V^pi$ 与 $pi$ 交替], [逐点单调改进，有限步收敛],
    [TD / Q-learning], [无（采样）], [$V$ / $Q$ 查找表], [Robbins–Monro 步长下 a.s. 收敛；函数逼近无保证],
    [PG / TRPO / PPO], [无（采样）], [策略参数 $theta$], [TRPO 近似单调；PPO 仅启发式],
    [MPC], [需 $f$（可学习）], [开环序列 $u_(0:H-1)$], [终端设计下递归可行/稳定；约束一等公民],
  ),
  caption: [五类决策与学习方法的性质对比（"a.s."为几乎必然收敛）。],
) <tab:ch02-compare>

== 评估的统计基础

RSI 闭环的最后一环是验证："第 $k+1$ 代真的优于第 $k$ 代吗？"这本质上是统计推断而非优化；_宣称改进而不附置信区间，等于在评估噪声上过拟合出幻觉改进_。设 $n$ 个 i.i.d. 回报样本，三条递进工具：(i) 中心极限定理给出渐近区间 $hat(J)_n plus.minus z_(1 - alpha\/2) hat(sigma) \/ sqrt(n)$；(ii) 回报有界 $G in [a, b]$ 时 Hoeffding 不等式给出无分布假设的样本界
$ PP(abs(hat(J)_n - J) >= epsilon) <= 2 exp(- frac(2 n epsilon^2, (b - a)^2)); $ <eq:ch02-hoeffding>
(iii) 经验 Bernstein 界用样本方差替换量程，小方差情形（"两代多数任务打平、少数分胜负"）显著收紧。只能以历史数据评估（RSI 常态）时，双重稳健估计配合浓度不等式给出高置信 off-policy 下界 @thomas2015high；只报点估计是基准不可复现的首要原因 @miller2024errorbars。

比较两代智能体应做配对设计：相同任务集与随机种子下对差值 $d_i = G_i^(A_(k+1)) - G_i^(A_k)$ 做单样本推断，消去任务难度这一公共方差源；多候选比较需多重性校正（Holm 优于 Bonferroni），自适应评估需 anytime-valid 序贯检验或 e-value。把候选改进视为臂、评估 rollout 视为拉臂，"有限预算选最优候选"即最优臂辨识，PAC 样本复杂度 $O(sum_i Delta_i^(-2) log(K\/delta))$ 量级。【本书推断】验证环节应显式建模为最优臂辨识，先算清候选数、差距与预算的账再谈结论；前提是_信息屏障_——验证集不可被改进算子接触，数据污染已被证实造成显著性能虚高 @xu2024contamination，时间门控与轮换私有题是标准对策 @white2025livebench。

== 2026 视角：Agentic RL 的再形式化

本章构件正在 agentic RL 前沿被重新激活。其一，*POMDP 再形式化已成共识*：传统 LLM-RL 是退化的单步 MDP，agentic RL 是时间延展的 POMDP——多步行动、部分观测、回合末稀疏奖励 @zhang2026agentic；上下文窗口即信念状态的有损压缩，而回合级优势对一次错误调用与数十轮正确动作一视同仁，GRPO 式信用分配的模板崩溃成为未解问题 @yao2026credit。其二，*信用分配沿四线推进*：轮级 MDP 抽象（Turn-PPO @li2026turnppo）、时序结构利用（RTPO @rtpo2026）、信赖域的多智能体化、留一法反事实归因 @yao2026credit。其三，*改进对象分层化*：改权重（想象空间 RL @yang2026rise）、改 harness（离线 RL 学执行策略 @harnessmdp2026）、改实验策略（期望信息增益为可验证奖励 @arbed2026）、改技能，四层分别适配信赖域、保守离线界、信息论准则与统计验收四套工具。【本书推断】这组进展强化三条全书主张：POMDP 与信用分配是主线而非附录；改进算子按作用对象分层、各层适用不同收敛工具；验证标准已从倡议变为准入门槛。

== 本章小结

本章建立了全书地基：Bellman 压缩映射给出最优性的存在、唯一与可计算性；POMDP 的信念状态与 PWLC 结构把"看不全的世界"纳入同一框架；强化学习以 Robbins–Monro 条件换几乎必然收敛、以占用测度技巧换可采样的策略梯度（@eq:ch02-pg）、以信赖域换近似单调改进；LQR 与 MPC 同 RL 构成"规划—学习"连续谱；统计推断裁决"改进是否真实"。

#keybox(title: [本章要点])[
- Bellman 最优算子在 $gamma < 1$ 时是模 $gamma$ 的压缩映射：存在性、唯一性、几何收敛三位一体（VI：$gamma^n$；PI：逐点单调、有限步）。
- POMDP 等价于信念 MDP，最优值函数分段线性凸；部分可观测是具身场景的常态——_记忆就是信念_。
- Q-learning 收敛需 Robbins–Monro 步长 + 无限访问 + 查找表；"致命三元组"齐备可致发散，离线改进必须用保守化兜底。
- 策略梯度定理（@eq:ch02-pg）：梯度不依赖 $nabla_theta d^(pi_theta)$ 故可采样估计；基线只降方差。TRPO 用信赖域买近似单调性，PPO 用裁剪买简洁。
- LQR 的 Riccati 方程是 Bellman 方程在二次型类上的显式不动点；MPC = 在线版一步策略迭代，与 model-based RL 连成连续谱。
- 验证即统计推断：置信区间 + 配对比较 + 最优臂辨识；信息屏障是一切结论前提。
]
