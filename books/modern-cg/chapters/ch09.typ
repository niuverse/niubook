#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 光线几何求交、空间加速结构（BVH）与渲染方程

前两模块构建的光栅化管线以「图元向屏幕投影」为核心，通过局部着色模型与深度缓冲实现高吞吐实时绘制；然而，光栅化在数学上将每个图元的着色过程解耦为局部独立计算，难以自然统一阴影、镜面反射、透明折射与多跳间接照明等全局光传输效应。1980 年，Whitted 提出递归光线追踪（Recursive Ray Tracing）@whitted1980improved，沿着视线反向发射光线并在交点处递归派生反射、折射与阴影光线；1986 年，Kajiya 进一步从辐射度量学守恒定律推导出渲染方程（Rendering Equation）@kajiya1986rendering，将全部照片级真实感渲染问题统一为高维积分方程求解。

本章作为模块四「基于物理的光线追踪与全局光照」的理论基石，首先推导参数化光线与平面、球体及三角形的解析求交算法（@sec:ch09-intersection）；随后阐述轴对齐包围盒（AABB）Slab 算法与基于表面积启发式（SAH）的层次包围盒（BVH）构建机制（@sec:ch09-bvh）；接着严格定义双向反射分布函数（BRDF）及其三大物理公理（@sec:ch09-brdf-props）；进而完整推导立体角形式与面积形式的渲染方程及其 Neumann 级数算子展开（@sec:ch09-rendering-eq）；最后探讨专用光线追踪硬件（RT Core）与实时神经辐射缓存的前沿演进（@sec:ch09-frontier）。

== 光线数学表达与基础图元求交（Möller-Trumbore 算法） <sec:ch09-intersection>

在几何光学近似下，忽略光的衍射与相干效应，光能沿直线在均匀介质中传播。我们将三维空间中的一条有向半直线（Ray）参数化定义为：
$ bold(r)(t) = bold(o) + t bold(d), quad t in [t_"min", t_"max"], $ <eq:ch09-ray>
其中 $bold(o) in RR^3$ 为光线起点（Origin），$bold(d) in RR^3$ 为光线传播方向向量（通常归一化为单位向量 $norm(bold(d)) = 1$），标量参数 $t$ 表示沿方向的传播距离。工程实现中，为消除浮点数自相交伪影（Shadow Acne），通常取 $t_"min" = epsilon approx 10^(-4)$，并在发现更近有效交点时动态收缩上限 $t_"max"$。在 Whitted 风格光线追踪 @whitted1980improved 中，主光线从相机中心穿过像素平面进入场景，命中最近表面点 $bold(x) = bold(r)(t^*)$ 后，分别向光源发射阴影光线（Shadow Ray）测试可见性，并沿镜面反射与 Snell 折射方向递归发射次级光线。

=== 隐式表面求交：平面与球体

对于由法线 $bold(n) in SS^2$ 与锚点 $bold(p)_0 in RR^3$ 定义的无限平面，其隐式方程为 $(bold(x) - bold(p)_0) dot bold(n) = 0$。将光线方程 @eq:ch09-ray 代入可得 $(bold(o) + t bold(d) - bold(p)_0) dot bold(n) = 0$，当分母 $bold(d) dot bold(n) != 0$（光线不平行于平面）时，唯一交点参数为：
$ t = ((bold(p)_0 - bold(o)) dot bold(n)) / (bold(d) dot bold(n)). $ <eq:ch09-ray-plane>
对于球心在 $bold(c) in RR^3$、半径为 $R$ 的球体，其隐式方程为 $norm(bold(x) - bold(c))^2 - R^2 = 0$。令相对起点向量 $bold(f) = bold(o) - bold(c)$，代入 @eq:ch09-ray 得到关于 $t$ 的一元二次方程 $(bold(d) dot bold(d)) t^2 + 2 (bold(f) dot bold(d)) t + (bold(f) dot bold(f) - R^2) = 0$。记半判别式 $Delta_4 = (bold(f) dot bold(d))^2 - (bold(d) dot bold(d))(bold(f) dot bold(f) - R^2)$：若 $Delta_4 < 0$ 则光线与球体相离；若 $Delta_4 >= 0$，则较小正根 $t_1 = (-(bold(f) dot bold(d)) - sqrt(Delta_4)) / (bold(d) dot bold(d))$ 给出光线进入球体的首个交点。

=== Möller-Trumbore 光线—三角形求交算法

现代三维场景以三角形网格为主体。传统两步法先按 @eq:ch09-ray-plane 与三角形所在平面求交，再在平面内做重心坐标测试；Möller 与 Trumbore @moller1997fast 提出直接将光线参数与三角形重心坐标联立求解的无预存储算法，消除了平面方程存储开销并显著减少浮点运算次数。

设三角形三个顶点为 $bold(v)_0, bold(v)_1, bold(v)_2 in RR^3$，三角形内任一点可由重心坐标 $(1 - u - v, u, v)$ 参数化为 $bold(x)(u, v) = (1 - u - v) bold(v)_0 + u bold(v)_1 + v bold(v)_2$，其中内部判定充要条件为 $u >= 0$、$v >= 0$ 且 $u + v <= 1$。令光线方程 $bold(o) + t bold(d) = bold(x)(u, v)$，定义两条边向量 $bold(e)_1 = bold(v)_1 - bold(v)_0$、$bold(e)_2 = bold(v)_2 - bold(v)_0$ 以及起点偏移向量 $bold(s) = bold(o) - bold(v)_0$，移项后得到三元一次线性方程组：
$ mat(-bold(d), bold(e)_1, bold(e)_2) vec(t, u, v) = bold(s). $ <eq:ch09-mt-system>

根据线性代数中的 Cramer 法则与标量三重积轮换恒等式 $det(bold(a), bold(b), bold(c)) = (bold(a) times bold(b)) dot bold(c) = (bold(c) times bold(a)) dot bold(b)$，引入两个复用叉积中间向量：
$ bold(p) = bold(d) times bold(e)_2, quad bold(q) = bold(s) times bold(e)_1. $ <eq:ch09-mt-pq>
于是系数矩阵行列式可写为 $D = det(-bold(d), bold(e)_1, bold(e)_2) = (bold(d) times bold(e)_2) dot bold(e)_1 = bold(p) dot bold(e)_1$。利用三重积性质分别计算三个分子的行列式：$det(bold(s), bold(e)_1, bold(e)_2) = (bold(s) times bold(e)_1) dot bold(e)_2 = bold(q) dot bold(e)_2$，$det(-bold(d), bold(s), bold(e)_2) = (bold(d) times bold(e)_2) dot bold(s) = bold(p) dot bold(s)$，以及 $det(-bold(d), bold(e)_1, bold(s)) = (bold(s) times bold(e)_1) dot bold(d) = bold(q) dot bold(d)$。由此得到 Möller-Trumbore 闭式解 @moller1997fast：
$ vec(t, u, v) = (1) / (bold(p) dot bold(e)_1) vec(bold(q) dot bold(e)_2, bold(p) dot bold(s), bold(q) dot bold(d)). $ <eq:ch09-moller-trumbore>

#remark(title: [早期剔除（Early-Exit）与几何解释])[
从几何上看，@eq:ch09-moller-trumbore 将原始三角形通过仿射变换映射为以原点为顶点、沿坐标轴张开的单位直角三角形，并将光线方向对齐至轴向。实际执行时按四步顺序短路退出：(1) 计算 $D = bold(p) dot bold(e)_1$，若 $|D| < epsilon$（光线平行于三角形平面，或开启背面剔除时 $D < epsilon$）立即返回未命中；(2) 计算 $u = (bold(p) dot bold(s)) / D$，若 $u < 0$ 或 $u > 1$ 退出；(3) 计算叉积 $bold(q)$ 与 $v = (bold(q) dot bold(d)) / D$，若 $v < 0$ 或 $u + v > 1$ 退出；(4) 最后计算 $t = (bold(q) dot bold(e)_2) / D$ 并校验 $t in [t_"min", t_"max"]$。对于绝大部分未命中的光线，算法在计算 $bold(q)$ 之前即提前终止。
]

== 轴对齐包围盒（AABB）Slab 算法与层次包围盒（BVH）构建 <sec:ch09-bvh>

若场景包含 $N$ 个三角形，朴素逐三角形求交的单条光线时间复杂度为 $O(N)$，面对百万面片级场景完全不可实用。空间加速结构通过层次化剔除将平均求交复杂度降至 $O(log N)$。

=== 轴对齐包围盒（AABB）与 Slab 区间求交

轴对齐包围盒（Axis-Aligned Bounding Box, AABB）定义为三个坐标轴上闭区间的笛卡尔积 $B = [x_"min", x_"max"] times [y_"min", y_"max"] times [z_"min", z_"max"]$，仅需存储最小角点 $bold(b)_"min"$ 与最大角点 $bold(b)_"max"$。Kay 与 Kajiya 提出的 Slab 算法将三维 AABB 视为三对轴对齐平行平面（Slab）的交集。对任意坐标轴 $k in {x, y, z}$，光线穿过第 $k$ 对平面的参数区间 $[t_("min", k), t_("max", k)]$ 由下式给出：
$ t_(0, k) = (b_("min", k) - o_k) dot d_k^(-1), quad t_(1, k) = (b_("max", k) - o_k) dot d_k^(-1), \
  t_("min", k) = min(t_(0, k), t_(1, k)), quad t_("max", k) = max(t_(0, k), t_(1, k)). $ <eq:ch09-slab-axis>
预计算方向倒数向量 $bold(d)^(-1) = (1 \/ d_x, 1 \/ d_y, 1 \/ d_z)$ 可用乘法替代除法（配合 IEEE 754 浮点数对正负无穷的处理）。光线与三维 AABB 相交当且仅当三个轴向参数区间的交集非空：
$ t_"enter" = max(t_("min", x), t_("min", y), t_("min", z)), quad t_"exit" = min(t_("max", x), t_("max", y), t_("max", z)), $ <eq:ch09-slab-interval>
有效命中判定条件为 $t_"enter" <= t_"exit"$、$t_"exit" >= t_"min"$ 且 $t_"enter" <= t_"max"$。

=== 空间划分与图元划分及表面积启发式（SAH）

三维加速结构分为两大范式：*空间划分*（Spatial Partitioning，如均匀网格、八叉树与 Kd-Tree）将空间切分为互不重叠的区域，同一图元若跨越分割面则被复制引用到多个子节点；*图元划分*（Object Partitioning，以层次包围盒 BVH 为代表）将图元集合划分为不相交的子集并分别计算紧致 AABB，不同子节点的包围盒允许在空间上重叠，但每个图元仅出现一次，树节点总数严格不超过 $2N - 1$。

构建高质量 BVH 的关键在于选择最优划分方案以最小化期望求交代价。MacDonald 与 Booth @macdonald1990heuristics 基于积分几何提出了表面积启发式（Surface Area Heuristic, SAH）：

#proposition(title: [表面积启发式（SAH）条件击中概率与代价模型 @macdonald1990heuristics])[
设凸体 $B_i$ 完全包含于凸父包围盒 $B_P$ 内（$B_i subset.eq B_P$）。对于空间中服从均匀各向同性分布的随机直线（即不终止于盒内的无限长光线），在已知直线击中父盒 $B_P$ 的条件下，其同时击中子盒 $B_i$ 的条件概率等于两者表面积之比：
$ PP("hit" B_i divides "hit" B_P) = (S(B_i)) / (S(B_P)), $ <eq:ch09-sah-prob>
其中对于边长为 $Delta bold(b) = (Delta x, Delta y, Delta z)$ 的 AABB，其表面积为 $S(B) = 2 (Delta x Delta y + Delta y Delta z + Delta z Delta x)$。由此，将父节点 $B_P$ 的图元划分为左子集（包围盒 $B_L$，含 $N_L$ 个图元）与右子集（包围盒 $B_R$，含 $N_R$ 个图元）的单步期望遍历代价为：
$ C_"SAH" (B_L, B_R) = C_"trav" + (S(B_L)) / (S(B_P)) N_L C_"isect" + (S(B_R)) / (S(B_P)) N_R C_"isect", $ <eq:ch09-sah-cost>
其中 $C_"trav"$ 为遍历内部节点并执行子盒 Slab 测试的固定代价，$C_"isect"$ 为单个图元的求交代价。
]

根据积分几何中的 Crofton 定理，三维空间中穿透任意凸体 $B$ 的有向直线集合的运动不变测度正比于该凸体的表面积 $S(B)$。由于 $B_i subset.eq B_P$，任何击中 $B_i$ 的无限直线必然击中 $B_P$，故条件概率直接化简为测度之比 $S(B_i) \/ S(B_P)$。在实际构建中，为避免对每个轴排序做 $O(N log N)$ 全量切分，工业界广泛采用分桶 SAH（Binned SAH）：沿最长轴将图元质心均匀投射到 $M$（常取 $M = 12$ 或 $16$）个桶中，通过一次前缀扫描与一次后缀扫描在线性时间 $O(N + M)$ 内评估全部 $M - 1$ 个候选切分面，如 @fig:ch09-bvh-sah 所示。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 左侧：几何空间 AABB 与 SAH 分桶切分
    rect((0.2, 0.4), (6.6, 5.2), fill: softbg, stroke: 0.9pt + accent, radius: 0.08)
    content((3.4, 4.9), text(size: 8pt, weight: "bold", fill: accent.darken(20%))[几何空间：父盒 $B_P$ 与 SAH 候选切分面])
    // 桶分割虚线
    for x in (1.5, 2.8, 4.1, 5.4) {
      line((x, 0.6), (x, 4.45), stroke: (dash: "dotted", paint: gray.darken(10%), thickness: 0.6pt))
    }
    // 最优切分线
    line((4.1, 0.55), (4.1, 4.55), stroke: (dash: "dashed", paint: warn, thickness: 1.1pt))
    content((4.1, 0.85), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7pt, fill: warn)[最优切分 $C_"SAH"^"*"$])
    // 左子盒 B_L
    rect((0.55, 1.3), (3.85, 4.3), fill: bluebg, stroke: 0.9pt + accent)
    content((2.2, 4.0), text(size: 7.5pt, weight: "bold", fill: accent.darken(20%))[左子盒 $B_L$ ($N_L = 3$)])
    line((0.8, 1.6), (1.7, 1.8), (1.2, 2.6), close: true, fill: accent.lighten(60%), stroke: 0.7pt + accent)
    line((1.9, 2.2), (2.9, 1.9), (2.4, 3.1), close: true, fill: accent.lighten(60%), stroke: 0.7pt + accent)
    line((2.6, 2.9), (3.6, 2.7), (3.2, 3.7), close: true, fill: accent.lighten(60%), stroke: 0.7pt + accent)
    // 右子盒 B_R
    rect((4.35, 1.2), (6.3, 3.8), fill: rgb("#f2efe6"), stroke: 0.9pt + accent2)
    content((5.32, 3.5), text(size: 7.5pt, weight: "bold", fill: accent2.darken(20%))[右子盒 $B_R$ ($N_R = 2$)])
    line((4.6, 1.5), (5.6, 1.6), (5.1, 2.5), close: true, fill: accent2.lighten(60%), stroke: 0.7pt + accent2)
    line((5.2, 2.2), (6.1, 2.4), (5.6, 3.2), close: true, fill: accent2.lighten(60%), stroke: 0.7pt + accent2)
    // 光线穿过
    line((0.25, 1.9), (6.5, 3.3), mark: (end: ">"), stroke: 1.0pt + warn)
    content((1.35, 1.42), text(size: 7.2pt, fill: warn)[光线 $bold(r)(t)$])

    // 右侧：BVH 层次树与按距离启发遍历栈
    rect((7.2, 3.9), (10.2, 4.95), fill: softbg, stroke: 0.9pt + accent, radius: 0.12)
    content((8.7, 4.6), text(size: 8pt, weight: "bold")[根节点 $B_P$])
    content((8.7, 4.18), text(size: 7.2pt)[Slab 命中：$t_"enter" <= t_"exit"$])

    rect((6.95, 2.0), (8.55, 3.05), fill: bluebg, stroke: 0.9pt + accent, radius: 0.12)
    content((7.75, 2.72), text(size: 7.5pt, weight: "bold")[内部节点 $B_L$])
    content((7.75, 2.28), text(size: 7pt)[先访问（$t_"enter"^L$ 更近）])

    rect((8.95, 2.0), (10.55, 3.05), fill: rgb("#f2efe6"), stroke: 0.9pt + accent2, radius: 0.12)
    content((9.75, 2.72), text(size: 7.5pt, weight: "bold")[叶子节点 $B_R$])
    content((9.75, 2.28), text(size: 7pt)[压入遍历栈])

    rect((6.85, 0.45), (7.68, 1.25), fill: softbg, stroke: 0.8pt + gray.darken(20%), radius: 0.08)
    content((7.26, 0.85), text(size: 7pt)[叶 $L_1$])
    rect((7.85, 0.45), (8.68, 1.25), fill: softbg, stroke: 0.8pt + gray.darken(20%), radius: 0.08)
    content((8.26, 0.85), text(size: 7pt)[叶 $L_2$])

    line((8.3, 3.9), (7.75, 3.05), mark: (end: ">"), stroke: 0.85pt + accent)
    line((9.1, 3.9), (9.75, 3.05), mark: (end: ">"), stroke: 0.85pt + accent2)
    line((7.55, 2.0), (7.26, 1.25), mark: (end: ">"), stroke: 0.8pt + gray.darken(20%))
    line((7.95, 2.0), (8.26, 1.25), mark: (end: ">"), stroke: 0.8pt + gray.darken(20%))

    // 最右侧：显式遍历栈说明框
    rect((10.95, 0.6), (14.2, 4.95), fill: softbg, stroke: 0.9pt + accent2, radius: 0.12)
    content((12.57, 4.55), text(size: 8pt, weight: "bold", fill: accent2.darken(20%))[单光线遍历循环])
    content((12.57, 3.85), text(size: 7.2pt)[1. 弹出栈顶节点测试 Slab])
    content((12.57, 3.2), text(size: 7.2pt)[2. 若 $t_"enter" > t_"max"$ 直接剪枝])
    content((12.57, 2.55), text(size: 7.2pt)[3. 远子节点压栈，近子先遍历])
    content((12.57, 1.9), text(size: 7.2pt)[4. 命中图元收缩 $t_"max" arrow.l t^*$])
    content((12.57, 1.15), text(size: 7.2pt, fill: accent.darken(10%))[复杂度：$O(N) -> O(log N)$])
  })),
  caption: [SAH 分桶切分构建与 BVH 遍历机制示意图。左图展示父包围盒 $B_P$ 沿最长轴分桶评估切分面，将图元划分为互不重叠的子集 $B_L$ 与 $B_R$；右图展示按 $t_"enter"$ 远近顺序压栈并在命中后动态收缩 $t_"max"$ 以剪枝远端分支的遍历流程。],
) <fig:ch09-bvh-sah>

@tab:ch09-accel-structures 系统对比了四类经典空间加速结构的构建复杂度、查询性能与工程特性。SAH-BVH 凭借线性内存占用、无图元复制、卓越的抗非均匀分布能力以及对局部变形重拟合（Refit）的支持，成为当代离线与硬件实时渲染器的事实标准。

#figure(
  table(
    columns: (2.4cm, 2.1cm, 2.5cm, 2.6cm, 2.4cm, 2.2cm),
    align: (left, center, center, left, left, left),
    [*加速结构*], [*划分范式*], [*构建复杂度*], [*光线查询性能*], [*动态场景支持*], [*内存与图元引用*],
    [均匀网格 (Grid)], [空间划分], [$O(N + G^3)$], [茶壶入体育馆退化严重], [可快速重建], [3D 数组，$O(G^3)$ 高开销],
    [八叉树 (Octree)], [空间划分], [$O(N D_"max")$], [中等，对称切分不够紧致], [局部节点更新], [跨越分割面图元被复制],
    [Kd-Tree (SAH)], [空间划分], [$O(N log N)$], [极高，严格从前向后遍历], [拓扑固定，需重建], [图元跨面复制，内存偏大],
    [SAH-BVH], [图元划分], [$O(N log N)$], [极高，支持 $4\/8$ 宽节点 SIMD], [支持 $O(N)$ Refit], [最多 $2N-1$ 节点，零复制],
  ),
  caption: [四类主流光线追踪空间加速结构的复杂度与工程特性对比],
) <tab:ch09-accel-structures>

== 双向反射分布函数（BRDF）物理性质：非负性、互易性与能量守恒 <sec:ch09-brdf-props>

当光线与加速结构求交定位到表面点 $bold(x) in cal(M)$（表面单位外法线为 $bold(n) in SS^2$）后，我们需要精确刻画入射光能如何散射到各个出射方向。遵循全书约定，入射方向 $omega_i in Omega^+$ 与出射方向 $omega_o in Omega^+$ 均定义为*背离表面指向外侧上半球* $Omega^+ = {omega in SS^2 : bold(n) dot omega >= 0}$ 的单位向量，天顶角余弦记为 $cos theta_i = bold(n) dot omega_i$、$cos theta_o = bold(n) dot omega_o$。

来自方向 $omega_i$、立体角微元 $dif omega_i$ 的入射辐射亮度 $L_i (bold(x), omega_i)$ 在表面微元 $dif A$ 上产生的微分辐照度（Differential Irradiance）为 $dif E_i (bold(x), omega_i) = L_i (bold(x), omega_i) cos theta_i dif omega_i$（其中 $cos theta_i$ 源于 Lambert 投影面积缩减定律 $dif A^perp = cos theta_i dif A$）。

#definition(title: [双向反射分布函数（BRDF）])[
不透明且无次表面散射的材质表面在点 $bold(x)$ 处的双向反射分布函数 $f_r (bold(x), omega_i, omega_o)$，定义为沿出射方向 $omega_o$ 散射的微分出射辐射亮度 $dif L_o (bold(x), omega_o)$ 与来自方向 $omega_i$ 的微分入射辐照度 $dif E_i (bold(x), omega_i)$ 之比：
$ f_r (bold(x), omega_i, omega_o) := (dif L_o (bold(x), omega_o)) / (dif E_i (bold(x), omega_i)) = (dif L_o (bold(x), omega_o)) / (L_i (bold(x), omega_i) cos theta_i dif omega_i), $ <eq:ch09-brdf-def>
其物理量纲为立体角的倒数 $["sr"^(-1)]$。
]

任何物理可实现的（Physically Plausible）BRDF 必须满足以下三条基本物理公理：
1. *非负性（Positivity）*：被动反射不会产生负辐射亮度，故对一切方向对恒有 $f_r (bold(x), omega_i, omega_o) >= 0$。
2. *Helmholtz 互易性（Reciprocity）*：由电磁波微观可逆性原理，交换入射方向与出射方向不改变散射比例：
   $ f_r (bold(x), omega_i, omega_o) = f_r (bold(x), omega_o, omega_i). $ <eq:ch09-reciprocity>
   这一性质保证了从光源正向追踪光子（Light Tracing）与从相机反向追踪视线（Path Tracing）在数学上严格等价。
3. *能量守恒（Energy Conservation）*：非自发光表面向整个上半球反射的总出射辐射通量不得超过入射辐射通量。固定入射方向 $omega_i$，定义方向—半球反射率（Directional-Hemispherical Reflectance）$rho_"hd" (omega_i)$ 为全半球出射辐照度与微分入射辐照度之比；利用互易性 @eq:ch09-reciprocity，能量守恒等价于对任意 $omega_o in Omega^+$ 满足：
   $ rho_"hd" (omega_o) = integral_(Omega^+) f_r (bold(x), omega_i, omega_o) cos theta_i dif omega_i <= 1. $ <eq:ch09-energy-conservation>

#example(title: [理想漫反射（Lambertian BRDF）的归一化常数 $1 \/ pi$])[
理想漫反射表面将入射光能均匀散射到上半球所有方向，其 BRDF 为与方向无关的常数 $f_r (bold(x), omega_i, omega_o) = c$。设材质表面反照率（Albedo，即反射能量占入射能量之比）为 $rho in [0, 1]$，代入 @eq:ch09-energy-conservation 并在球坐标 $(theta_i, phi_i) in [0, pi \/ 2] times [0, 2 pi]$ 下积分（立体角微元 $dif omega_i = sin theta_i dif theta_i dif phi_i$）：
$ rho = integral_0^(2 pi) integral_0^(pi / 2) c cos theta_i sin theta_i dif theta_i dif phi_i = 2 pi c [ (1 / 2) sin^2 theta_i ]_0^(pi / 2) = pi c. $
因此，满足能量守恒的 Lambertian BRDF 必须写为 $f_r = rho \/ pi$（其中 $rho in [0, 1]$），若直接令 $f_r = rho$ 则会导致反射能量凭空放大 $pi$ 倍。
]

== 渲染方程（Rendering Equation）：立体角形式、面积形式与算子展开 <sec:ch09-rendering-eq>

将微分关系 $dif L_o (bold(x), omega_o) = f_r (bold(x), omega_i, omega_o) L_i (bold(x), omega_i) cos theta_i dif omega_i$ 在整个上半球 $Omega^+$ 上对所有入射方向叠加，并计入表面自身的辐射发射项 $L_e (bold(x), omega_o)$，即得到 Kajiya 于 1986 年确立的渲染方程 @kajiya1986rendering：

#theorem(title: [渲染方程的半球立体角形式 @kajiya1986rendering])[
在几何光学稳态平衡与无参与介质（真空）假设下，场景表面点 $bold(x)$ 沿方向 $omega_o$ 的出射辐射亮度 $L_o (bold(x), omega_o)$ 满足第二类 Fredholm 积分方程：
$ L_o (bold(x), omega_o) = L_e (bold(x), omega_o) + integral_(Omega^+) f_r (bold(x), omega_i, omega_o) L_i (bold(x), omega_i) cos theta_i dif omega_i. $ <eq:ch09-rendering-eq-hemi>
在真空直线传播下，光线沿射线无衰减，故点 $bold(x)$ 沿方向 $omega_i$ 接收的入射辐射亮度等于射线命中最近表面点 $bold(y) = "raycast"(bold(x), omega_i)$ 沿反方向 $-omega_i$ 的出射辐射亮度，即 $L_i (bold(x), omega_i) = L_o (bold(y), -omega_i)$。
]

=== 面积积分形式与几何耦合项 $G(bold(x) <-> bold(y))$

在许多采样算法（如第 10 章的面光源直接采样与双向路径追踪 @veach1997robust）中，我们需要将半球立体角域 $Omega^+$ 上的积分转换为场景全体表面流形 $cal(M)$ 上的面积积分。如 @fig:ch09-rendering-eq 所示，设点 $bold(x)$（法线 $bold(n)_x$）与另一表面点 $bold(y) in cal(M)$（法线 $bold(n)_y$）之间的单位连线方向为 $omega_(x -> y) = (bold(y) - bold(x)) \/ norm(bold(y) - bold(x))$，记两端法线夹角余弦分别为 $cos theta_x = max(0, bold(n)_x dot omega_(x -> y))$ 与 $cos theta_y = max(0, bold(n)_y dot (-omega_(x -> y)))$。根据立体角的几何定义，面积微元 $dif A(bold(y))$ 对点 $bold(x)$ 张开的微分立体角雅可比行列式为：
$ dif omega_i = (cos theta_y dif A(bold(y))) / (norm(bold(x) - bold(y))^2). $ <eq:ch09-jacobian>

引入二值可见性指示函数 $V(bold(x) <-> bold(y)) in {0, 1}$（当开线段 $(bold(x), bold(y))$ 与场景几何无交点时取 $1$，被遮挡时取 $0$）以及对称几何耦合项（Geometry Term）：
$ G(bold(x) <-> bold(y)) := (cos theta_x cos theta_y) / (norm(bold(x) - bold(y))^2), $ <eq:ch09-geometry-term>
将 @eq:ch09-jacobian 与 @eq:ch09-geometry-term 代入 @eq:ch09-rendering-eq-hemi，立即得到渲染方程的面积形式 @veach1997robust：
$ L_o (bold(x), omega_o) = L_e (bold(x), omega_o) + integral_(cal(M)) f_r (bold(x), omega_(x -> y), omega_o) L_o (bold(y), -omega_(x -> y)) V(bold(x) <-> bold(y)) G(bold(x) <-> bold(y)) dif A(bold(y)). $ <eq:ch09-rendering-eq-area>

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 左侧：立体角积分与面积积分的微元测度变换
    rect((0.2, 0.3), (7.6, 5.0), fill: softbg, stroke: 0.9pt + accent, radius: 0.1)
    content((3.9, 4.68), text(size: 8pt, weight: "bold", fill: accent.darken(20%))[立体角微元 $dif omega_i$ 与面积微元 $dif A(bold(y))$ 几何换算])
    // 表面 x
    line((0.6, 1.0), (3.4, 1.0), stroke: 1.4pt + ink)
    content((2.0, 0.68), text(size: 7.5pt)[着色点 $bold(x)$ 所在切平面])
    // 半球虚线弧
    arc((3.2, 1.0), start: 0deg, stop: 180deg, radius: 1.2, stroke: (dash: "dashed", paint: accent, thickness: 0.85pt))
    content((1.15, 2.15), text(size: 7.2pt, fill: accent)[单位半球 $Omega^+$])
    // 法线 n_x 与出射方向 omega_o
    line((2.0, 1.0), (2.0, 2.7), mark: (end: ">"), stroke: 0.9pt + accent)
    content((1.7, 2.6), text(size: 7.5pt, fill: accent)[$bold(n)_x$])
    line((2.0, 1.0), (0.85, 2.3), mark: (end: ">"), stroke: 0.9pt + accent2)
    content((0.8, 2.55), text(size: 7.5pt, fill: accent2)[$omega_o$])
    // 连线 x <-> y
    line((2.0, 1.0), (6.1, 3.6), mark: (start: ">", end: ">"), stroke: 1.0pt + warn)
    content((4.1, 2.55), frame: "rect", fill: white, stroke: none, padding: 0.06, text(size: 7.2pt, fill: warn)[$V(bold(x) <-> bold(y)) = 1, quad r = norm(bold(x) - bold(y))$])
    content((2.55, 1.65), text(size: 7.2pt)[$theta_x$])
    content((3.15, 1.4), text(size: 7.2pt, fill: accent)[$dif omega_i$])
    // 表面 y 微元
    line((5.4, 4.15), (6.8, 3.05), stroke: 1.6pt + accent2)
    line((6.1, 3.6), (5.1, 2.4), mark: (end: ">"), stroke: 0.9pt + accent2)
    content((4.85, 2.2), text(size: 7.5pt, fill: accent2)[$bold(n)_y$])
    content((5.55, 3.3), text(size: 7.2pt)[$theta_y$])
    content((6.6, 3.95), text(size: 7.5pt, weight: "bold", fill: accent2.darken(20%))[$dif A(bold(y))$])
    content((4.5, 0.9), text(size: 7.3pt)[$dif omega_i = (cos theta_y dif A(bold(y))) / norm(bold(x) - bold(y))^2$])

    // 右侧：Neumann 级数算子展开物理图景
    rect((8.0, 0.3), (14.2, 5.0), fill: softbg, stroke: 0.9pt + accent2, radius: 0.1)
    content((11.1, 4.68), text(size: 8pt, weight: "bold", fill: accent2.darken(20%))[线性算子展开 $bold(L) = sum_(k=0)^infinity cal(T)^k bold(L)_e$])

    rect((8.35, 3.55), (13.85, 4.25), fill: bluebg, stroke: 0.8pt + accent, radius: 0.08)
    content((11.1, 3.9), text(size: 7.4pt)[$k=0$: $bold(L)_e$（光源直接可见自发光）])

    rect((8.35, 2.55), (13.85, 3.25), fill: bluebg, stroke: 0.8pt + accent, radius: 0.08)
    content((11.1, 2.9), text(size: 7.4pt)[$k=1$: $cal(T) bold(L)_e$（单次弹射：局部直接光照与硬/软阴影）])

    rect((8.35, 1.55), (13.85, 2.25), fill: rgb("#f2efe6"), stroke: 0.8pt + accent2, radius: 0.08)
    content((11.1, 1.9), text(size: 7.4pt)[$k=2$: $cal(T)^2 bold(L)_e$（二次弹射：色彩溢色与焦散）])

    rect((8.35, 0.55), (13.85, 1.25), fill: rgb("#f2efe6"), stroke: 0.8pt + accent2, radius: 0.08)
    content((11.1, 0.9), text(size: 7.4pt)[$k >= 3$: $sum_(k=3)^infinity cal(T)^k bold(L)_e$（多次弹射高阶全局光照）])

    line((11.1, 3.55), (11.1, 3.25), mark: (end: ">"), stroke: 0.8pt + accent)
    line((11.1, 2.55), (11.1, 2.25), mark: (end: ">"), stroke: 0.8pt + accent2)
    line((11.1, 1.55), (11.1, 1.25), mark: (end: ">"), stroke: 0.8pt + accent2)
  })),
  caption: [渲染方程的积分域几何变换（左）与 Neumann 级数多次弹射展开（右）。左图展示立体角微元 $dif omega_i$ 通过距离平方反比与双余弦几何项 $G(bold(x) <-> bold(y))$ 映射到表面微元 $dif A(bold(y))$；右图展示传输算子 $cal(T)$ 迭代作用对应的高阶全局光照层次。],
) <fig:ch09-rendering-eq>

=== 线性积分算子与 Neumann 级数展开

将辐射亮度函数 $bold(L)(bold(x), omega_o)$ 视为函数赋范空间中的元素，定义线性光传输积分算子（Light Transport Operator）$cal(T)$ 为：
$ (cal(T) bold(L))(bold(x), omega_o) := integral_(Omega^+) f_r (bold(x), omega_i, omega_o) bold(L)("raycast"(bold(x), omega_i), -omega_i) cos theta_i dif omega_i. $ <eq:ch09-transport-op>
于是渲染方程可简写为算子不动点方程 $bold(L) = bold(L)_e + cal(T) bold(L)$，即 $(cal(I) - cal(T)) bold(L) = bold(L)_e$（其中 $cal(I)$ 为恒等算子）。在真实物理场景中，表面吸收使得式 @eq:ch09-energy-conservation 严格小于 $1$，算子范数满足 $norm(cal(T)) < 1$（压缩映射）。由泛函分析中的 Banach 不动点定理，逆算子 $(cal(I) - cal(T))^(-1)$ 存在且可展开为收敛的 Neumann 级数 @kajiya1986rendering @veach1997robust：
$ bold(L) = (cal(I) - cal(T))^(-1) bold(L)_e = sum_(k=0)^infinity cal(T)^k bold(L)_e = bold(L)_e + cal(T) bold(L)_e + cal(T)^2 bold(L)_e + dots.c . $ <eq:ch09-neumann>
如 @fig:ch09-rendering-eq 右侧所示，Neumann 级数的每一项具有清晰的物理对应：$k = 0$ 项 $bold(L)_e$ 为直接落入相机的光源辐射；$k = 1$ 项 $cal(T) bold(L)_e$ 为光线从光源出发经一次表面反射进入相机的直接光照（传统光栅化管线仅近似前两项）；$k >= 2$ 各阶项则对应漫反射色彩溢色（Color Bleeding）、软间接阴影与焦散（Caustics）等完整全局光照。

下面给出批量向量化的 Möller-Trumbore 光线—三角形求交与 AABB Slab 区间测试的参考实现：

```python
import numpy as np

def intersect_triangles_mt(ray_o: np.ndarray, ray_d: np.ndarray,
                           v0: np.ndarray, v1: np.ndarray, v2: np.ndarray,
                           t_min: float = 1e-4, t_max: float = 1e30, eps: float = 1e-8):
    """向量化 Möller-Trumbore 算法：单条光线 (3,) 对 N 个三角形 (N, 3) 求交"""
    e1, e2 = v1 - v0, v2 - v0                          # (N, 3)
    p = np.cross(ray_d[None, :], e2)                   # p = d x e2, (N, 3)
    det = np.einsum("ij,ij->i", p, e1)                 # D = p . e1, (N,)
    valid = np.abs(det) > eps
    inv_det = np.where(valid, 1.0 / np.where(valid, det, 1.0), 0.0)

    s = ray_o[None, :] - v0                            # s = o - v0, (N, 3)
    u = np.einsum("ij,ij->i", p, s) * inv_det
    valid &= (u >= 0.0) & (u <= 1.0)

    q = np.cross(s, e1)                                # q = s x e1, (N, 3)
    v = np.einsum("j,ij->i", ray_d, q) * inv_det
    valid &= (v >= 0.0) & (u + v <= 1.0)

    t = np.einsum("ij,ij->i", q, e2) * inv_det
    valid &= (t >= t_min) & (t <= t_max)
    return valid, t, u, v

def intersect_aabb_slab(ray_o: np.ndarray, inv_d: np.ndarray,
                        b_min: np.ndarray, b_max: np.ndarray,
                        t_min: float = 1e-4, t_max: float = 1e30):
    """向量化 AABB Slab 测试：单条光线对 M 个包围盒 (M, 3) 返回命中掩码与 t_enter"""
    t0 = (b_min - ray_o[None, :]) * inv_d[None, :]
    t1 = (b_max - ray_o[None, :]) * inv_d[None, :]
    t_enter = np.maximum(np.max(np.minimum(t0, t1), axis=-1), t_min)
    t_exit = np.minimum(np.min(np.maximum(t0, t1), axis=-1), t_max)
    return t_enter <= t_exit, t_enter
```

== 现代演进：硬件光线追踪（RT Core）与实时神经辐射缓存 <sec:ch09-frontier>

过去十年间，光线追踪完成了从电影级离线渲染（数小时每帧）向 60 FPS 实时渲染的跨越，其核心驱动力来自专用硬件加速与神经辐射场缓存的协同设计：

1. *专用光线追踪硬件（RT Core）与宽 BVH 遍历*：【已有成果】自 NVIDIA Turing 架构、AMD RDNA 2 及 Apple M3/M4 GPU 起，现代图形处理器在着色器核心旁集成了固定功能的硬件光线追踪单元（RT Core）。硬件将单指令多数据流（SIMD）中极易产生分支发散的*宽 BVH 节点（BVH4 / BVH8）压缩解包、AABB Slab 区间求交、显式短栈管理以及 Möller-Trumbore 水密三角形求交*全部卸载到专用数字逻辑电路中，使单 GPU 每秒可完成百亿次光线求交测试。
2. *线性 BVH（LBVH）与并行分层构建*：【已有成果】针对动态网格与骨骼蒙皮场景，GPU 利用三维空间填充 Morton 码（Z-order 曲线）将三维图元质心映射为一维有序整数，在数毫秒内并行构建 LBVH 或分层线性 BVH（HLBVH），并与顶层实例加速结构（TLAS）/底层几何加速结构（BLAS）双层架构结合，支撑大规模动态开放世界实时更新。
3. *实时神经辐射缓存（Neural Radiance Caching, NRC）*：【已有成果】在实时帧率预算下，每个像素仅能负担 1–2 条极短路径，无法独立收敛高阶 Neumann 级数项 $sum_(k >= 2) cal(T)^k bold(L)_e$。Müller 等人 @muller2021nrc 提出实时神经辐射缓存（NRC）：从屏幕像素仅追踪含 1–2 次弹射的短路径，在路径末端查询一个采用多分辨率哈希编码与全融合多层感知机（Fully-Fused MLP）构建的在场辐射亮度缓存 $hat(L)_theta (bold(x), omega)$，直接截断无穷积分级数；同时在每帧利用少量延长路径采用自举时序监督（Self-Training）在不到 1 ms 内在线更新网络权重 $theta$。

【本书推断】这种「前 1–2 跳精确几何光线追踪（保证高频直接光照与接触阴影锐利度）+ 远端神经缓存截断（保证高阶漫反射/光泽全局光照低方差）」的混合架构，实质上是在 Neumann 级数算子展开 @eq:ch09-neumann 的低阶项与高阶余项之间引入了可学习的变分边界条件，已成为现代实时路径追踪引擎的标准范式。

#keybox(title: [本章要点])[
1. *Möller-Trumbore 求交*：通过 Cramer 法则与标量三重积将光线参数与重心坐标联立求解，复用叉积 $bold(p) = bold(d) times bold(e)_2$ 与 $bold(q) = bold(s) times bold(e)_1$ 实现高效早期剔除。
2. *SAH-BVH 加速结构*：基于 Crofton 定理，子包围盒的条件击中概率正比于表面积之比 $S(B_i) \/ S(B_P)$；分桶 SAH 构建配合按 $t_"enter"$ 排序的栈遍历将求交复杂度从 $O(N)$ 降至 $O(log N)$。
3. *BRDF 三大物理公理*：非负性 $f_r >= 0$、Helmholtz 互易性 $f_r (omega_i, omega_o) = f_r (omega_o, omega_i)$ 与半球能量守恒 $integral_(Omega^+) f_r cos theta_i dif omega_i <= 1$（由此导出 Lambertian BRDF 的 $1 \/ pi$ 因子）。
4. *渲染方程与算子展开*：立体角形式与面积形式通过雅可比因子 $dif omega_i = (cos theta_y \/ norm(bold(x) - bold(y))^2) dif A(bold(y))$ 等价转换；Neumann 级数 $bold(L) = sum_(k=0)^infinity cal(T)^k bold(L)_e$ 揭示了第 $k$ 次光线弹射的物理层级。
]
