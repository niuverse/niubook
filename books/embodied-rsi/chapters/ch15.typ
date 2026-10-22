#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 工程实践：可扩展 Embodied RSI 参考框架与端到端示例

前面各章建立了 Embodied RSI 的理论框架、harness 设计原则、自我修改机制与构件库；本章把它们落到一套#strong[可真实运行的参考实现]上：配套代码库 `examples/` 下的最小具身 RSI 闭环（约 1600 行 Python），用二维质点到达任务跑通"任务生成 → 实验设计 → 仿真执行 → 轨迹分析 → 失败归因 → 提出改进 → 修改 → 验证 → 经验积累"九环节。示例刻意不调用任何 LLM API——"提出改进"由规则算子承担——但接口与决策流与真实 LLM 驱动系统#emph[完全一致]：本章讲的是一套"接口先行"的参考框架，应作为"可执行的协议规范"来读。

== 设计目标与参考架构

框架的第一个决策是#strong[范围克制]：只闭环"仿真内的策略调参"，教学价值在于把闭环#emph[骨架]跑通并把每个关节做成可替换接口。三个工程目标：#strong[简洁]——只依赖 `numpy` 与 `pyyaml`；改进算子必须能#emph[读懂]它要修改的系统，mini-SWE-agent 以约百行 harness 达到 SWE-bench Verified 约 65% 的经验 @yang2024sweagent 说明 harness 应当做减法。#strong[模块化]——九环节映射为六个正交模块，只经显式数据结构通信。#strong[可扩展]——任务生成可升级为 LLM/POET 式合成 @wang2019poet，仿真可升级为 GPU 并行集群 @isaaclab2025，改进算子可升级为 LLM 代理 @zhang2025dgm，接口签名不变。

三目标收敛到#strong[Agent-Native 接口]设计——第 5 章四原则（可观测、可修改、可验证、可追溯）在代码层的具体化【本书提出】。为什么坚持 schema 而非自然语言约定？因为闭环的每一环都是另一环的"程序输入"：结构化归因把提案者的错误模式从"理解错"退化为"选错算子"（可被白名单兜底），三元组式提案把修改应用退化为纯机械操作。全部"智能"安排在 schema 的生产与消费两侧，schema 本身保持机械与贫乏——贫乏的接口才是可测试、可回归、可审计的接口。

@fig:arch 给出参考框架的模块架构。系统分三层：#strong[配置层]（单个 YAML 文件声明全部可调面，点分路径如 `policy.kp` 是改进提案的唯一寻址方式）；#strong[编排层]（`loop/rsi_loop.py` 把配置"编译"为实验规约并驱动九环节）；#strong[执行层]（MuJoCo 质点环境与作为"被改进对象"的 PD 控制器）。配置的边界就是权限的边界：不在配置中的行为（如验收谓词）天然处于提案面之外。

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let acc = rgb("#0f5c5c")
    let acc2 = rgb("#8c5a2b")
    let softbg = rgb("#f6f4ef")
    let bluebg = rgb("#eef3f5")
    let boxw = 2.3
    let boxh = 0.66
    let box(x, y, label, sc, fc: softbg, w: boxw) = {
      rect((x - w/2, y - boxh/2), (x + w/2, y + boxh/2), radius: 0.08, fill: fc, stroke: 0.9pt + sc)
      content((x, y), text(size: 7pt)[#label])
    }
    let arr(a, b, lc: acc, dashed: false) = {
      if dashed {
        line(a, b, mark: (end: ">"), stroke: (paint: lc, thickness: 0.75pt, dash: "dashed"))
      } else {
        line(a, b, mark: (end: ">"), stroke: 0.75pt + lc)
      }
    }
    // 配置层
    box(2.0, 6.1, [configs/\*.yaml\ 点分路径配置], acc2)
    box(7.0, 6.1, [loop/rsi_loop.py\ 九环节编排 · keep/rollback], acc, fc: bluebg, w: 3.4)
    arr((3.2, 6.1), (5.3, 6.1))
    // harness 容器
    rect((0.5, 2.6), (13.5, 5.0), radius: 0.12, fill: softbg, stroke: 0.9pt + acc)
    content((0.72, 4.72), anchor: "west", text(size: 7.5pt, fill: acc, weight: "bold")[harness/ —— Agent-Native Harness])
    let xs = (1.95, 4.5, 7.05, 9.6, 12.15)
    let labs = ([task_gen\ 任务生成], [orchestrator\ 编排执行], [evaluator\ 指标+归因], [proposal\ 改进提案], [memory\ 经验记忆])
    for i in range(5) { box(xs.at(i), 3.5, labs.at(i), acc) }
    // sim 容器
    rect((2.3, 0.3), (8.6, 1.7), radius: 0.12, fill: bluebg, stroke: 0.9pt + acc)
    content((2.52, 1.48), anchor: "west", text(size: 7.5pt, fill: acc, weight: "bold")[sim/ —— 仿真执行层])
    box(3.7, 0.8, [point_mass\ MuJoCo 质点环境], acc, fc: white)
    box(7.0, 0.8, [controller\ PD 控制器(被改进)], acc2, fc: white)
    // 主循环到各模块
    arr((5.6, 5.77), (1.95, 5.0))
    arr((6.3, 5.77), (4.5, 5.0))
    arr((7.0, 5.77), (7.05, 5.0))
    arr((7.7, 5.77), (9.6, 5.0))
    arr((8.4, 5.77), (12.15, 5.0))
    // 编排到 sim 与回传
    arr((4.2, 3.17), (3.7, 1.7))
    content((3.0, 2.4), text(size: 6.5pt, fill: acc)[ExperimentSpec])
    arr((7.0, 1.7), (7.0, 3.17), lc: acc2, dashed: true)
    content((7.75, 2.4), frame: "rect", fill: white, stroke: none, padding: 1pt, text(size: 6.5pt, fill: acc2)[Trajectory])
    // controller 被提案修改
    arr((9.6, 3.17), (7.6, 0.68), lc: acc2, dashed: true)
    content((10.3, 1.9), text(size: 6.5pt, fill: acc2)[提案修改 policy.\*])
    // memory 检索回提案
    arr((11.6, 3.3), (10.15, 3.3), lc: acc2, dashed: true)
    // LLM 替换点标注
    rect((8.3, 3.05), (13.0, 4.0), radius: 0.1, stroke: (paint: acc2, thickness: 0.9pt, dash: "dashed"), fill: none)
    content((10.65, 4.35), text(size: 7pt, fill: acc2, weight: "bold")[LLM 代理替换点（接口不变）])
  }),
  caption: [参考框架模块架构。实线为主数据流，虚线为轨迹回传、提案修改与经验检索；赭色虚线框标出 LLM 代理替换点（接口不变）。],
) <fig:arch>

@tab:modules 汇总各模块的职责、接口与扩展点。`RuleBasedImprover` 与 `CurriculumTaskGenerator` 是仅有的两个"智能占位符"，真实系统中分别替换为 LLM 提案代理与 LLM/POET 式任务合成 @hu2025adas，输出 schema 不变；`Orchestrator` 在真实系统中额外承担容器化分发与制品回收 @isaaclab2025，结果结构保持不变，扩展对上层透明。

#figure(
  {
    set text(size: 8pt)
    table(
      columns: (3.2cm, 4.8cm, 3.6cm, 1.7cm),
      inset: 4pt,
      [模块（闭环环节）], [关键接口], [生产扩展点], [对应章节],
      [`task_gen.py`（任务生成）], [`TaskSpec`、`CurriculumTaskGenerator`], [LLM/POET 开放式任务合成], [第 13、14 章],
      [`orchestrator.py`（实验设计/执行）], [`ExperimentSpec`、`Orchestrator.run`], [容器化 worker、Isaac/MJX 并行], [第 10、11 章],
      [`point_mass.py`（仿真执行）], [`SimParams`、`DomainRandomization`、`Trajectory`], [真实动力学、GPU 引擎、真机], [第 11 章],
      [`controller.py`（被改进对象）], [`act(obs)`、`PDControllerConfig`], [神经网络策略、训练脚本补丁], [第 12 章],
      [`evaluator.py`（轨迹分析/归因）], [`EpisodeMetrics`、`FailureReport`], [LLM 归因、学到的奖励模型], [第 13、14 章],
      [`proposal.py`（提出改进/修改）], [`ImprovementProposal`、`RuleBasedImprover`], [LLM 提案代理 + 守门审查], [第 8 章],
      [`rsi_loop.py`（验证/主循环）], [`build_spec`、`heldout_score`、`run_loop`], [证据门控协议、多级回归], [第 8、10 章],
      [`memory.py`（经验积累）], [`SQLiteMemory`（iterations/proposals 表）], [向量检索、跨运行经验库], [第 6 章],
    )
  },
  caption: [模块 × 闭环环节 × 接口 × 扩展点 × 对应章节对照表],
) <tab:modules>

== 关键接口精选

本节讲解三个最关键的接口（代码摘录自 `examples/` 真实源码）。`ExperimentSpec` 把"一批任务 × 一份策略/仿真配置"参数化为编排器的唯一输入：`frozen=True` 保证实验发出后不可篡改，安全约束（`max_episodes`、`time_budget_s`）作为#emph[一等字段]与实验内容在同一对象中被声明与审计；`build_spec` 把 YAML 编译为 frozen dataclass，隔离了"被改的东西"（配置字典）与"跑的东西"（类型化对象）。闭环可信的关键在留出集：`heldout()` 用独立固定种子生成覆盖完整距离区间的任务集，与训练课程解耦——验收基准必须是提案者够不到的常量 @wang2026regenharness。评估器把聚合指标映射为结构化 `FailureReport`——闭环中"感知"与"决策"之间的桥梁、提案代理的输入语言：

```python
@dataclass(frozen=True)
class FailureReport:
    """结构化失败归因报告：proposal.py 的消费对象。"""
    cause: str              # 失败原因标签（面向提案者）
    detail: str             # 证据描述
    severity: float         # 严重度（归一化超出量，越大越优先）
    suggested_operator: str # 建议的改进算子名
    evidence: Dict[str, float]  # 支撑证据（关键指标取值）
```

规则归因按优先级实现六条规则（欠驱动 → `tune_force_limit`、精度不足 → `tune_kp`、超调 → `tune_kd` 等）。两个字段承担主要工程语义：`severity` 使不同量纲的异常可排序；`suggested_operator` 把开放的诊断空间投影到白名单化的处方空间，将 LLM 代理约束在可审查的离散集合内。

`ImprovementProposal` 是对配置的#emph[一次原子修改]——每条提案可独立审计、独立计数、独立回滚：

```python
@dataclass(frozen=True)
class ImprovementProposal:
    """一次原子改进提案。"""
    proposal_id: str   # 唯一标识
    operator: str      # 产生该提案的算子名
    param_path: str    # 点分参数路径（如 "policy.kp"）
    old_value: float   # 修改前取值
    new_value: float   # 修改后取值
    rationale: str     # 理由（真实系统中由 LLM 撰写）
    source_cause: str  # 触发该提案的失败原因标签

def apply_proposals(config: Dict[str, Any],
                    proposals: List[ImprovementProposal]) -> Dict[str, Any]:
    """将提案应用到配置的深拷贝上并返回新配置（原配置保持不变，便于回滚）。"""
    new_config = copy.deepcopy(config)
    for proposal in proposals:
        set_path(new_config, proposal.param_path, proposal.new_value)
    return new_config
```

keep/rollback 协议由此平凡而安全：`incumbent` 永不被原地修改，候选是深拷贝应用提案后的新对象；留出集验证通过则指针换绑，否则丢弃候选——回滚不是"改回去"而是"从未发生"。算子注册表同时充当#emph[参数白名单与能力声明]：提案只能修改注册过的路径、每路径每轮至多一次、取值裁剪到物理合理区间——"权限"从可被注入的散文劝告变成结构性约束，与 DGM、RegenHarness 的版本化 rollout/rollback 同构 @zhang2025dgm @wang2026regenharness。经验记忆用标准库 `sqlite3` 实现 `iterations`（决策、理由、双指标、配置快照）与 `proposals`（旧值/新值/采纳状态）两张表——任何一次"变好"都能回答"是谁、何时、凭什么证据改的"。

== 端到端走查：一次 RSI 迭代的完整数据流

@fig:seq 刻画一次迭代的九环节数据流。注意：#strong[归因只看训练集，验证只看留出集]——诊断信号与验收信号来自不相交的任务分布，这是防过拟合的设计。

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let acc = rgb("#0f5c5c")
    let acc2 = rgb("#8c5a2b")
    let softbg = rgb("#f6f4ef")
    // 生命线
    let xs = (0.9, 3.4, 5.9, 8.4, 10.9, 13.4)
    let names = ([主循环\ rsi_loop], [任务生成\ task_gen], [编排器\ orchestrator], [仿真\ sim], [评估\ evaluator], [提案/记忆\ proposal/memory])
    for i in range(6) {
      rect((xs.at(i) - 1.05, 5.5), (xs.at(i) + 1.05, 6.15), radius: 0.08, fill: softbg, stroke: 0.9pt + acc)
      content((xs.at(i), 5.82), text(size: 6.6pt)[#names.at(i)])
      line((xs.at(i), 5.5), (xs.at(i), 0.15), stroke: (paint: acc, thickness: 0.6pt, dash: "dashed"))
    }
    let msg(a, b, y, label, lc: acc) = {
      line((xs.at(a), y), (xs.at(b), y), mark: (end: ">"), stroke: 0.75pt + lc)
      content(((xs.at(a) + xs.at(b)) / 2, y + 0.17), frame: "rect", fill: white, stroke: none, padding: 0.8pt, text(size: 6.2pt, fill: lc)[#label])
    }
    msg(0, 1, 5.1, [① sample\_batch(n) → List\[TaskSpec\]])
    msg(0, 2, 4.55, [② run(ExperimentSpec train)])
    msg(2, 3, 4.0, [③ run\_episode → Trajectory])
    msg(2, 4, 3.45, [④ trajectory\_metrics → aggregate])
    msg(4, 0, 2.9, [⑤ FailureReport\[］(按 severity 排序)], lc: acc2)
    msg(0, 5, 2.35, [⑥ propose(cfg, reports) → ImprovementProposal\[］], lc: acc2)
    msg(0, 2, 1.8, [⑦⑧ run(候选配置, heldout) → heldout\_score 对比])
    msg(0, 5, 1.25, [⑨ log\_iteration(keep / rollback / skip)], lc: acc2)
    content((-0.1, 0.5), anchor: "west", text(size: 6.2pt, fill: acc2)[保留则 incumbent ← candidate，否则丢弃候选（深拷贝，天然回滚）])
  }),
  caption: [一次 RSI 迭代的端到端时序。编号对应闭环九环节；赭色消息为提案与记忆链路。],
) <fig:seq>

用一份刻意"失调"的演示配置观察闭环：运动学后端、`horizon: 1.0`s、成功半径收紧到 `0.03`、初始 `policy.kp: 1.0`——留出集成功率为 0。以下为真实运行的终端输出（节选，`keep_margin: 0.005`）：

```text
[RSI][iter 0] 基线留出集得分 = -0.0445
        [heldout-baseline] 回合=8 成功率=0.00 终末误差=0.870 超调=0.000 能耗=0.95
[RSI][iter 1] KEEP | 提案: policy.kp: 1.0->1.3    (留出集 -0.0445 -> -0.0390)
[RSI][iter 2] KEEP | 提案: policy.kp: 1.3->1.69    (留出集 -0.0390 -> -0.0325)
[RSI][iter 3] KEEP | 提案: policy.kp: 1.69->2.197  (留出集 -0.0325 -> -0.0250)
[RSI][iter 4] KEEP | 提案: policy.kp: 2.197->2.8561 (留出集 -0.0250 -> -0.0166)
[RSI][iter 5] KEEP | 提案: policy.kp: 2.8561->3.71293, curriculum.difficulty: 0.4->0.3
        留出集得分 -0.0166 -> 0.4905，提升达到阈值 0.005，保留候选配置。
[RSI][iter 6] 无改进提案，跳过。
[RSI][iter 7] ROLLBACK | 提案: curriculum.difficulty: 0.3->0.45
        留出集得分 0.4905 -> 0.4905，未达到保留阈值，回滚到上一轮配置。
[RSI][iter 9] KEEP | 提案: policy.kp: 3.71293->4.826809  (留出集 0.4905 -> 0.7372)
```

这段日志包含闭环的全部四种决策路径。#strong[改进]（iter 1–5）：归因器产出"到达精度不足"（`tune_kp`），每轮把 kp 乘以 1.3；前四轮成功率仍为 0，但终末误差从 0.870 单调降到 0.224 故判保留；第五轮 kp=3.71 时留出集成功率跃升至 0.38，得分跳到 +0.49——复合验收信号在成功率尚未"点亮"的爬坡期提供了改进所需的梯度。#strong[混合提案]（iter 5）："课程难度过高"归因触发第二条提案，与调参提案原子提交、共同受检。#strong[跳过]（iter 6、8）：指标均在阈值内时无归因产出，循环显式记录 `skip` 而非静默空转。#strong[回滚]（iter 7）：提案提升课程难度，但留出集（与课程难度无关）得分零变化，未达 `keep_margin`，候选被丢弃。

回滚路径揭示了重要设计点：若 `keep_margin` 设为 0，同样的课程提案将因"平局即保留"一路推进——difficulty 从 0.3 KEEP 到 0.95，留出集得分却始终停在 0.7372：课程难度在涨，能力没有涨。这是#emph[课程通胀]，一种对验证器的软性 Goodhart 攻击 @manheim2018goodhart；`keep_margin` 把"无证据的推进"挡在门外。另注意 iter 0 先把初始配置记为 `baseline`——没有基线，后续"提升"无从谈起 @zhang2026selfharness。复现只需 `python -m loop.rsi_loop --config configs/smoke_test.yaml`。

== 扩展到生产规模的路径

四个替换点各对应一条升级路径，建议按"先智能、后算力、再物理、最后模型"的顺序实施。#strong[第一步：规则算子 → LLM 提案代理（工程量小，风险中）。]输入 `FailureReport` 加记忆检索结果，输出同一 schema 的提案；进阶形态是代码补丁，须叠加守门审查与沙箱执行 @zelikman2024stop @zhang2025dgm；agent 主导的改进尚无公认收益证据 @li2026harbor，应先接 RSIGym/SEAR 类基准做对照再放量 @meng2026rsigym @wang2026sear。#strong[第二步：单仿真 → Isaac/MJX 并行集群（中，低）。]工程量在分布式基础设施 @mujoco_playground2025；主要风险是并行非确定性污染留出集——种子必须随任务分发而非在 worker 上现取。#strong[第三步：kinematic → 真实动力学 → 真机（大，高）。]仿真内免费的奖励与成功判定不复存在，验证器成为最大单点瓶颈 @lee2026roboreward，不可逆后果要求护栏 @ahn2024autort @zhou2026physicalrsi。#strong[第四步：世界模型预验证（中，中，本书推断）。]留出集验证前用学到的世界模型廉价预筛 @hao2023rap @hafner2025dreamerv3，但预筛只能否决不能保送——最终判定权必须留在真实留出集。四步是#emph[依赖关系]而非并列清单：提案质量未被基准验证之前扩大算力，只是把更多计算花在噪声爬山上。

== 安全沙箱工程

`harness/safety.md` 把沙箱分为进程内软约束与容器级硬隔离两层。已内置的#strong[软约束]共九项：回合数硬上限与墙钟预算内嵌于 `ExperimentSpec`；单回合步数上限防策略死循环；`try/except` 隔离单回合异常；提案侧有参数白名单、取值裁剪与每路径每轮一次修改；判定侧有 keep/rollback 与决策可追溯。

#strong[威胁模型]三条。其一，#emph[奖励 hacking]：提案可能修改 `reward.*` 权重虚增塑形回报 @skalse2022rewardhacking @krakovna2020specgaming——保留判定因此刻意#emph[不]使用任何可被提案修改的量：

```python
def heldout_score(agg: AggregateMetrics) -> float:
    """留出集综合得分（保留/回滚判据）。刻意不使用可被提案
    修改的塑形回报（reward.*），防"奖励 hacking"。"""
    if agg.n_episodes == 0:
        return -1e9
    return (agg.success_rate
            - 0.05 * agg.mean_final_distance
            - 0.001 * agg.mean_control_energy)
```

其二，#emph[课程坍缩]：`adjust_curriculum` 不断降难度会让训练指标虚高——留出集覆盖完整距离区间且不受课程影响，`keep_margin` 挡住"平局推进"。其三，#emph[记忆污染]：检索优先 `accepted=1` 且近期的条目；记忆与验证装置的完整性应与模型权重同等防护 @wang2026harnesstampering。

#strong[硬隔离]清单面向生产部署：每次"应用提案 → 仿真验证"在独立容器中执行、仓库只读挂载；cgroups 限额、提案执行默认禁网；代码补丁经静态检查与守门复核后才进仿真；保留判定必须在提案侧不可读取种子的固定留出集上进行；迭代数与提案数设全局速率上限，连续回滚触发熔断——与 RegenHarness 的证据门控协议同构 @wang2026regenharness。沙箱与人类监督是接力关系：软约束保证失控有界，硬隔离保证失控无害，但"什么样的改进算改进"仍须由人类通过 `thresholds`、`heldout_score`、`keep_margin` 三处显式注入——它们不应对提案代理开放。

== 本章小结

本章把全书概念落到可运行的参考实现上：用类型化 schema 实现 Agent-Native 接口，核心手法是"智能在两端、接口在中间"。一次真实冒烟运行同时展示了改进（kp 1.0 → 3.71，留出集得分 −0.04 → +0.49）、混合提案、跳过与回滚四种路径及 `keep_margin` 对课程通胀的防御。验证器校准、同轮多提案的因果归因、跨代遗忘回归与元层改进是通往第 16 章的未解决问题 @meng2026rsigym @wang2026regenharness。建议读者先复现上述日志，再替换 `RuleBasedImprover` 为真实 LLM 代理。

#keybox(title: [本章要点])[
+ Agent-Native 接口优先：任务、实验、指标、归因、提案、记忆全部机器可读且类型化——闭环的每个"读者"都预设为 LLM 代理 @yang2024sweagent。
+ 验收谓词与提案面隔离：留出集固定种子、覆盖全难度，`heldout_score` 不含可被提案修改的塑形回报；`keep_margin` 挡住平局推进（课程通胀）。
+ 原子提案 + 深拷贝应用使回滚"从未发生"；SQLite 决策谱系让每次改进可回答"是谁、何时、凭什么证据改的"。
+ 扩展四步曲：LLM 提案代理 → 并行仿真集群 → 真实动力学与真机（验证器是瓶颈）→ 世界模型预筛（只否决不保送）。
+ 安全分层：软约束（预算、白名单、裁剪、异常隔离）已在进程内；硬隔离（容器、限额、禁网、补丁审查、熔断）是生产部署的前提 @wang2026regenharness。
]
