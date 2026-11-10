#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 显式与隐式几何：参数曲线、曲面与有向距离场

前两模块完成了三维场景从局部坐标到屏幕像素的投影变换，并建立了色彩与感知空间的度量基础。然而，无论光栅化管线还是光线追踪器，其输入首先必须是三维几何体的数学描述。计算机图形学中的几何表示天然分裂为两大对偶范式：*显式表示（Explicit Representation）*直接给出表面点集的参数映射或离散采样，而*隐式表示（Implicit Representation）*将几何表面定义为三维空间标量场的零等值面。这种对偶性不仅贯穿了经典的 CAD 参数样条与构造实体几何（CSG），也在当代可微渲染与神经隐式场中再次交汇。

本章首先建立显式与隐式几何的分类谱系与运算复杂度对比（@sec:ch07-taxonomy），随后完整推导 Bézier 曲线、de Casteljau 递归插值、Bernstein 基函数性质及 B 样条/NURBS 扩展（@sec:ch07-bezier），进而将参数曲线提升为张量积参数曲面并引入第一、第二基本形式与曲率度量（@sec:ch07-surfaces）；在此基础上转向隐式阵营，严格定义有向距离场（SDF）、布尔运算与球体追踪算法（@sec:ch07-sdf），最后剖析等值面网格化方法与现代神经隐式表面演进（@sec:ch07-frontier）。

== 几何表示分类谱系：显式表面与隐式场的对偶性 <sec:ch07-taxonomy>

从泛函映射的视角看，三维空间 $RR^3$ 中二维流形表面 $cal(S)$ 的显式表示与隐式表示恰好互为逆向算子：

- *显式几何（参数化与离散流形）*：通过从二维参数域 $Omega subset RR^2$ 到三维欧氏空间的连续映射 $bold(S): Omega -> RR^3, (u, v) mapsto bold(S)(u, v)$（或分段线性的多边形网格、离散点云）直接枚举表面点。显式表示的根本优势在于*表面采样与生成极易*：遍历参数 $(u, v) in Omega$ 即可在 $O(1)$ 时间内生成表面点并送入光栅化管线；但其对偶代价是*内外判定与空间归属测试极难*——给定任意空间点 $bold(x) in RR^3$，判断 $bold(x)$ 是否落在曲面上或闭合曲面内部，需要求解非线性逆问题或发射射线统计交点奇偶性（Jordan 曲线定理）。
- *隐式几何（水平集与距离场）*：不直接给出表面点的坐标，而是定义标量势函数 $f: RR^3 -> RR$，将表面定义为零等值面（Zero-Level Set）$cal(S) = { bold(x) in RR^3 | f(bold(x)) = 0 }$，约定内部区域满足 $f(bold(x)) < 0$、外部区域满足 $f(bold(x)) > 0$。隐式表示使*内外测试与布尔合成退化为 $O(1)$ 的函数求值*，且天然允许拓扑结构在形变中自由分裂或融合（无须维护网格连接关系）；反之，若要在隐式表面上均匀采样点集或直接交由硬件光栅化，则必须付出一维光线求根或三维网格提取的代价。

#figure(
  table(
    columns: (2.4cm, 1.8cm, 2.8cm, 2.8cm, 2.6cm, 2.4cm),
    align: (left, center, left, left, left, left),
    [表示范式], [类别], [拓扑灵活性], [内存与存储特征], [光线求交方式], [CSG 布尔与内外测试],
    [多边形网格 \ （Triangle Mesh）], [显式], [受限于连接关系；拓扑改变需重连半边], [$O(V + F)$ 顶点与索引表；随精度线性增长], [BVH 加速结构 + Möller-Trumbore 精确求交], [困难；需复杂网格裁剪与自交修复],
    [参数样条曲面 \ （NURBS）], [显式], [单片拓扑同胚于矩形域；复杂拓扑需拼接裁剪], [极紧凑；仅需存储控制网格与节点向量], [数值牛顿迭代或预细分后构建 BVH], [困难；求交曲线即裁剪 NURBS 难题],
    [有向距离场 \ （解析/神经 SDF）], [隐式], [极高；零等值面可自由分裂、合并与改变亏格], [解析式为 $O(1)$；神经场为固定 MLP 权重], [球体追踪（Sphere Tracing）无偏步进], [$O(1)$ 闭式合成（$min, max$ 及平滑布尔）],
    [体素网格 \ （Voxel / VDB）], [隐式/体积], [极高；规则网格天然支持任意拓扑演化], [稠密网格为 $O(N^3)$；稀疏八叉树/VDB 为 $O(N^2)$], [3D DDA 网格遍历或三线性插值求根], [$O(1)$ 逐体素布尔或形态学运算],
    [点云与高斯集 \ （Point / 3DGS）], [显式离散], [极高；无显式连接约束，支持任意几何形态], [$O(N)$ 粒子属性（位置、法线或协方差）], [椭球求交或屏幕空间 EWA 溅射排序], [较难；缺乏严格封闭边界与内外定义],
  ),
  caption: [计算机图形学五类主流几何表示范式的对偶属性与计算特征对比。],
) <tab:ch07-geom-taxonomy>

@tab:ch07-geom-taxonomy 总结了五类主流表示在拓扑弹性、存储开销、光线求交与布尔运算上的工程权衡。现代图形管线的核心设计哲学并非二选一，而是*按算子需求在显式与隐式之间桥接*：工业造型用 NURBS 与隐式 CSG 精确建模，经等值面提取或曲面细分转化为三角形网格（第 8 章）送入 GPU 光栅化；而在逆向重建中，神经隐式场先在连续空间恢复拓扑，再导出显式网格用于实时交互。

== Bézier 曲线、de Casteljau 算法、Bernstein 基与 B 样条 <sec:ch07-bezier>

参数曲线是显式几何的基石。给定控制点序列 $bold(b)_0, bold(b)_1, dots, bold(b)_n in RR^3$，我们希望构造一条光滑曲线 $bold(b)(t), t in [0, 1]$，使其逼近控制多边形并具备优良的几何不变性@farin2002curves。

=== de Casteljau 递归几何构造与 Bernstein 显式展开

法国工程师 Paul de Casteljau 于 1959 年提出用纯几何的重复线性插值定义参数曲线。设初值 $bold(b)_i^0 (t) = bold(b)_i$（$i = 0, dots, n$），对参数 $t in [0, 1]$，第 $r$ 层（$r = 1, dots, n$）的中间点由前一层相邻两点按比例 $(1-t) : t$ 线性插值生成：

$ bold(b)_i^r (t) = (1 - t) bold(b)_i^(r-1) (t) + t bold(b)_(i+1)^(r-1) (t), quad r = 1, dots, n, quad i = 0, dots, n - r. $ <eq:ch07-casteljau>

当递归进行到第 $n$ 层时，唯一剩余的点 $bold(b)_0^n (t)$ 即定义为 $n$ 次 *Bézier 曲线*在参数 $t$ 处的点@farin2002curves。将 @eq:ch07-casteljau 的递推关系显式展开，即可得到 Pierre Bézier 独立发表的代数形式：

$ bold(b)(t) = bold(b)_0^n (t) = sum_(i=0)^n bold(b)_i B_i^n (t), quad B_i^n (t) = binom(n, i) t^i (1 - t)^(n - i), quad t in [0, 1], $ <eq:ch07-bernstein>

其中 $B_i^n (t)$ 称为 $n$ 次 *Bernstein 基多项式*。以最常用的三次 Bézier 曲线（$n = 3$）为例，其四个基函数为 $B_0^3 (t) = (1-t)^3$、$B_1^3 (t) = 3 t (1-t)^2$、$B_2^3 (t) = 3 t^2 (1-t)$ 与 $B_3^3 (t) = t^3$。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 左侧：三次 Bézier 曲线与 de Casteljau 几何构造 (t = 0.5)
    // 凸包阴影区域
    line((0.9, 0.9), (2.1, 4.3), (5.7, 4.5), (7.3, 1.1), close: true, fill: softbg, stroke: (dash: "dotted", paint: gray.darken(20%), thickness: 0.7pt))
    content((4.1, 0.55), text(size: 7pt, fill: gray.darken(40%))[凸包 $"Conv"{bold(b)_0, bold(b)_1, bold(b)_2, bold(b)_3}$])

    // 控制多边形 b0 - b1 - b2 - b3
    line((0.9, 0.9), (2.1, 4.3), (5.7, 4.5), (7.3, 1.1), stroke: 0.9pt + gray.darken(30%))

    // 第一层线性插值 b0^1(1.5, 2.6), b1^1(3.9, 4.4), b2^1(6.5, 2.8)
    line((1.5, 2.6), (3.9, 4.4), (6.5, 2.8), stroke: (dash: "dashed", paint: accent, thickness: 0.85pt))

    // 第二层线性插值 b0^2(2.7, 3.5), b1^2(5.2, 3.6)
    line((2.7, 3.5), (5.2, 3.6), stroke: 0.9pt + accent2)

    // 精确采样的三次 Bézier 曲线
    line(
      (0.90, 0.90), (1.33, 1.79), (1.87, 2.50), (2.51, 3.02), (3.21, 3.35),
      (3.95, 3.55), (4.70, 3.49), (5.44, 3.23), (6.14, 2.75), (6.76, 2.06), (7.30, 1.10),
      stroke: 1.4pt + accent
    )

    // 在 b0^3(0.5) = (3.95, 3.55) 处的切向量箭头
    line((3.95, 3.55), (5.75, 3.62), mark: (end: ">"), stroke: 1.0pt + warn)
    content((5.85, 3.92), text(size: 7.5pt, fill: warn, weight: "bold")[$bold(b)'(t)$ 切线])

    // 标注各层级控制点
    circle((0.9, 0.9), radius: 0.08, fill: ink, stroke: none)
    content((0.5, 0.9), text(size: 7.5pt)[$bold(b)_0$])
    circle((2.1, 4.3), radius: 0.08, fill: ink, stroke: none)
    content((1.8, 4.6), text(size: 7.5pt)[$bold(b)_1$])
    circle((5.7, 4.5), radius: 0.08, fill: ink, stroke: none)
    content((5.9, 4.78), text(size: 7.5pt)[$bold(b)_2$])
    circle((7.3, 1.1), radius: 0.08, fill: ink, stroke: none)
    content((7.7, 1.1), text(size: 7.5pt)[$bold(b)_3$])

    circle((1.5, 2.6), radius: 0.07, fill: accent, stroke: none)
    content((1.05, 2.65), text(size: 7.2pt, fill: accent)[$bold(b)_0^1$])
    circle((3.9, 4.4), radius: 0.07, fill: accent, stroke: none)
    content((3.9, 4.72), text(size: 7.2pt, fill: accent)[$bold(b)_1^1$])
    circle((6.5, 2.8), radius: 0.07, fill: accent, stroke: none)
    content((6.95, 2.85), text(size: 7.2pt, fill: accent)[$bold(b)_2^1$])

    circle((2.7, 3.5), radius: 0.07, fill: accent2, stroke: none)
    content((2.35, 3.78), text(size: 7.2pt, fill: accent2)[$bold(b)_0^2$])
    circle((5.2, 3.6), radius: 0.07, fill: accent2, stroke: none)
    content((5.35, 3.25), text(size: 7.2pt, fill: accent2)[$bold(b)_1^2$])

    circle((3.95, 3.55), radius: 0.09, fill: warn, stroke: none)
    content((3.95, 3.12), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.5pt, weight: "bold", fill: warn)[$bold(b)_0^3 (t)$])

    // 右侧：递归代数金字塔与细分不变性说明框
    rect((8.3, 2.8), (14.3, 4.8), fill: bluebg, stroke: 0.8pt + accent, radius: 0.12)
    content((11.3, 4.42), text(size: 8pt, weight: "bold", fill: accent)[de Casteljau 三角形金字塔])
    content((11.3, 3.85), text(size: 7.5pt)[$bold(b)_0^0 , bold(b)_1^0 , bold(b)_2^0 , bold(b)_3^0 ->^(1-t, t) bold(b)_0^1 , bold(b)_1^1 , bold(b)_2^1$])
    content((11.3, 3.25), text(size: 7.5pt)[$->^(1-t, t) bold(b)_0^2 , bold(b)_1^2 ->^(1-t, t) bold(b)_0^3 (t)$])

    rect((8.3, 0.5), (14.3, 2.4), fill: softbg, stroke: 0.8pt + accent2, radius: 0.12)
    content((11.3, 2.02), text(size: 8pt, weight: "bold", fill: accent2)[细分不变性（Subdivision）])
    content((11.3, 1.45), text(size: 7.3pt)[左半控制链：$(bold(b)_0^0, bold(b)_0^1, bold(b)_0^2, bold(b)_0^3)$])
    content((11.3, 0.92), text(size: 7.3pt)[右半控制链：$(bold(b)_0^3, bold(b)_1^2, bold(b)_2^1, bold(b)_3^0)$])
  })),
  caption: [三次 Bézier 曲线在 $t = 0.5$ 处的 de Casteljau 递归几何构造。整条曲线严格约束在控制点凸包内，最后一阶插值线段 $bold(b)_0^2 bold(b)_1^2$ 直接给出曲线在 $bold(b)_0^3 (t)$ 处的切线方向，且金字塔两侧边缘顶点自然构成左右两段子 Bézier 曲线的控制多边形。],
) <fig:ch07-de-casteljau>

#proposition(title: [Bernstein 基与 Bézier 曲线的核心分析性质])[
  设 $bold(b)(t) = sum_(i=0)^n bold(b)_i B_i^n (t)$ 为 $n$ 次 Bézier 曲线，则对任意 $t in [0, 1]$ 满足：
  1. *非负性与单位分解（Partition of Unity）*：$B_i^n (t) >= 0$，且 $sum_(i=0)^n B_i^n (t) equiv 1$；
  2. *凸包性（Convex Hull Property）*：曲线段整体位于控制点的凸包 $"Conv"{bold(b)_0, dots, bold(b)_n}$ 内部，且仿射变换 $Phi(bold(x)) = bold(A) bold(x) + bold(t)$ 下满足仿射不变性 $Phi(bold(b)(t)) = sum_(i=0)^n Phi(bold(b)_i) B_i^n (t)$；
  3. *导数与端点相切定理*：曲线的一阶导数为 $n-1$ 次 Bézier 曲线：
     $ bold(b)'(t) = n sum_(i=0)^(n-1) (bold(b)_(i+1) - bold(b)_i) B_i^(n-1) (t) = n (bold(b)_1^(n-1) (t) - bold(b)_0^(n-1) (t)), $ <eq:ch07-bezier-deriv>
     特别地，端点处满足 $bold(b)(0) = bold(b)_0, bold(b)(1) = bold(b)_n$，且 $bold(b)'(0) = n (bold(b)_1 - bold(b)_0), bold(b)'(1) = n (bold(b)_n - bold(b)_(n-1))$；
  4. *细分不变性*：在任意分割点 $t_0 in (0, 1)$ 处，de Casteljau 金字塔左腰序列 $(bold(b)_0^0, bold(b)_0^1 (t_0), dots, bold(b)_0^n (t_0))$ 与右腰序列 $(bold(b)_0^n (t_0), bold(b)_1^(n-1) (t_0), dots, bold(b)_n^0)$ 恰好构成原曲线在 $[0, t_0]$ 与 $[t_0, 1]$ 上的完整控制多边形。
]

#proof[
  (1) 当 $t in [0, 1]$ 时显然 $t^i (1-t)^(n-i) >= 0$；由二项式定理 $1 = (t + (1-t))^n = sum_(i=0)^n binom(n, i) t^i (1-t)^(n-i) = sum_(i=0)^n B_i^n (t)$。(2) 非负权重与单位分解直接意味着每个曲线点 $bold(b)(t)$ 都是控制点的凸组合，故必属于凸包；线性项与平移项提出求和号后由 $sum_(i=0)^n B_i^n (t) = 1$ 即得仿射不变性。(3) 对 $B_i^n (t)$ 求导并利用恒等式 $i binom(n, i) = n binom(n-1, i-1)$ 及 $(n-i) binom(n, i) = n binom(n-1, i)$，有 $(d)/(d t) B_i^n (t) = n (B_(i-1)^(n-1) (t) - B_i^(n-1) (t))$（约定越界项为 $0$）。代入 $bold(b)'(t) = sum_(i=0)^n bold(b)_i (d)/(d t) B_i^n (t)$ 并做阿贝尔分部求和（重排下标），即得 @eq:ch07-bezier-deriv；令 $t=0$ 与 $t=1$ 即得端点切向量公式。(4) 展开 $bold(b)(u t_0)$（$u in [0, 1]$）的二项式复合系数并与 @eq:ch07-casteljau 的第 $r$ 层二项展开对比，两侧关于 $u$ 的 $n$ 次多项式系数逐项相等（几何直观见 @fig:ch07-de-casteljau）。
]

=== 分段拼接连续性、B 样条与 NURBS

单段高次 Bézier 曲线存在两大工程瓶颈：一是次数 $n$ 随控制点数增加而升高，导致数值不稳定与龙格振荡；二是每个基函数 $B_i^n (t)$ 在整个 $(0, 1)$ 区间均非零，移动任一控制点都会牵动整条曲线（缺乏*局部控制性*）。工业界解决方案是采用低次*分段 Bézier 曲线*或 *B 样条（B-Splines）*。

设两段三次 Bézier 曲线 $bold(p)(t)$（控制点 $bold(p)_0, dots, bold(p)_3$）与 $bold(q)(t)$（控制点 $bold(q)_0, dots, bold(q)_3$）在交点处拼接：
- *$C^0$ / $G^0$ 位置连续*：$bold(p)_3 = bold(q)_0$；
- *$C^1$ 参数一阶连续 vs. $G^1$ 几何切向连续*：$C^1$ 要求切向量大小与方向完全相等 $bold(p)'(1) = bold(q)'(0) <=> bold(p)_3 - bold(p)_2 = bold(q)_1 - bold(q)_0$（即 $bold(p)_2, bold(p)_3, bold(q)_1$ 共线且等距）；而 $G^1$ 仅要求单位切向一致，即 $bold(q)_1 - bold(q)_0 = kappa (bold(p)_3 - bold(p)_2)$（$kappa > 0$）。

为自动保证高阶连续性与局部支撑性，B 样条在非递减节点向量（Knot Vector）$bold(u) = (u_0, u_1, dots, u_(m))$ 上通过 *Cox-de Boor 递推公式*定义 $p$ 次基函数 $N_(i, p) (u)$@farin2002curves：

$ N_(i, 0) (u) = cases(1 comma & quad "若" u_i <= u < u_(i+1), 0 comma & quad "其他"), quad N_(i, p) (u) = (u - u_i)/(u_(i+p) - u_i) N_(i, p-1) (u) + (u_(i+p+1) - u)/(u_(i+p+1) - u_(i+1)) N_(i+1, p-1) (u), $ <eq:ch07-cox-de-boor>

其中约定 $0 / 0 = 0$。每个 $p$ 次 B 样条基函数 $N_(i, p) (u)$ 仅在局部区间 $[u_i, u_(i+p+1))$ 上非零，并在单重节点处天然具备 $C^(p-1)$ 连续性。进一步为每个控制点赋予齐次权重 $w_i > 0$，在四维齐次空间构造 B 样条并做透视除法，即得到*非均匀有理 B 样条（NURBS）*：$bold(c)(u) = (sum_i w_i bold(p)_i N_(i, p) (u)) / (sum_j w_j N_(j, p) (u))$。由于有理分式对射影变换封闭，NURBS 既能精确表示圆锥曲线（圆、椭圆、双曲面），又在透视投影下保持控制点变换不变性。

== 张量积参数曲面与曲面微分几何初阶 <sec:ch07-surfaces>

将一维参数曲线沿两个独立参数方向 $(u, v) in [0, 1]^2$ 做直积，即可由二维控制网格 ${bold(p)_(i, j)}$（$0 <= i <= n, 0 <= j <= m$）构造*张量积 Bézier 曲面片（Tensor-Product Bézier Patch）*：

$ bold(S)(u, v) = sum_(i=0)^n sum_(j=0)^m B_i^n (u) B_j^m (v) bold(p)_(i, j). $ <eq:ch07-tensor-surface>

计算 $bold(S)(u, v)$ 时，可先固定 $u$ 对每列控制点执行一维 de Casteljau 算法得到 $m+1$ 个临时控制点 $bold(q)_j (u) = sum_(i=0)^n B_i^n (u) bold(p)_(i, j)$，再沿 $v$ 方向对 ${bold(q)_j (u)}$ 执行一次一维 de Casteljau 插值。双三次 Bézier 曲面片（$n = m = 3$，共 16 个控制点，如经典的 Utah Teapot）是曲面造型的标准基元。

=== 切平面、第一与第二基本形式及曲率度量

设正则参数曲面 $bold(S)(u, v)$ 满足偏导向量 $bold(S)_u = partial bold(S) / partial u$ 与 $bold(S)_v = partial bold(S) / partial v$ 处处线性无关。在曲面点 $bold(S)(u, v)$ 处，$bold(S)_u$ 与 $bold(S)_v$ 张成二维切平面，单位表面法线定义为：

$ bold(n)(u, v) = (bold(S)_u times bold(S)_v) / norm(bold(S)_u times bold(S)_v) in SS^2. $ <eq:ch07-surface-normal>

考察曲面上无穷小位移 $d bold(S) = bold(S)_u d u + bold(S)_v d v$。弧长微元平方 $d s^2 = d bold(S) dot d bold(S)$ 诱导出切空间上的内积度量，称为曲面的*第一基本形式（First Fundamental Form）*，而位移相对单位法线变化率 $-d bold(S) dot d bold(n) = d^2 bold(S) dot bold(n)$ 则刻画了曲面在三维空间中的弯曲程度，称为*第二基本形式（Second Fundamental Form）*：

$ "I"(d u, d v) = mat(d u, d v) mat(E, F; F, G) vec(d u, d v), quad "II"(d u, d v) = mat(d u, d v) mat(L, M; M, N) vec(d u, d v), $ <eq:ch07-fundamental-forms>

其中第一基本形式系数为 $E = bold(S)_u dot bold(S)_u$、$F = bold(S)_u dot bold(S)_v$、$G = bold(S)_v dot bold(S)_v$（决定曲面上的曲线弧长、夹角与面积微元 $d A = sqrt(E G - F^2) d u d v$，属*内蕴几何量*）；第二基本形式系数为 $L = bold(S)_(u u) dot bold(n)$、$M = bold(S)_(u v) dot bold(n)$、$N = bold(S)_(v v) dot bold(n)$。Weingarten 形状算子（Shape Operator）对应的矩阵为 $"I"^(-1) "II"$，其两个特征值即为该点的主曲率 $kappa_1, kappa_2$。由此直接导出*高斯曲率（Gaussian Curvature）* $K$ 与*平均曲率（Mean Curvature）* $H$：

$ K = kappa_1 kappa_2 = (L N - M^2) / (E G - F^2), quad H = (1)/(2) (kappa_1 + kappa_2) = (E N - 2 F M + G L) / (2 (E G - F^2)). $ <eq:ch07-curvatures>

高斯绝妙定理（Theorema Egregium）指出 $K$ 仅依赖于第一基本形式系数及其导数（例如柱面 $K equiv 0$ 可无拉伸地展开为平面，而球面 $K = 1 / R^2 > 0$ 在任何平面参数化下必然发生面积或角度畸变），这直接构成了纹理映射（UV 展开）不可避免产生拉伸畸变的微分几何根源；平均曲率 $H$ 则刻画了局部面积泛函的一阶变分梯度（极小曲面满足 $H equiv 0$），将在第 8 章离散余切拉普拉斯算子中得到精确对应。

== 有向距离场（SDF）、构造实体几何（CSG）与球体追踪算法 <sec:ch07-sdf>

在隐式几何谱系中，最兼具数学优美性与计算实用性的表示是*有向距离场（Signed Distance Field, SDF）*。

#definition(title: [有向距离函数与程函方程])[
  设 $Omega subset RR^3$ 为带有光滑边界 $partial Omega = cal(S)$ 的有界闭区域。称标量场 $f: RR^3 -> RR$ 为 $Omega$ 的有向距离函数，若对任意 $bold(x) in RR^3$，其函数值等于 $bold(x)$ 到边界 $cal(S)$ 的带符号欧氏距离：
  $ f(bold(x)) = cases(- inf_(bold(y) in cal(S)) norm(bold(x) - bold(y)) comma & quad "若" bold(x) in Omega^circle.small "（内部）", 0 comma & quad "若" bold(x) in cal(S) "（表面）", + inf_(bold(y) in cal(S)) norm(bold(x) - bold(y)) comma & quad "若" bold(x) in RR^3 without Omega "（外部）".) $ <eq:ch07-sdf-def>
  在 $f$ 可微的任意空间点（除中轴骨架 Medial Axis 外几乎处处可微），$f$ 恒满足*程函方程（Eikonal Equation）* $norm(nabla f(bold(x))) = 1$，且表面点处的梯度直接给出朝外的单位表面法线 $bold(n)(bold(x)) = nabla f(bold(x))$。
]

=== 解析原语与 CSG 布尔算子

基本几何原语的精确 SDF 极为简洁：半径为 $r$ 的球体为 $f_"sphere" (bold(x)) = norm(bold(x)) - r$；半边长为 $bold(b) in RR_+^3$ 的轴对齐盒，设 $bold(q) = abs(bold(x)) - bold(b)$，则 $f_"box" (bold(x)) = norm(max(bold(q), bold(0))) + min(max(q_x, max(q_y, q_z)), 0)$。给定两个隐式体 $f_1, f_2$，*构造实体几何（CSG）*布尔运算与平滑混合（Smooth-Min，用于有机融合过渡）可写成闭式代数算子：

$ f_(A union B) (bold(x)) = min(f_1 (bold(x)), f_2 (bold(x))), quad f_(A inter B) (bold(x)) = max(f_1 (bold(x)), f_2 (bold(x))), quad f_(A without B) (bold(x)) = max(f_1 (bold(x)), -f_2 (bold(x))), $ <eq:ch07-csg>
$ "smin"_k (a, b) = min(a, b) - (1)/(6 k) max(k - abs(a - b), 0)^3, $ <eq:ch07-smin>

其中 $k > 0$ 控制融合半径。注意在精确交集与差集以及非等距缩放下，合成场可能不再严格满足 $norm(nabla f) = 1$，但通常仍保持 1-Lipschitz 下界性质（即 $abs(f(bold(x)) - f(bold(y))) <= norm(bold(x) - bold(y))$）。

=== 球体追踪（Sphere Tracing）算法与收敛保证

如何在不将 SDF 转化为网格的前提下直接渲染隐式表面？给定相机发射的光线 $bold(r)(t) = bold(o) + t bold(d)$（其中 $norm(bold(d)) = 1, t >= 0$），求交等价于寻找最小的 $t^* >= 0$ 使得 $f(bold(o) + t^* bold(d)) = 0$。若采用固定小步长 $Delta t$ 沿光线采样（Fixed-Step Ray Marching），步长过大将穿透薄壁几何，步长过小则计算量剧增。

John C. Hart 于 1996 年提出*球体追踪（Sphere Tracing）*算法@hart1996sphere：由于 $abs(f(bold(p)_k))$ 给出当前位置 $bold(p)_k = bold(o) + t_k bold(d)$ 到最近表面的最短欧氏距离，故以 $bold(p)_k$ 为球心、$r_k = abs(f(bold(p)_k))$ 为半径的开球内部*绝对不包含任何表面点*（称为无界安全球 Unbounding Sphere）。因此，光线可以百分之百安全地向前推进距离 $f(bold(p)_k)$ 而绝不越过零等值面：

$ t_(k+1) = t_k + f(bold(o) + t_k bold(d)), quad t_0 = 0. $ <eq:ch07-sphere-tracing>

若标量场 $f$ 是 Lipschitz 常数为 $lambda >= 1$ 的有向距离上界场（即 $abs(f(bold(x)) - f(bold(y))) <= lambda norm(bold(x) - bold(y))$，标准 SDF 满足 $lambda = 1$），则改进步进式 $t_(k+1) = t_k + f(bold(o) + t_k bold(d)) / lambda$ 生成单调递增序列 $t_0 <= t_1 <= dots <= t^*$，且必收敛至光线与零等值面的首个交点 $t^*$@hart1996sphere。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 左侧：球体追踪几何示意图
    // 隐式表面 f(x) = 0 及内部区域填充
    line(
      (3.0, 4.35), (3.8, 3.85), (4.5, 3.45), (5.2, 2.95), (5.55, 2.30),
      (5.9, 1.30), (6.5, 0.55), (7.6, 0.55), (7.6, 4.35),
      close: true, fill: softbg, stroke: none
    )
    line(
      (3.0, 4.35), (3.8, 3.85), (4.5, 3.45), (5.2, 2.95), (5.55, 2.30), (5.9, 1.30), (6.5, 0.55),
      stroke: 1.5pt + accent2
    )
    content((6.75, 3.75), text(size: 7.5pt, weight: "bold", fill: accent2)[内部 $f(bold(x)) < 0$])
    content((6.65, 1.45), text(size: 7.5pt, fill: accent2)[零等值面 $f(bold(x)) = 0$])
    content((1.7, 4.15), text(size: 7.5pt, fill: accent)[外部 $f(bold(x)) > 0$])

    // 三个安全步进圆 (Unbounding Spheres)
    // p0 = (1.55, 2.30), r0 = 1.45 -> p1 = (3.00, 2.30)
    circle((1.55, 2.30), radius: 1.45, stroke: (dash: "dashed", paint: accent, thickness: 0.75pt), fill: rgb(15, 92, 92, 12))
    // p1 = (3.00, 2.30), r1 = 1.05 -> p2 = (4.05, 2.30)
    circle((3.00, 2.30), radius: 1.05, stroke: (dash: "dashed", paint: accent, thickness: 0.75pt), fill: rgb(15, 92, 92, 18))
    // p2 = (4.05, 2.30), r2 = 0.75 -> p3 = (4.80, 2.30)
    circle((4.05, 2.30), radius: 0.75, stroke: (dash: "dashed", paint: accent, thickness: 0.75pt), fill: rgb(15, 92, 92, 24))
    // p3 = (4.80, 2.30), r3 = 0.50 -> p4 = (5.30, 2.30)
    circle((4.80, 2.30), radius: 0.50, stroke: (dash: "dashed", paint: accent, thickness: 0.75pt), fill: rgb(15, 92, 92, 30))

    // 光线 r(t) = o + t d
    line((0.5, 2.30), (6.3, 2.30), mark: (end: ">"), stroke: 1.0pt + ink)
    content((0.95, 2.62), text(size: 7.5pt, weight: "bold")[$bold(r)(t)$])

    // 半径标注线
    line((1.55, 2.30), (2.35, 3.51), stroke: 0.65pt + accent)
    content((1.75, 3.05), frame: "rect", fill: white, stroke: none, padding: 0.04, text(size: 7pt, fill: accent)[$r_0 = f(bold(p)_0)$])
    line((3.00, 2.30), (3.62, 3.15), stroke: 0.65pt + accent)
    content((3.15, 2.88), frame: "rect", fill: white, stroke: none, padding: 0.04, text(size: 7pt, fill: accent)[$r_1$])

    // 步进点 p0, p1, p2, p3, p*
    circle((1.55, 2.30), radius: 0.07, fill: accent, stroke: none)
    content((1.55, 1.95), text(size: 7.2pt)[$bold(p)_0$])
    circle((3.00, 2.30), radius: 0.07, fill: accent, stroke: none)
    content((3.00, 1.95), text(size: 7.2pt)[$bold(p)_1$])
    circle((4.05, 2.30), radius: 0.07, fill: accent, stroke: none)
    content((4.05, 1.95), text(size: 7.2pt)[$bold(p)_2$])
    circle((4.80, 2.30), radius: 0.07, fill: accent, stroke: none)
    content((4.80, 1.95), text(size: 7.2pt)[$bold(p)_3$])
    circle((5.55, 2.30), radius: 0.09, fill: warn, stroke: none)
    content((5.32, 1.88), frame: "rect", fill: white, stroke: none, padding: 0.04, text(size: 7.5pt, weight: "bold", fill: warn)[$bold(p)^*$])

    // 右侧：Sphere Tracing 算法逻辑框
    rect((8.1, 2.65), (14.3, 4.45), fill: bluebg, stroke: 0.8pt + accent, radius: 0.12)
    content((11.2, 4.08), text(size: 8pt, weight: "bold", fill: accent)[自适应安全步长保证（1-Lipschitz）])
    content((11.2, 3.52), text(size: 7.4pt)[开球 $cal(B)(bold(p)_k, abs(f(bold(p)_k)))$ 内无零等值面点])
    content((11.2, 2.98), text(size: 7.4pt)[步进更新：$t_(k+1) = t_k + f(bold(o) + t_k bold(d))$，绝不穿透表面])

    rect((8.1, 0.65), (14.3, 2.35), fill: softbg, stroke: 0.8pt + accent2, radius: 0.12)
    content((11.2, 1.98), text(size: 8pt, weight: "bold", fill: accent2)[终止判据与中心差分法线])
    content((11.2, 1.45), text(size: 7.4pt)[命中：$f(bold(p)_k) < epsilon$；逸出：$t_k > t_"max"$])
    content((11.2, 0.95), text(size: 7.4pt)[法线：$bold(n) approx "normalize"(nabla_epsilon f(bold(p)^*))$])
  })),
  caption: [球体追踪（Sphere Tracing）几何原理。在每一步 $bold(p)_k$ 处，查询有向距离 $r_k = f(bold(p)_k)$ 即获得安全球半径，光线直接沿方向 $bold(d)$ 跳跃至球面交点 $bold(p)_(k+1)$，在远离表面时大步跨越，逼近零等值面交点 $bold(p)^*$ 时自动缩减步长。],
) <fig:ch07-sphere-tracing>

如 @fig:ch07-sphere-tracing 所示，球体追踪在空旷区域仅需极少步数即可跨越，而在擦边光线（Grazing Rays）附近步长会因距离场影响而缩小。下面给出包含解析原语、平滑布尔并集、中心差分法线估计与球体追踪的完整可运行 NumPy 实现：

```python
import numpy as np

def sdf_scene(p: np.ndarray) -> np.ndarray:
    """场景 SDF：球体与轴对齐盒的平滑并集 (p: [..., 3])"""
    d_sphere = np.linalg.norm(p - np.array([-0.35, 0.0, 0.0]), axis=-1) - 0.55
    q = np.abs(p - np.array([0.35, 0.0, 0.0])) - np.array([0.42, 0.42, 0.42])
    d_box = np.linalg.norm(np.maximum(q, 0.0), axis=-1) + np.minimum(np.max(q, axis=-1), 0.0)
    k = 0.25  # 三次多项式平滑并集半径
    h = np.maximum(k - np.abs(d_sphere - d_box), 0.0) / k
    return np.minimum(d_sphere, d_box) - h * h * h * k / 6.0

def sdf_normal(p: np.ndarray, eps: float = 1e-4) -> np.ndarray:
    """四点四面体/六点中心差分法计算隐式表面单位法线 n = grad(f) / ||grad(f)||"""
    ex, ey, ez = np.array([eps, 0, 0]), np.array([0, eps, 0]), np.array([0, 0, eps])
    grad = np.stack([
        sdf_scene(p + ex) - sdf_scene(p - ex),
        sdf_scene(p + ey) - sdf_scene(p - ey),
        sdf_scene(p + ez) - sdf_scene(p - ez),
    ], axis=-1)
    return grad / (np.linalg.norm(grad, axis=-1, keepdims=True) + 1e-12)

def sphere_trace(ray_o: np.ndarray, ray_d: np.ndarray, t_max: float = 10.0,
                 eps: float = 1e-4, max_steps: int = 96):
    """向量化球体追踪器：返回命中距离 t、交点坐标与表面法线"""
    t = np.zeros(ray_o.shape[:-1], dtype=np.float64)
    for _ in range(max_steps):
        pts = ray_o + t[..., None] * ray_d
        dist = sdf_scene(pts)
        t = np.where((dist > eps) & (t < t_max), t + dist, t)
    hit_pts = ray_o + t[..., None] * ray_d
    hit_mask = sdf_scene(hit_pts) <= eps * 5.0
    return t, hit_mask, sdf_normal(hit_pts)
```

== 等值面提取（Marching Cubes / Dual Contouring）与现代神经隐式场 <sec:ch07-frontier>

当隐式场需要与现代光栅化引擎、物理碰撞网格或 CAD 下游管线对接时，必须执行*等值面提取（Isosurface Extraction）*，将连续标量场 $f(bold(x)) = 0$ 转化为显式多边形网格。

=== Marching Cubes 与 Dual Contouring 的对偶机制

Lorensen 与 Cline 于 1987 年提出的 *Marching Cubes（移动立方体）*算法@lorensen1987marching 将空间划分为规则三维体素网格：每个体素有 8 个角点，每个角点按 $f(bold(v)_i) < 0$ 或 $>= 0$ 呈现二值状态，共计 $2^8 = 256$ 种拓扑构型（扣除旋转与符号翻转对称性后归约为 15 种基本构型，为消除相邻体素共享面上的拓扑二义性洞孔，现代实现通常扩充至 33 种渐近决断构型）。当体素的某条棱两端符号相反时，算法通过线性插值 $bold(x) = (abs(f_2) bold(v)_1 + abs(f_1) bold(v)_2) / (abs(f_1) + abs(f_2))$ 在棱上放置顶点，并查表连接成三角形。然而，由于顶点被严格约束在网格棱上且未使用法线信息，Marching Cubes 会将硬边与尖角全部倒角磨平。

为重建尖锐特征（Sharp Features），Ju 等人于 2002 年提出 *Dual Contouring（对偶轮廓法）*@ju2002dual：不在网格棱上生成网格顶点，而是在*每个包含符号变化棱的体素内部*求解一个最佳特征顶点 $bold(v)^*$，再跨越每一条符号变化的网格棱，将围绕该棱的 4 个相邻体素内部顶点连接成一个四边形（与原网格互为拓扑对偶）。设体素被 $k$ 条符号变化棱切割，交点为 $bold(p)_i$、该处隐式场单位法线为 $bold(n)_i = nabla f(bold(p)_i)$，则体素内部顶点 $bold(v)^*$ 通过最小化*二次误差函数（Quadratic Error Function, QEF）*求解：

$ E_"QEF" (bold(v)) = sum_(i=1)^k (bold(n)_i^top (bold(v) - bold(p)_i))^2 = norm(bold(A) bold(v) - bold(b))_2^2, $ <eq:ch07-qef>

其中切平面超定方程通过截断奇异值分解（SVD）或 Tikhonov 正则化求解，使 $bold(v)^*$ 精确落回多个切平面的交线或角点上，从而完美保留机械零件的锐边与尖角@ju2002dual。

=== 现代演进：从 DeepSDF、NeuS 到可微网格提取

2019 年以来，隐式几何在深度学习与三维视觉中经历了范式复兴：

- 【已有成果】*连续神经隐式表示（DeepSDF）*：Park 等人提出的 DeepSDF@park2019deepsdf 用坐标多层感知机（Coordinate MLP）$f_theta (bold(z), bold(x)) approx s$ 直接拟合有向距离场，其中潜在编码 $bold(z) in RR^d$ 表征形状类别空间。相比高分辨率体素网格的 $O(N^3)$ 显存墙，神经 SDF 将任意拓扑的连续表面压缩进数兆字节的网络权重，并支持在潜空间 $bold(z)$ 上做光滑形状插值与补全。
- 【已有成果】*无偏神经体积表面重建（NeuS 与程函正则化）*：第 10 章将详述的早期 NeRF 仅学习体积密度 $sigma(bold(x))$，其提取的等值面充满噪声且存在视角依赖偏差。Wang 等人提出的 NeuS@wang2021neus 将场景参数化为神经有向距离场 $f_theta (bold(x))$，通过 S 型逻辑斯蒂密度核 $phi_s (f_theta (bold(x)))$ 将零等值面耦合进体渲染积分，并施加*程函正则化损失（Eikonal Loss）*：
  $ cal(L)_"eik" = EE_(bold(x)) [(norm(nabla_(bold(x)) f_theta (bold(x)))_2 - 1)^2], $ <eq:ch07-eikonal-loss>
  证明了该构造满足*一阶无偏性（First-Order Unbiasedness）*与遮挡感知性——即体渲染权重的局部极大值严格落在真实表面 $f_theta (bold(x)) = 0$ 处，使多视图光度监督得以恢复毫米级精度的光滑几何表面@wang2021neus。
- 【本书推断】*混合显隐式管线的收敛趋势*：2024–2026 年的工业界实践表明，纯神经隐式场在训练阶段的拓扑自由度无与伦比，但在部署与仿真阶段仍需回归显式图元。以 FlexiCubes、DMTet 为代表的*可微等值面提取层*将 Dual Contouring / Marching Tetrahedra 嵌入端到端反向传播图中，使「神经 SDF 拓扑发现 $->$ 可微等值面提取 $->$ 硬件光栅化与物理引擎驱动」成为三维生成模型（3D Generative AI）的标准底座。

#keybox(title: [本章要点])[
  1. *显隐式对偶定律*：显式表示 $bold(S)(u, v)$ 擅长表面点枚举与硬件光栅化，但内外测试困难；隐式表示 $f(bold(x)) = 0$ 擅长 $O(1)$ 内外测试、CSG 布尔合成与拓扑变化，但表面采样需借助球体追踪或等值面提取。
  2. *Bézier 与样条基石*：de Casteljau 递归线性插值与 Bernstein 基展开等价；非负性与单位分解保证了凸包性与仿射不变性；B 样条与 NURBS 通过 Cox-de Boor 局部支撑基与齐次权重克服了全局牵连与圆锥曲线精确表示难题。
  3. *曲面微分几何*：第一基本形式 $(E, F, G)$ 度量内蕴弧长与面积，第二基本形式 $(L, M, N)$ 度量法向弯曲；高斯曲率 $K = kappa_1 kappa_2$ 决定了 UV 参数化展开的必然拉伸界限。
  4. *SDF 与神经隐式场*：精确有向距离场满足程函方程 $norm(nabla f) = 1$；Sphere Tracing 利用 $abs(f(bold(p)_k))$ 的无界安全球性质实现无穿透自适应求交；Marching Cubes 与 Dual Contouring 打通了隐式场到显式网格的桥梁，并在 DeepSDF 与 NeuS 中演进为可微三维重建的核心底座。
]
