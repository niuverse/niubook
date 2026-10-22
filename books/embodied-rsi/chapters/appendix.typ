#import "../template.typ": *

#heading(numbering: none)[附录 A　符号表]
// 附录 A 表格按 "A-N" 编号（附录标题无自动编号，需手工重置表计数器）
#counter(figure.where(kind: table)).update(0)
#set figure(numbering: n => "A-" + str(n))

本附录汇总全书统一使用的核心符号，按主题分组；"首次出现"一栏给出定义章节，后续章节沿用不再重定义。期望与概率一律写作 $EE$ 与 $PP$，实数集记 $RR$。

*A.1　决策问题与环境（第 2 章）*

#figure(
  table(
    columns: (auto, 1fr, 5.5em),
    [符号], [含义], [首次出现],
    [$cal(M)$], [马尔可夫决策过程 $cal(M) = (cal(S), cal(A), P, r, gamma, mu_0)$；POMDP 扩展记 $cal(M)_P$], [第 2 章],
    [$cal(S)$, $cal(A)$, $cal(O)$], [状态、动作、观测空间（$cal(A)$ 在 RSI 语境下另指系统状态空间，见文末约定）], [第 2 章],
    [$P(s' mid s, a)$], [转移核（环境动力学）；观测核记 $O(o mid s', a)$], [第 2 章],
    [$r(s, a)$, $gamma$], [奖励函数（轨迹简写 $r_t$）；折扣因子 $gamma in [0, 1]$], [第 2 章],
    [$tau$], [轨迹 $tau = (s_0, a_0, r_0, s_1, dots)$；环境交互时间指标记 $t$，与 RSI 世代指标 $k$ 区分], [第 2 章],
  ),
  caption: [MDP/POMDP 与环境记号],
)

*A.2　策略、值函数与优化（第 2 章）*

#figure(
  table(
    columns: (auto, 1fr, 5.5em),
    [符号], [含义], [首次出现],
    [$pi_theta (a mid s)$], [参数化随机策略；$theta$ 为策略参数（亦泛指模型权重）], [第 2 章],
    [$V^pi (s)$, $Q^pi (s, a)$], [状态值函数与动作值函数；最优者记 $V^*$, $Q^*$], [第 2 章],
    [$A^pi (s, a)$], [优势函数 $A^pi = Q^pi - V^pi$], [第 2 章],
    [$J(theta)$], [期望回报目标 $J(theta) = EE_(tau ~ pi_theta) [sum_t gamma^t r_t]$；$hat(J)_n$ 为 $n$ 个样本的均值估计], [第 2 章],
    [$EE$, $PP$], [期望与概率算子], [第 2 章],
    [$D_"KL"$], [KL 散度（信赖域约束与正则项）], [第 2 章],
  ),
  caption: [策略、值函数与优化记号],
)

*A.3　元学习与实验设计（第 3 章）*

#figure(
  table(
    columns: (auto, 1fr, 5.5em),
    [符号], [含义], [首次出现],
    [$cal(T)$, $p(cal(T))$], [任务与任务分布（元学习外层优化的对象）], [第 3 章],
    [$phi_i$], [内层适配参数 $phi_i = theta - alpha nabla_theta cal(L)_(cal(T)_i)$（MAML）], [第 3 章],
    [$xi in Xi$, $y$], [贝叶斯实验设计的设计变量与实验观测], [第 3 章],
    [$"EIG"(xi)$], [期望信息增益，贝叶斯实验设计的效用函数], [第 3 章],
  ),
  caption: [元学习与实验设计记号],
)

*A.4　递归自我改进形式化（第 4 章）*

#figure(
  table(
    columns: (auto, 1fr, 5.5em),
    [符号], [含义], [首次出现],
    [$A_t$], [自我改进系统第 $t$ 代状态（代码、权重、策略、工具集、harness 配置等一切可修改成分）；$A_t in cal(A)$], [第 4 章],
    [$U : cal(A) -> RR$], [系统性能度量；经验评估记 $hat(U)$], [第 4 章],
    [$Phi : cal(A) -> 2^cal(A)$], [改进算子：从当前系统可达的候选修改集合；一次具体修改（提案）记 $m in Phi(A_t)$], [第 4 章],
    [$I_t subset A_t$], [改进器子系统：负责提议、评估与采纳修改的机制], [第 4 章],
    [$C_t$, $Delta_t$], [能力水平 $C_t = U(A_t)$ 与逐代增量 $Delta_t = C_(t+1) - C_t$], [第 4 章],
    [$cal(D)_"val"$, $delta_0$], [验证集；最小重要效应量（验证协议预注册参数）], [第 4、9 章],
  ),
  caption: [RSI 形式化记号（全书沿用；闭环章节世代指标亦作 $k$）],
)

*A.5　Harness 与闭环框架（第 5、10 章）*

#figure(
  table(
    columns: (auto, 1fr, 5.5em),
    [符号], [含义], [首次出现],
    [$cal(H)$], [Harness：模型之外的全部脚手架（loop、tools、skills、sub-agents、hooks、MCP、sessions）], [第 5 章],
    [$cal(A)_"llm"$], [LLM 智能体 $cal(A)_"llm" = (M, cal(H))$，$M$ 为基础模型：$"Agent" = "Model" + "Harness"$], [第 5 章],
    [$(H, Theta, Phi, E)$], [Physical RSI 四元组：执行系统 = harness $H$ + 参数模型 $Theta$；改进程序 $Phi$；独立评估器 $E$], [第 10 章],
    [$tilde(X)_k$], [扩展闭环状态 $tilde(X)_k = (H_k, Theta_k, Phi_k, M_k, L_k)$], [第 10 章],
    [$M_k$], [记忆/经验库（蒸馏技能、教训、世界模型残差、课程历史）], [第 10 章],
    [$L_k$], [证据账本（提案、证据、验证与提交/回滚事件的只增序列）], [第 10 章],
    [$cal(V)_k$], [第 $k$ 轮验证机制（独立评估器 $E$ 的执行体）], [第 10 章],
    [$Delta J_k$], [第 $k$ 轮的改进量（L5 判据要求序列 ${Delta J_k}$ 递增且有独立受控证据）], [第 10 章],
  ),
  caption: [Harness 与 Embodied RSI 闭环框架记号],
)

*A.6　进化搜索与安全约束（第 14、16 章）*

#figure(
  table(
    columns: (auto, 1fr, 5.5em),
    [符号], [含义], [首次出现],
    [$cal(B)$], [行为描述子空间（QD/MAP-Elites 的"照亮"对象）；档案单元记 $c in cal(B)$], [第 14 章],
    [$f(x)$], [目标/适应度函数（QD 中与行为描述子联合优化）], [第 14 章],
    [$c_i (s, a)$, $d_i$], [CMDP 的第 $i$ 个代价函数与安全预算；约束为 $J_(c_i) (theta) <= d_i$], [第 16 章],
  ),
  caption: [进化搜索与安全约束记号],
)

#remark(title: [同名符号冲突的使用约定])[
全书三处刻意的同名记号均按上下文区分：(i) $cal(A)$ 在第 2 章为动作空间、在第 4 章 RSI 形式化中为系统状态空间（$A_t in cal(A)$）；(ii) $cal(T)$ 在第 2 章为 Bellman 算子（总带作用对象 $(cal(T) V)(s)$）、在第 3 章为任务（总出现在 $cal(T)_i$ 或 $p(cal(T))$ 中）；(iii) $rho$ 为平均回报，占用测度一律写作 $rho^pi$ 或 $d^pi$。观测核 $O(o mid s', a)$ 不单独使用字母 $O$。
]

#heading(numbering: none)[附录 B　改进验证协议清单]

本清单是第 9 章"七步验证协议"（本书提出）的可打印浓缩版，供实验记录与评审核对。整体逻辑是漏斗式过滤：候选修改 $m$ 从生成到被认证为改进须依次通过七道门，每道门针对一类已知失效模式（Goodhart 博弈、评估污染、统计噪声、分布内锐化、静默退化、评估器被操纵、不可复现），且每道门的输出——无论通过与否——都必须写入证据账本 $L_k$。任何一项无法勾选，断言即按协议降级（"未决声明""分布内锐化"或"回滚"），而非跳过。

*S1　度量解耦与预注册*

- □ 评估套件、主要效应量度量、最小重要效应 $delta_0$、显著性水平 $alpha$ 与样本量已预注册并加时间戳；"否定结果亦须报告"已写入预注册。
- □ 评估套件满足三者之一：held-out、评测时点之后发布、第三方生成。
- □ 训练/选择管线对评估套件的访问日志已审计，确认被改进系统零接触。

*S2　污染审计*

- □ 训练语料、技能库、记忆库已通过 n-gram 与嵌入级双重泄漏检测 @xu2024contamination。
- □ task-ID/答案复述探针测试已执行（能凭任务标识背出答案即红牌）；具身场景已完成任务模板谱系审计。
- □ 泄漏率与剔除可疑样本后的敏感性分析已报告。

*S3　配对差分与置信区间*

- □ 新旧系统在同一任务集上配对 rollout，共享随机种子流；重复次数按功效分析确定（agent 任务建议 $K >= 30$ @hochlehnert2025sober）。
- □ 以任务为聚类单位计算聚类 bootstrap 置信区间；小样本改用 Wilson 区间或贝叶斯后验 @miller2024errorbars @bowyer2025clt。
- □ 报告效应量、区间及区间与 $delta_0$ 的位置关系；成本账本（token / GPU 时 / 真机时长）随效应量一并报告。

*S4　三层泛化面板*

- □ 第一层（同分布 held-out）、第二层（分布偏移：换场景模板/实体/任务组合）、第三层（真实世界小样本，报告 Wilson 区间）证据链齐备且独立成链。
- □ 断言等级已按通过层数标注：仅第一层 = "分布内锐化"，两层 = "有限泛化"，三层齐备方可记"能力提升" @huang2024sharpening @song2025mindthegap。
- □ 面板构成与淘汰标准已写入预注册。

*S5　回归与保持性检查*

- □ 固定回归集上的向后保持率与最差案例退化幅度已报告；安全关键能力的一票否决门槛已检查。
- □ 已做谱系级纵向评估：跨多世代跟踪最坏回归、保持率与算力效率 @safeevolve2026。
- □ 退化超阈的回滚事件已触发并写入证据账本。

*S6　对抗验证评估器*

- □ ImpossibleBench 式"通过即作弊"探针已部署，评估管道被利用的倾向已量化 @zhong2025impossiblebench。
- □ 评估器、熔断器、评分脚本确认位于被评估者的写域之外 @wang2026harnesstampering @thaman2026rhb。
- □ 改进前后评估代码、测试文件与配置的逐行 diff 审计已完成。

*S7　可复现工件冻结*

- □ harness 版本、随机种子、环境/仿真器版本与评估代码的精确哈希已冻结；轨迹级日志至少对审计方可查询。
- □ 工件已按组件版本化并支持回滚（组件版本图可参照 SafeEvolve 的工程样板）@safeevolve2026。
- □ 已知局限与失效边界已声明；七步全部通过后候选修改方转为"认证改进"。

#remark(title: [使用说明])[
本清单与第 9 章正文的关系是"操作化"而非替代：各步骤的动机、失效模式分析与统计细节见第 9 章，特别是"优化目标与证据来源解耦"这一第一公理 @skalse2022rewardhacking @wang2026equilibrium。七步协议是全书对任何"改进断言"的最低要求；第 16 章在此基础上叠加安全层，第 17 章讨论协议尚不能覆盖的开放问题。
]

#heading(numbering: none)[附录 C　2026 下半年前沿大事记]

本附录按时间顺序整理 2025 年 8 月至 2026 年 10 月（本书截稿时点）与 Embodied RSI 直接相关的关键进展，作为各章前沿讨论的编年索引。标注"（新闻级）"者为行业事件，证据等级低于论文。

// 长表直接放置（可跨页），手工表题与 figure 标题样式一致
#block(sticky: true)[
  #set text(size: 9pt)
  #text(fill: accent, weight: "semibold")[表 C-1]
  #text(fill: ink)[：Embodied RSI 前沿大事记（2025-08 至 2026-10）]
]

#table(
    columns: (5.5em, 1fr),
    table.header([时间], [事件]),
    [2025-08], [Google DeepMind 发布 Genie 3：720p/24fps 实时交互世界模型，明确定位为"训练具身智能体的仿真器" @deepmind2025genie3。self-evolving agents 两篇奠基综述上线，成为 2026 年该领域的引用基础 @gao2025selfevolvingsurvey @fang2025selfevolvingsurvey2。],
    [2025-10], [Huxley-Gödel Machine（HGM）发布：以"clade 级后验"选择扩展节点，后获 ICLR 2026 Oral @wang2025hgm。PLD 展示 VLA 的"残余 RL 专家 → 自动数据采集 → 蒸馏回通用模型"三段式自我改进管线，真机连续一小时无人工干预 @xiao2025pld。],
    [2025-11/12], [Live-SWE-agent 证明软件工程智能体可在线自进化 @xia2025livesweagent；AgentRL 与 RollArt 把 agentic RL 基础设施推进到全异步解耦阶段 @agentrl2025 @rollart2025。],
    [2026-07], [Harness Engineering 对 11 个生产级 coding harness 做源码级解剖，宣布"harness 完成平台化转身"：harness 变为可 import 的 SDK，并出现编排多家 harness 的 meta-harness @harnessengineering2026；AlphaEvolve 在 Google Cloud 全面 GA（社区同时指出其仍是有界优化器而非完全体 RSI）@deepmind2026alphaevolveimpact。],
    [2026-08], [Mendel Gödel Machine 以"反应规范变异 + 跨谱系杂交"改进 HGM，仅靠进化 scaffold 将开源模型推过 GPT-5 水平 @liu2026mgm；Hierarchical Self-Improvement 把可进化边界扩展到整个 harness @hierarchicalsi2026。安全侧集中爆发：EvoMal 揭示自进化编码 agent 技能库的自毒化蠕虫风险 @evomal2026；harness 篡改审计基准发布 @wang2026harnesstampering。],
    [2026-09], [RegenHarness 提出首个面向具身机器人 agent 的证据门控 RSI 协议：RSI 循环只改 harness 配置且更新器无权弱化自己的验收谓词 @wang2026regenharness；SafeEvolve 以 harness-策略共进化做安全对齐并倡议谱系级纵向评估 @safeevolve2026；Evolutionary Safety 给出递归自我改进安全的首个系统化框架 @gong2026evolutionarysafety；自主研究群体中作弊传染与自发吹哨的案例研究发表 @paglieri2026swarms。工程事件：DeepSeek Harness 沙箱逃逸 CVE-2026-82533 披露（新闻级）。],
    [2026-10], [纲领成形月：《Who Improves the Robot?》形式化 Physical RSI 四元组 $(H, Theta, Phi, E)$ 与 L0–L5 分级，并断言现有文献无任何系统达到 L5 @zhou2026physicalrsi；EmbodiedEvo 让自进化 coding agent 直接充当闭环机器人策略 @li2026embodiedevo；RSI 专用评测环境 RSIGym 与 RSIBench-Data 出现 @meng2026rsigym @meng2026rsibenchdata；《Auditing the Product, Not the Recursion》指出多数 RSI 声明只审计了产物而非递归本身 @chen2026auditing；EmbodiedRSI @song2026embodiedrsi 与 SEAR @wang2026sear 等同周涌现——"Embodied RSI"一词事实上已经成军。],
)

#remark(title: [证据等级与版本说明])[
本大事记的 arXiv 条目均按编号核对过摘要；部分 2026 年 9–10 月新论文的出版信息尚待最终确认（书目中以 UNVERIFIED 标注），行业事件一律标注"新闻级"。本书以 2026 年 10 月为知识截点；此后的进展请参照各章"最新进展与未解决问题"一节的框架自行归档。
]
