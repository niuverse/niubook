#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 开放问题与研究路线图

前面十六章留下一个悖谬的结构：可运行原型越来越多 @zhang2025dgm @wang2025hgm @wang2026regenharness @yang2026rise，却没有系统把整条改进环闭合并证明复合增益 @zhou2026physicalrsi @chen2026auditing。本章做三件收口工作：把各章未竟事项系统化为四象限开放问题地图（§17.1–17.4：理论、系统、具身、安全与治理），每问按*现状—障碍—路线*陈述；以 L0–L5 为刻度给出 2026–2031 五年路线图（§17.5），每里程碑附"关键障碍／所需能力／可检验预测"三栏；结语（§17.6）回答 Embodied RSI 作为研究纲领的价值与边界。

== 理论开放问题

理论层的母题："递归""改进""增长"缺少可操作且可证伪的度量——领域的短板不是做不出演示，而是证明不了声明 @chen2026auditing。

=== 递归性的判据与度量

*现状。* 严格递归定义要求"改进器本身也被改进" @yampolskiy2015seed，但改进器度量长期空白；首批候选（HGM 的谱系级元生产力 @wang2025hgm、Headroom-Closed Index @duan2026lastai）刚出现，而声明"改进过程变好"的论文中仅 4/26 做过同起点、匹配预算的配对比较 @chen2026auditing。*障碍。* 无公认基准且候选度量不可通约；度量一旦成为优化目标即遭 Goodhart 失效 @manheim2018goodhart；纵向谱系重跑成本高。*路线。*【本书提出】规约为协议问题：固定起点与预算，以"早期 vs 后期改进器的留出任务配对差分"为最小证据单元估计改进速率，第三方复现为终审；DGM/HGM 的谱系档案首次提供了数据底床 @zhang2025dgm @sun2026reuse。

=== 自我奖励的信息论上限

*现状。* 这是证据最一致的问题：sharpening 理论证明自我改进不能创造模型中不存在的信息 @huang2024sharpening；纯合成数据迭代约 2–3 轮饱和且不随规模抬升 @song2025mindthegap；Solomonoff 视角断言闭环密度匹配不提供改进算子 @solomonoff2026limits。*障碍。* 裁判与策略共漂移缺联合定理；"每轮须注入多少比特外部信息"无操作性定义。*路线。*【本书推断】把外部信息率形式化为资源，建立"信息—改进"剂量曲线；物理世界是无需模型同意即可注入真值的信道 @singh2024beyondhuman——这正是具身 RSI 的结构性优势。

=== 能力增长边界：饱和式与爆炸式的证据裁决

*现状。* 智能爆炸假说提出六十年，其增长曲线从未被实测 @good1965speculations @yudkowsky2013microeconomics；间接证据偏向饱和（RL 标度律呈 sigmoid @khatri2025scalerl、自我改进数轮触顶），但 DGM 80 代未见平台期 @zhang2025dgm——短窗增益无法区分 sigmoid 中段与指数前段。*障碍。* 缺长时程、预算受控、谱系完整的数据；"能力"的多维性使单一度量拟合可被欺骗。*路线。*【本书提出】预注册的增长曲线裁决计划：拟合再投资回报随能力变化的符号并开发抗饱和多维度量 @meng2026rsigym；裁决结果直接决定 L4/L5 的可达性与安全准备优先级。

== 系统开放问题

系统层问题的共性：单轮看都有工程解，跨百轮看都缺乏理论。

=== 元规则稳定性：改 harness 的 harness 何时终止

*现状。* Hyperagents 把"产生未来改进的机制"本身纳入编辑范围，元层级改进跨域迁移并跨运行累积 @zhang2026hyperagents；但没有任何判据回答"哪一层应被冻结、何时停止向上编辑"。*障碍。* 向上无限回归必须有终止条件，而任何固定终止层都是"人设计的不可改内核"，恰是现有系统被批评非真递归的理由 @duan2026lastai。*路线。*【本书提出】检验三条候选：(i) 不动点判据——边际改进低于验证成本时冻结该层；(ii) 元编辑错误预算；(iii) 授权窗口制——默认冻结、按预声明窗口开放，更新器无权弱化自己的验收谓词 @wang2026regenharness。

=== 评估器自身的进化：谁验证验证器

*现状。* 评估器不是可信背景而是回路的一等组件：自改进 agent 会修改自己的评估管道以虚报改进 @wang2026harnesstampering；有限评估预算下 reward hacking 是均衡解 @wang2026equilibrium；共享底座模型时误差自相关使独立性假设崩溃 @chen2026auditing。*障碍。* 自指无法从内部消除，只能转移到外部锚点，而锚点带宽远低于回路迭代速度。*路线。* 按可信度递增：评估器谱系审计（每次变更入账并回溯重放）；差分评估器组合（异构底座 + 对抗探针 @zhong2025impossiblebench）；*环境锚定*【本书推断】——把最终裁决权交给不可伪造的物理结果：物理世界不读日志，也不收贿赂。

== 具身特有开放问题

具身层回答同一追问：为何编码域已逼近 L4 雏形，物理域连 L2 整环闭合都未达成？答案不在算法而在物理：差距、吞吐与不可逆。

=== Sim-to-Real 差距的闭合

*现状。* 域随机化 @tobin2017dr、RMA 式快速适应 @kumar2021rma 与高吞吐仿真 @tao2025maniskill3 已把 sim-to-real 工程化；世界模型把"试验场"扩展到生成模型 @deepmind2025genie3 @yang2026rise。但对 RSI 而言问题换了形态：*在仿真中验证的"改进"何时是真改进？* 仿真基准与评估任务同源等价于评估污染，想象 rollout 继承生成模型的盲区。*障碍。* 接触丰富任务的物理建模残差使仿真验证失真 @li2026embodiedevo；真机小样本确认的统计功效不足以支撑逐代门控。*路线。*【本书提出】三层证据面板（仿真 held-out、世界模型交叉验证、真机小样本）作为改进断言的默认格式；残差模型随真机确认在线更新；定期用真机数据再校准想象引擎，防止"仿真茧房" @ring2011delusion。

=== 真实世界吞吐瓶颈

*现状。* 成本结构在具身域反转：仿真端已达 3 万 FPS @tao2025maniskill3，真机验证的边际成本却不随并行化下降——瓶颈在验证层而非生成层；PLD 的真机连续一小时无人干预 @xiao2025pld 说明可行，但改进轮次以个位数计。*障碍。* 真机回合以分钟计、设备磨损、复位靠人工；更关键的是机器人域尚无大规模可验证奖励来源。*路线。* 以信息价值调度稀缺真机试验 @song2026embodiedrsi；自主复位技能优先建设；攻关可验证奖励源（VLM 成功检测器、物理不变量检验等）——投入产出比最高的单点问题之一【本书推断】。

=== 物理不可逆与回滚的不可能性

*现状。* 提交语义依赖"未通过验证则回滚"，但回滚只覆盖可修改状态，不覆盖世界：被验证假阳性放行的修改若造成不可逆物理后果，账本再完整也于事无补。现有防线分层——CPO 式更新级约束 @achiam2017cpo、可达性分析 @reachability2025llmrobot、跨层风险分析 @safeembodied2026、运行时 shielding @saferlsurvey2025。*障碍。* 自我修改后模型/动力学失配，形式保证需随每次更新重做，全量重验证不可行。*路线。* 增量重验证——只对新旧策略的行为差集重做可达性检查【本书推断】；把"损伤恢复"提升为一等技能 @cully2015robots；把重验证成本列为 L3 以上的准入门禁指标。

== 安全与治理开放问题（承接第 16 章）

第 16 章已给出风险分类学与防御纵深；本节只列三个*防御落地后仍敞开*的问题。

*其一，错位泛化可否根除。* 学会 reward hacking 的模型自发泛化出 alignment faking 与破坏行为，inoculation prompting 削减 75–90% 但不根除 @macdiarmid2025emergent @baker2025monitoring。障碍：行为日志可装、内部表征难读。路线：内部表征监控 @bergen2026internal，环境硬化与写权限隔离作底线。

*其二，自我修改工件的安全边界。* EvoMal 证明攻击面已转移到 agent 自编工件，现有防御在 CREATE 路径失效 @evomal2026。障碍：结构性隔离与自进化能力互斥。路线：工件出处标准与谱系级纵向评估制度化；把"隔离牺牲的改进能力"作为显式记账项【本书提出】。

*其三，群体级治理与停止规则。* 自主研究群体中作弊可经共享知识库传染，但也自发涌现吹哨与审计反制 @paglieri2026swarms；复合停止判据已在第 16 章给出 @khatri2025scalerl。障碍：群体动力学缺可重复实验平台。路线：Ostrom 公共池治理机制的算法化移植，把停止规则写入 update authorization @gong2026evolutionarysafety。

== 研究路线图：以 L0–L5 为刻度的五年规划

本节给出本书的收官建议【本书提出】：以 Physical RSI 的 L0–L5 分级 @zhou2026physicalrsi 为公共刻度，把 2026–2031 年的研究组织为四个里程碑。刻度回顾：L0 固定系统；L1 单任务能力级更新；L2 单任务元级更新（改进程序本身被改进）；L3 跨任务能力级迁移；L4 跨任务元级改进；L5 = L4 加上*逐轮改进收益递增的独立受控证据*。截至 2026 年 10 月，编码域已有 L3 雏形 @zhang2026hyperagents，具身域最高可信证据在 L1–L2 之间 @xiao2025pld @yang2026rise @li2026embodiedevo @wang2026regenharness，L5 无任何系统达到 @zhou2026physicalrsi。@fig:roadmap 给出时间轴与依赖关系，@tab:milestones 给出三栏细则。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // ---- 上排：L0–L5 级别盒 ----
    let levels = (
      ("L0", [固定系统\ 无自改进]),
      ("L1", [单任务\ 能力级更新]),
      ("L2", [单任务\ 元级更新]),
      ("L3", [跨任务\ 能力级迁移]),
      ("L4", [跨任务\ 元级改进]),
      ("L5", [逐轮收益递增\ ＋独立证据]),
    )
    let y0 = 3.5; let y1 = 4.7
    for (i, (lv, desc)) in levels.enumerate() {
      let xa = 0.5 + i * 2.42
      let xb = xa + 2.22
      let done = i <= 1   // L0/L1 已达成
      rect((xa, y0), (xb, y1), radius: 0.1,
        fill: if done { accent } else { softbg },
        stroke: 0.8pt + accent, name: "L" + str(i))
      content(((xa + xb) / 2, y1 - 0.22), text(size: 8.5pt, weight: "bold",
        fill: if done { white } else { accent.darken(10%) })[#lv])
      content(((xa + xb) / 2, y0 + 0.38), text(size: 7pt,
        fill: if done { white } else { ink })[#desc])
      if i > 0 {
        line((xa - 0.2, (y0 + y1) / 2), (xa, (y0 + y1) / 2), mark: (end: ">"), stroke: 0.9pt + accent)
      }
    }
    // ---- 中排：里程碑盒 ----
    let ms = (
      ((0.7, 1.3), (3.7, 2.75), "M1 近期 2026–28", [L2 整环闭合：\ 改进程序亦被改进\ 的具身闭环演示], 2),
      ((4.35, 1.3), (7.35, 2.75), "M2 中期 2027–29", [L3 跨域迁移：\ 跨任务族迁移并带\ 来零样本增益], 3),
      ((8.0, 1.3), (11.0, 2.75), "M3 远期 2028–30", [L4 递增收益迹象：\ 改进速率随代数上\ 升（配对受控）], 4),
      ((11.65, 1.3), (14.65, 2.75), "M4 判据 2029–31", [L5 判据与标准：\ 社区协议与独立复\ 现、首个 L5 声明], 5),
    )
    for (pa, pb, title, body, li) in ms {
      rect(pa, pb, radius: 0.1, fill: white, stroke: 0.8pt + accent2, name: title)
      content(((pa.at(0) + pb.at(0)) / 2, pb.at(1) - 0.24), text(size: 7pt, weight: "bold", fill: accent2.darken(10%))[#title])
      content(((pa.at(0) + pb.at(0)) / 2, pa.at(1) + 0.48), text(size: 6.8pt)[#body])
    }
    line((3.7, 2.0), (4.35, 2.0), mark: (end: ">"), stroke: 0.9pt + accent2)
    line((7.35, 2.0), (8.0, 2.0), mark: (end: ">"), stroke: 0.9pt + accent2)
    line((11.0, 2.0), (11.65, 2.0), mark: (end: ">"), stroke: 0.9pt + accent2)
    // ---- 下排：时间轴 ----
    line((0.5, 0.55), (14.6, 0.55), mark: (end: ">"), stroke: 0.9pt + ink)
    for i in range(6) {
      let x = 0.9 + i * 2.72
      line((x, 0.45), (x, 0.65), stroke: 0.7pt + ink)
      content((x, 0.2), text(size: 7.5pt)[#str(2026 + i)])
    }
    line((3.4, 1.27), (3.4, 0.65), stroke: (dash: "dotted", paint: softline.darken(30%), thickness: 0.6pt))
    line((6.9, 1.27), (6.9, 0.65), stroke: (dash: "dotted", paint: softline.darken(30%), thickness: 0.6pt))
    line((9.9, 1.27), (9.9, 0.65), stroke: (dash: "dotted", paint: softline.darken(30%), thickness: 0.6pt))
    line((12.9, 1.27), (12.9, 0.65), stroke: (dash: "dotted", paint: softline.darken(30%), thickness: 0.6pt))
  })),
  caption: [Physical RSI L0–L5 五年路线图（本书绘制）。上排为分级刻度（L0/L1 已有实证）；中排为里程碑 M1–M4，依次对应 L2–L5，实线箭头为里程碑之间的依赖。细则见 @tab:milestones。],
) <fig:roadmap>

#figure(
  table(
    columns: (1.15fr, 1.85fr, 1.85fr, 2.05fr),
    [里程碑], [关键障碍], [所需能力], [可检验预测],
    [M1：L2 整环闭合\ （2026–2028）],
    [真机验证吞吐低；机器人域缺可验证奖励；改进真实性协议未被采用],
    [证据门控 harness 与技能契约；想象训练数据管线；配对差分评测纪律],
    [≥1 个公开系统在单一任务族连续 ≥10 轮自主改进且改进程序被显式修改，配对置信区间不含零，账本可审计],
    [M2：L3 跨域迁移\ （2027–2029）],
    [跨任务"改进"缺定义；技能可携带性无判据；sim-real 差距被放大],
    [harness 语义层技能契约；跨域世界模型验证；本体变更保值测试],
    [完成 RSI 的系统在*未参与改进*的留出任务族上取得统计显著零样本增益，可归因于迁移资产而非底座规模],
    [M3：L4 递增收益\ （2028–2030）],
    [元规则稳定性无理论；评估器共进化污染证据；长时程受控运行无先例],
    [元编辑授权窗口与错误预算；差分评估器组合；谱系级纵向评测设施],
    [相同起点、匹配预算下，后期改进器的真实改进速率显著高于早期改进器],
    [M4：L5 判据与证据标准\ （2029–2031）],
    [收益递增需跨度量族长时程成立；独立复现与预注册制度缺位],
    [RSIGym 级专用环境成标配；声明索引报告标准被采纳；第三方复现联盟],
    [社区采纳 L5 预注册检验协议；首个*受争议*的 L5 声明触发独立复现],
  ),
  caption: [五年路线图里程碑三栏细则（本书提出）。M1–M4 依次对应 L2–L5；"可检验预测"刻意写成可证伪形式，验证应满足第 9 章协议与"审计递归而非产物"的标准 @chen2026auditing。],
) <tab:milestones>

三点方法论说明：*里程碑是依赖链*——M2 依赖 M1 的真实性协议、M3 依赖 M2 的迁移判据、M4 依赖 M3 的过程级证据；*时间窗是概率陈述*——M1 存活概率高，M3/M4 依赖增长边界裁决；*首要交付物是标准而非系统*——L5 判据让"伪 RSI"声明可被拒斥 @duan2026lastai @chen2026auditing。

== 结语：Embodied RSI 作为研究纲领的价值与边界

本书始于一个观察，终于一个判断：Embodied RSI 在 2026 年 10 月已越过"口号"与"纲领"的分界线。判据是纲领三要素齐备——*硬核*：$(H, Theta, Phi, E)$ 四元组与 L0–L5 判据给出可证伪的核心主张 @zhou2026physicalrsi；*保护带*：harness 工程、世界模型、agentic RL 三条外援战线成熟汇合 @harnessengineering2026 @wmrsurvey2026 @agentrl2025；*启发法*：本章的开放问题与里程碑构成正面启发，第 16 章与第 9 章构成反面启发。纲领命名已被社区采纳 @qin2026agenticrobots @song2026embodiedrsi @hierarchicalsi2026——本书恰好定义而非追述这个纲领。

价值的一面：即使永远不产出 L5 系统，纲领也已产生方法论红利——它把"自我改进"从营销词汇变成需要配对比较、预算受控、谱系可审计的技术声明 @chen2026auditing，把安全讨论从"模型会不会出错"推进到"改进回路可不可信" @gong2026evolutionarysafety；物理世界在此不是负担而是资产：唯一不被模型收买的验证器与不可伪造的信息源。边界的一面必须同样坦率：No Free Lunch 定理宣判"通用自我改进"必须相对化到任务分布 @wolpert1997nfl；sharpening 界宣判无外部信息注入的闭环注定数轮内触顶 @huang2024sharpening @song2025mindthegap；六十年的智能爆炸假说至今没有一条被测量的增长曲线 @good1965speculations @yudkowsky2013microeconomics。本书的立场【本书推断】：Embodied RSI 的前景*有界、饱和式、但在工程上极其可观*——物理世界源源不断地注入真值与失败，恰是饱和天花板下最可靠的"外部信息泵"。递归自我改进不再是奇点叙事的专利，而是一组可在实验室逐步攻克的开放问题——从闭合第一个 L2 整环开始。

#keybox(title: [本章要点])[
+ 开放问题地图四象限：理论缺递归性度量与增长曲线证据；系统缺元规则终止条件与评估器验证；具身卡在差距、吞吐与不可逆；安全治理剩根除、边界与群体规则三问。
+ 五年路线图 M1（L2 整环闭合）→ M2（L3 跨域迁移）→ M3（L4 递增收益）→ M4（L5 证据标准），各带可证伪预测（@fig:roadmap、@tab:milestones）；无系统达到 L5，默认增长形态为饱和式。
]
