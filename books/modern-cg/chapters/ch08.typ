#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 多边形网格处理：半边结构、离散微分算子与网格演化

第 7 章展示了连续参数曲面与隐式有向距离场的数学优美性，但在现代 GPU 光栅化管线、实时物理仿真与交互式造型工具中，*多边形网格（Polygon Mesh，尤其是三角形网格与四边形网格）*始终占据绝对主导地位@botsch2010polygon。多边形网格将连续二维流形离散化为顶点（Vertices）、边（Edges）与面片（Faces）的分段线性复形：它既能以任意精度逼近复杂拓扑表面，又能直接映射为硬件光栅化器的重心插值原语。

本章系统构建数字几何处理（Digital Geometry Processing）的核心理论与算法体系：首先定义二维拓扑流形、欧拉-庞加莱公式与支持 $O(1)$ 邻域导航的半边数据结构（@sec:ch08-halfedge），随后推导离散微分几何中的余切 Laplace-Beltrami 算子、离散高斯/平均曲率与隐式网格平滑（@sec:ch08-laplacian），进而剖析从粗控制网格生成光滑极限曲面的 Loop 细分与 Catmull-Clark 细分规则（@sec:ch08-subdivision），以及保特征减面的边坍缩与二次误差度量（QEM）算法（@sec:ch08-qem），最后探讨拉普拉斯谱分解与自回归神经网格生成的前沿演进（@sec:ch08-frontier）。

== 拓扑流形与半边数据结构（Half-Edge Mesh） <sec:ch08-halfedge>

在渲染接口（如 OpenGL / Vulkan 顶点缓冲区）中，网格常表示为「三角形汤（Triangle Soup）」或*索引面片集（Indexed Face Set, IFS）*：仅存储顶点坐标数组 $cal(V) in RR^(V times 3)$ 与面片顶点索引三元组数组 $cal(F) in NN^(F times 3)$。然而，几何处理算子（如法线加权、曲率估计、边翻转与网格简化）频繁需要查询「围绕某顶点 $v_i$ 的所有相邻三角形（1-Ring 邻域）」或「某条边两侧的相邻面片」。在纯索引面片集上，此类邻接查询需要 $O(F)$ 的全表扫描，且无法阻止非流形拓扑退化。

=== 二维流形条件与欧拉-庞加莱特征数

称离散三角形网格 $cal(M) = (cal(V), cal(E), cal(F))$ 为合法的*二维流形网格（2-Manifold Mesh）*，若表面上每一点的局部开邻域均同胚于二维欧氏开圆盘 $RR^2$（带边界流形的边界点同胚于半圆盘）@botsch2010polygon。转化到离散组合拓扑，二维流形网格必须同时满足三条铁律：
1. *边流形性*：每条内部边恰好被 2 个面片共享，每条边界边仅属于 1 个面片（若一条边被 $>= 3$ 个面片共享，则构成非流形鳍片边）；
2. *顶点流形性*：与任一顶点 $v$ 关联的所有面片必须能排成一个单连通的扇形环（1-Ring Fan）或单段开扇形（严禁两个圆锥仅在顶点处相连的「沙漏顶点」）；
3. *可定向性（Orientability）*：所有相邻面片的顶点环绕方向（逆时针 CCW）在公共边上诱导相反的定向（即剔除莫比乌斯带与克莱因瓶）。

对任意亏格（Genus，即贯穿孔洞数）为 $g$、边界环数量为 $b$ 的紧致可定向二维流形网格，其顶点数 $V = abs(cal(V))$、边数 $E = abs(cal(E))$ 与面片数 $F = abs(cal(F))$ 恒满足*欧拉-庞加莱公式（Euler-Poincaré Formula）*@botsch2010polygon @crane2013digital：

$ chi(cal(M)) = V - E + F = 2 - 2 g - b, $ <eq:ch08-euler>

其中 $chi(cal(M))$ 称为欧拉示性数。对封闭且亏格较小的大型纯三角形网格，由于每个三角形有 3 条边、每条内部边被 2 个三角形共享（$3 F = 2 E$），联立 $V - E + F approx 0$ 立即推导出著名的*网格常数比例律*：

$ F approx 2 V, quad E approx 3 V, quad "顶点平均度数（Valence）" bar(d) = (2 E) / V approx 6. $ <eq:ch08-mesh-ratios>

=== 半边数据结构与 $O(1)$ 一环邻域遍历

为了在二维流形网格上以 $O(1)$ 常数时间完成局部邻域导航与拓扑修改，工业界几何内核（如 CGAL、OpenMesh）普遍采用*半边数据结构（Half-Edge Data Structure / Doubly Connected Edge List）*@botsch2010polygon。

#definition(title: [半边数据结构（Half-Edge Mesh）])[
  半边结构将无向边 $e in cal(E)$ 拆分为两条方向相反、互为配对的有向半边（Half-Edges）$h$ 与 $h."twin"$。每条有向半边 $h$ 维护五个核心引用指针：
  - $h."twin"$：指向同一条无向边上方向相反的配对半边，满足 $h."twin"."twin" = h$；
  - $h."next"$：指向所属面片内部沿逆时针（CCW）环绕方向的下一条半边（三角形中满足 $h."next"."next"."next" = h$）；
  - $h."vertex"$：指向该有向半边指向的目标终点顶点（或约定为起点，全库统一即可；本章统一约定为*半边起点* $v_"orig"$，则终点为 $h."twin"."vertex"$）；
  - $h."edge"$ 与 $h."face"$：分别指向所属的无向边 $e$ 与左侧关联面片 $f$（若位于网格外边界，则虚设边界半边的 $h."face" = "null"$）。
  同时，每个顶点 $v$、每条边 $e$ 与每个面片 $f$ 仅需各存储一个指向其任一关联半边的入口指针 $v."halfedge"$、$e."halfedge"$ 与 $f."halfedge"$。
]

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 左侧：相邻三角形 f_L 与 f_R 的半边拓扑连接图
    // 顶点坐标：v_i = (4.1, 0.8), v_j = (4.1, 4.4), v_k = (0.9, 2.6), v_l = (7.3, 2.6)
    line((4.1, 0.8), (4.1, 4.4), (0.9, 2.6), close: true, fill: softbg, stroke: 0.8pt + gray.darken(25%))
    line((4.1, 0.8), (7.3, 2.6), (4.1, 4.4), close: true, fill: bluebg, stroke: 0.8pt + gray.darken(25%))

    // 左面片 f_L 内部的逆时针半边环 (h, h.next, h.next.next)
    line((3.88, 1.35), (3.88, 3.85), mark: (end: ">"), stroke: 1.15pt + accent)
    content((3.48, 2.60), text(size: 7.8pt, weight: "bold", fill: accent)[$h$])

    line((3.65, 3.92), (1.45, 2.72), mark: (end: ">"), stroke: 0.9pt + accent)
    content((2.40, 3.65), text(size: 7.2pt, fill: accent)[$h."next"$])

    line((1.45, 2.48), (3.65, 1.28), mark: (end: ">"), stroke: 0.9pt + accent)
    content((2.25, 1.55), text(size: 7.2pt, fill: accent)[$h."next"^2$])

    content((2.75, 2.60), text(size: 7.5pt, weight: "bold", fill: ink)[面 $f_L$])

    // 右面片 f_R 内部的逆时针半边环 (h.twin 及其后继)
    line((4.32, 3.85), (4.32, 1.35), mark: (end: ">"), stroke: 1.15pt + accent2)
    content((4.95, 2.60), text(size: 7.8pt, weight: "bold", fill: accent2)[$h."twin"$])

    line((4.55, 1.28), (6.75, 2.48), mark: (end: ">"), stroke: 0.9pt + accent2)
    line((6.75, 2.72), (4.55, 3.92), mark: (end: ">"), stroke: 0.9pt + accent2)
    content((5.75, 2.60), text(size: 7.5pt, weight: "bold", fill: ink)[面 $f_R$])

    // twin 双向配对虚线箭头
    line((3.92, 2.95), (4.28, 2.95), mark: (start: ">", end: ">"), stroke: (dash: "dotted", paint: warn, thickness: 0.8pt))

    // 四个顶点圆点与标签
    circle((4.1, 0.8), radius: 0.09, fill: ink, stroke: none)
    content((4.1, 0.42), text(size: 7.5pt, weight: "bold")[$v_i$（$h."vertex"$）])
    circle((4.1, 4.4), radius: 0.09, fill: ink, stroke: none)
    content((4.1, 4.76), text(size: 7.5pt, weight: "bold")[$v_j$])
    circle((0.9, 2.6), radius: 0.09, fill: ink, stroke: none)
    content((0.45, 2.6), text(size: 7.5pt, weight: "bold")[$v_k$])
    circle((7.3, 2.6), radius: 0.09, fill: ink, stroke: none)
    content((7.75, 2.6), text(size: 7.5pt, weight: "bold")[$v_l$])

    // 右侧：半边五元指针表与局部网格重连操作说明框
    rect((8.3, 2.75), (14.3, 4.75), fill: bluebg, stroke: 0.8pt + accent, radius: 0.12)
    content((11.3, 4.38), text(size: 8pt, weight: "bold", fill: accent)[顶点 $v_i$ 的 $O(1)$ 一环遍历（1-Ring）])
    content((11.3, 3.80), text(size: 7.3pt)[初值：$h <- v_i ."halfedge"$（以 $v_i$ 为起点的出射半边）])
    content((11.3, 3.22), text(size: 7.3pt)[顺时针步进：$h <- h."twin"."next"$，直至回到初值])

    rect((8.3, 0.50), (14.3, 2.45), fill: softbg, stroke: 0.8pt + accent2, radius: 0.12)
    content((11.3, 2.08), text(size: 8pt, weight: "bold", fill: accent2)[局部流形拓扑算子（纯指针重连）])
    content((11.3, 1.50), text(size: 7.3pt)[边翻转（Edge Flip）：将公共边 $(v_i, v_j)$ 替换为 $(v_k, v_l)$])
    content((11.3, 0.95), text(size: 7.3pt)[边分裂 / 边坍缩：在 $O(1)$ 时间内增删局部半边环])
  })),
  caption: [半边数据结构（Half-Edge Mesh）的拓扑指针组织。无向公共边 $(v_i, v_j)$ 被拆分为分别属于左面片 $f_L$ 与右面片 $f_R$ 的反向半边 $h$ 与 $h."twin"$；交替调用 $"twin"$ 与 $"next"$ 即可在 $O(1)$ 步内围绕顶点 $v_i$ 旋转遍历其全部一环邻居。],
) <fig:ch08-halfedge>

如 @fig:ch08-halfedge 所示，从以顶点 $v_i$ 为起点的半边 $h = v_i ."halfedge"$ 出发，执行一步 $h <- h."twin"."next"$，恰好跨越公共边进入相邻三角形并以 $v_i$ 为起点取出下一条出射半边！因此，遍历度数（关联边数）为 $d_i$ 的顶点的一环邻域仅需严格的 $O(d_i) = O(1)$ 常数时间，且边翻转（Edge Flip）、边分裂（Edge Split）与边坍缩（Edge Collapse）均只涉及常数个局部半边指针的原地重连。

== 离散微分几何：余切拉普拉斯算子与离散曲率度量 <sec:ch08-laplacian>

如何在分段线性的多边形网格上定义光滑曲面的拉普拉斯算子、平均曲率与高斯曲率？这是*离散微分几何（Discrete Differential Geometry, DDG）*的核心命题@meyer2003discrete @crane2013digital。

=== 均匀图拉普拉斯与余切 Laplace-Beltrami 算子

设定义在网格顶点上的离散标量场为 $f: cal(V) -> RR$（或三维坐标向量场 $bold(x): cal(V) -> RR^3$）。最朴素的离散化是*均匀图拉普拉斯（Uniform Laplacian）*：$(bold(L)_"uni" f)_i = (1)/(d_i) sum_(j in cal(N)(i)) (f_j - f_i)$，即用一环邻居的算术平均减去中心顶点。然而，均匀图拉普拉斯完全忽略了网格边的实际几何长度与三角形内角：即便在完全平坦的平面区域上，只要网格剖分不均匀，$(bold(L)_"uni" bold(x))_i$ 就会产生平行于切平面的伪漂移，导致顶点在网格平滑中发生切向滑动畸变。

Meyer、Desbrun、Schröder 与 Barr 于 2003 年利用分段线性有限元（Galerkin FEM）与离散外微分（DEC）严格推导出保持几何内蕴性的*余切 Laplace-Beltrami 算子（Cotangent Laplacian）*@meyer2003discrete @crane2013digital：

$ (Delta_M f)_i = (1)/(2 A_i) sum_(j in cal(N)(i)) (cot alpha_(i j) + cot beta_(i j)) (f_j - f_i), $ <eq:ch08-cot-laplacian>

其中 $cal(N)(i)$ 为顶点 $v_i$ 的一环相邻顶点集，$alpha_(i j)$ 与 $beta_(i j)$ 分别为共享边 $(v_i, v_j)$ 的两个左右相邻三角形中与该边相对的两个内角，$A_i$ 为顶点 $v_i$ 管辖的局部控制面积（通常取重心配分面积 $A_i = (1)/(3) sum_(t in cal(F)(i)) "Area"(t)$ 或混合 Voronoi 面积@meyer2003discrete）。在矩阵形式下，令刚度矩阵（对称余切权矩阵）$bold(W)_(i j) = (1)/(2) (cot alpha_(i j) + cot beta_(i j))$（对角元 $bold(W)_(i i) = - sum_(j != i) bold(W)_(i j)$），对角质量矩阵 $bold(M) = "diag"(A_1, dots, A_V)$，则余切拉普拉斯算子分解为 $bold(L) = bold(M)^(-1) bold(W)$。

=== 平均曲率法向、角亏高斯曲率与离散 Gauss-Bonnet 定理

将余切拉普拉斯算子直接作用于网格顶点的三维位置坐标 $bold(x)_i in RR^3$，由于坐标函数围绕局部区域的曲面积分等价于边界外法向张力之和，可得*离散平均曲率法向（Mean Curvature Normal）*恒等式@meyer2003discrete：

$ Delta_M bold(x)_i = (1)/(2 A_i) sum_(j in cal(N)(i)) (cot alpha_(i j) + cot beta_(i j)) (bold(x)_j - bold(x)_i) = - 2 H(bold(x)_i) bold(n)_i, $ <eq:ch08-mean-curvature-normal>

由此直接同时读出顶点处的离散平均曲率大小 $H_i = (1)/(2) norm(Delta_M bold(x)_i)$ 与单位表面法线方向！与此同时，离散*高斯曲率（Discrete Gaussian Curvature）*由顶点 $v_i$ 周围所有关联三角形 $t in cal(F)(i)$ 在 $v_i$ 处的内角和偏离平面周角 $2 pi$ 的*角亏（Angle Deficit）*给出@meyer2003discrete @crane2013digital：

$ K_i = (1)/(A_i) (2 pi - sum_(t in cal(F)(i)) theta_t^(i)). $ <eq:ch08-gaussian-curvature>

#theorem(title: [离散 Gauss-Bonnet 定理])[
  对任意无边界封闭二维流形三角形网格 $cal(M) = (cal(V), cal(E), cal(F))$，所有顶点的面积加权离散高斯曲率之和严格等于欧拉示性数的 $2 pi$ 倍，且与顶点几何位置完全无关：
  $ sum_(i=1)^V A_i K_i = sum_(i=1)^V (2 pi - sum_(t in cal(F)(i)) theta_t^(i)) = 2 pi chi(cal(M)) = 2 pi (2 - 2 g). $ <eq:ch08-gauss-bonnet>
]

#proof[
  将所有顶点处的内角亏损直接求和：由于每个三角形 $t in cal(F)$ 的三个内角之和恒为 $pi$，故全部顶点周围的内角总和等于 $pi F$。利用封闭流形三角形网格的拓扑关系 $3 F = 2 E <=> F = 2 E - 2 F$，可得 $sum_(i=1)^V A_i K_i = 2 pi V - pi F = 2 pi V - 2 pi (E - F) = 2 pi (V - E + F) = 2 pi chi(cal(M))$。
]

=== 显式与隐式拉普拉斯网格平滑

利用平均曲率法向流（Mean Curvature Flow）$partial bold(X) / partial t = Delta_M bold(X)$ 可滤除网格表面的高频几何噪声@botsch2010polygon。若采用显式前向欧拉步进 $bold(X)^(k+1) = (bold(I) + lambda bold(M)^(-1) bold(W)) bold(X)^k$，步长 $lambda$ 受限于最小网格边长（CFL 条件），大步长下极易发散爆炸。工业界标准方案是求解*无条件稳定的后向隐式欧拉方程*（或采用正负步长交替的 Taubin 无收缩滤波）：

$ (bold(M) - lambda bold(W)) bold(X)^(k+1) = bold(M) bold(X)^k, $ <eq:ch08-implicit-smoothing>

由于 $(bold(M) - lambda bold(W))$ 是对称正定（SPD）稀疏矩阵，可通过稀疏 Cholesky 分解或共轭梯度法在毫秒级时间内求解。下面给出构建稀疏余切拉普拉斯矩阵与隐式网格平滑的 Python（NumPy / SciPy 风格）实现：

```python
import numpy as np

def cotangent_laplacian_and_smooth(V: np.ndarray, F: np.ndarray, lam: float = 1e-3):
    """构建对称余切刚度矩阵 W、重心面积质量矩阵 M，并执行一步隐式拉普拉斯平滑"""
    n_verts = len(V)
    W = np.zeros((n_verts, n_verts), dtype=np.float64)
    A = np.zeros(n_verts, dtype=np.float64)
    # 遍历三角形三个轮换顶点 (i, j, k)，在角 k 处计算边 (i, j) 的余切权重
    for a, b, c in [(0, 1, 2), (1, 2, 0), (2, 0, 1)]:
        i, j, k = F[:, a], F[:, b], F[:, c]
        u, v = V[i] - V[k], V[j] - V[k]
        cross_norm = np.linalg.norm(np.cross(u, v), axis=1)
        cot_k = np.sum(u * v, axis=1) / (cross_norm + 1e-12)
        np.add.at(W, (i, j), 0.5 * cot_k)
        np.add.at(W, (j, i), 0.5 * cot_k)
        np.add.at(A, i, cross_norm / 6.0)  # 每个三角形面积 0.5 * cross_norm 的 1/3
    np.fill_diagonal(W, -np.sum(W, axis=1))
    # 求解对称正定线性系统 (M - lam * W) X_{k+1} = M X_k
    lhs = np.diag(A) - lam * W
    rhs = A[:, None] * V
    return np.linalg.solve(lhs, rhs)
```

== 网格细分：Loop 细分与 Catmull-Clark 细分的拓扑与几何规则 <sec:ch08-subdivision>

*细分曲面（Subdivision Surfaces）*打通了离散多边形网格与连续光滑样条曲面之间的壁垒：从粗糙控制网格 $cal(M)^0$ 出发，反复交替执行「拓扑分裂（Topological Split）」与「局部加权平滑（Geometric Averaging）」，其极限曲面 $cal(M)^infinity = lim_(k -> infinity) cal(M)^k$ 收敛至处处光滑的分段多项式样条曲面，且完全不受任意亏格拓扑的限制。

=== 三角形网格的 Loop 细分

Charles Loop 于 1987 年针对纯三角形网格提出基于四次箱式样条（Quartic Box Spline）的 *Loop 细分*@loop1987smooth。每一轮迭代将每个三角形沿三边中点执行 *1-to-4 拓扑分裂*，生成 4 个小三角形，并按两套掩模（Stencil）更新几何位置：
1. *新边点（Odd / Edge Vertex）*：对内部边 $(v_0, v_1)$（两侧相邻三角形相对顶点为 $v_2, v_3$），新顶点位置取加权组合：
   $ bold(v)_"edge" = (3)/(8) (bold(v)_0 + bold(v)_1) + (1)/(8) (bold(v)_2 + bold(v)_3) quad ("边界边取" (1)/(2)(bold(v)_0 + bold(v)_1)). $ <eq:ch08-loop-edge>
2. *旧顶点（Even / Vertex Update）*：设旧顶点 $bold(v)$ 的一环邻居为 $bold(v)_1, dots, bold(v)_n$（度数 $n$），其更新位置为：
   $ bold(v)' = (1 - n beta) bold(v) + beta sum_(i=1)^n bold(v)_i, quad beta = cases((3)/(16) comma & quad "若" n = 3, (1)/(n) ((5)/(8) - ((3)/(8) + (1)/(4) cos((2 pi)/(n)))^2) comma & quad "若" n > 3.) $ <eq:ch08-loop-vertex>

在所有正则顶点（度数为 $n = 6$）处，Loop 极限曲面达到 $C^2$ 连续；在度数 $n != 6$ 的*奇异点（Extraordinary Vertices）*处仍严格保证 $C^1$ 切平面连续@loop1987smooth。

=== 一般多边形与四边形网格的 Catmull-Clark 细分

Edwin Catmull 与 Jim Clark 于 1978 年将双三次均匀 B 样条曲面推广至任意拓扑多边形网格@catmull1978recursively（成为 Pixar 动画工业与现代 DCC 软件的绝对标准）。每轮迭代包含三步几何加权与四边形拓扑重构：
1. *面点（Face Point）*：每个面片 $f$ 生成中心点 $bold(f)_i = (1)/(abs(f)) sum_(v in f) bold(v)$（其所有顶点的算术平均）；
2. *边点（Edge Point）*：每条内部边 $e = (v_1, v_2)$（两侧相邻面片的新面点为 $bold(f)_L, bold(f)_R$）生成边点 $bold(e)_j = (bold(v)_1 + bold(v)_2 + bold(f)_L + bold(f)_R) / 4$；
3. *原顶点更新（Vertex Point）*：对度数为 $n$ 的旧顶点 $bold(v)$，记其关联的 $n$ 个新面点均值为 $bold(F) = (1)/(n) sum_(i=1)^n bold(f)_i$，关联的 $n$ 条原边中点均值为 $bold(R) = (1)/(n) sum_(j=1)^n (bold(v) + bold(v)_j) / 2$，则原顶点更新为：
   $ bold(v)' = (bold(F) + 2 bold(R) + (n - 3) bold(v)) / n. $ <eq:ch08-catmull-clark>

拓扑连接上，将每个面点与其边界上的所有新边点相连，使原本的 $k$ 边形分裂为 $k$ 个四边形。因此，*只需经过第 1 轮 Catmull-Clark 细分，网格中所有非四边形面片全部消失*，且奇异点（度数 $n != 4$）的数量自第 1 轮起永久恒定不变！其极限曲面在正则四边形区域（$n = 4$）精确退化为 $C^2$ 连续的双三次均匀 B 样条曲面，在奇异点处保持 $C^1$ 连续@catmull1978recursively。

== 网格简化：边坍缩与二次误差度量（QEM）推导 <sec:ch08-qem>

与细分相反，三维扫描或等值面提取往往产生数千万面片的冗余网格，需要通过*网格简化（Mesh Simplification）*在保留几何轮廓的前提下大幅削减面数，构建多细节层次（LOD）。Garland 与 Heckbert 于 1997 年提出的*基于二次误差度量的边坍缩算法（Quadric Error Metrics, QEM）*@garland1997surface 是兼顾速度与保特征精度的经典里程碑。

=== 平面二次误差矩阵与边坍缩代价推导

每次*边坍缩（Edge Collapse）*操作 $(v_1, v_2) -> bar(v)$ 将一条边的两个端点合并为一个新顶点 $bar(bold(v)) = (x, y, z, 1)^top$（齐次坐标），同时删除共享该边的两个退化三角形。如何度量新顶点 $bar(bold(v))$ 偏离原始局部几何表面的误差？

考察与原顶点关联的某三角形所在平面，其单位法线为 $bold(n) = (a, b, c)^top$（$a^2 + b^2 + c^2 = 1$），平面方程为 $bold(p)^top bar(bold(v)) = a x + b y + c z + d = 0$，其中 $bold(p) = (a, b, c, d)^top$。空间任意点 $bar(bold(v))$ 到该平面的有向距离平方恰好可改写为齐次二次型：

$ (bold(p)^top bar(bold(v)))^2 = (bar(bold(v))^top bold(p)) (bold(p)^top bar(bold(v))) = bar(bold(v))^top (bold(p) bold(p)^top) bar(bold(v)) = bar(bold(v))^top bold(K)_p bar(bold(v)), quad bold(K)_p = bold(p) bold(p)^top = mat(a^2, a b, a c, a d; a b, b^2, b c, b d; a c, b c, c^2, c d; a d, b d, c d, d^2). $ <eq:ch08-fundamental-quadric>

定义初始顶点 $v_i$ 的*二次误差矩阵（Quadric Matrix）*为其一环所有关联三角形平面二次型之和 $bold(Q)_i = sum_(p in "planes"(v_i)) bold(K)_p in RR^(4 times 4)$。当执行边坍缩 $(v_1, v_2) -> bar(v)$ 时，新顶点 $bar(v)$ 的累积二次矩阵近似设为 $bold(Q)_(bar(v)) = bold(Q)_1 + bold(Q)_2$，其几何误差代价函数为：

$ Delta(bar(bold(v))) = bar(bold(v))^top bold(Q)_(bar(v)) bar(bold(v)) = bar(bold(v))^top mat(q_(11), q_(12), q_(13), q_(14); q_(12), q_(22), q_(23), q_(24); q_(13), q_(23), q_(33), q_(34); q_(14), q_(24), q_(34), q_(44)) bar(bold(v)). $ <eq:ch08-qem-cost>

由于 $Delta(bar(bold(v)))$ 是关于三维坐标 $(x, y, z)$ 的二次凸函数（其等误差面为椭球面），令梯度为零 $partial Delta / partial x = partial Delta / partial y = partial Delta / partial z = 0$，即可通过求解 $3 times 3$ 线性方程组直接得出使二次误差最小的*最优坍缩位置* $bar(bold(v))^*$@garland1997surface：

$ mat(q_(11), q_(12), q_(13), q_(14); q_(12), q_(22), q_(23), q_(24); q_(13), q_(23), q_(33), q_(34); 0, 0, 0, 1) bar(bold(v))^* = vec(0, 0, 0, 1). $ <eq:ch08-qem-opt>

若左上角 $3 times 3$ 子矩阵接近奇异（例如局部面片共面或共线），则回退至在线段 $(bold(v)_1, bold(v)_2)$ 的端点与中点中选取使 $Delta(bar(bold(v)))$ 最小的位置。全局算法将所有边按最优坍缩代价 $Delta(bar(bold(v))^*)$ 放入*最小优先队列（Min-Heap）*，每步弹出代价最小的边执行坍缩，令 $bold(Q)_(bar(v)) <- bold(Q)_1 + bold(Q)_2$ 并更新相邻边的堆优先级，直至达到目标面数。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 左框：坍缩前局部一环拓扑与二次误差椭球
    rect((0.3, 0.4), (4.7, 4.6), fill: softbg, stroke: 0.8pt + gray.darken(25%), radius: 0.12)
    content((2.5, 4.25), text(size: 7.8pt, weight: "bold")[1. 坍缩前边 $(v_1, v_2)$ 与二次矩阵])

    // 局部网格线 (左)
    line((1.7, 2.2), (3.3, 2.2), stroke: 1.4pt + warn)
    line((1.7, 2.2), (2.5, 3.6), (3.3, 2.2), stroke: 0.75pt + gray.darken(30%))
    line((1.7, 2.2), (2.5, 0.85), (3.3, 2.2), stroke: 0.75pt + gray.darken(30%))
    line((1.7, 2.2), (0.8, 3.1), (2.5, 3.6), stroke: 0.75pt + gray.darken(30%))
    line((1.7, 2.2), (0.8, 1.3), (2.5, 0.85), stroke: 0.75pt + gray.darken(30%))
    line((3.3, 2.2), (4.2, 3.1), (2.5, 3.6), stroke: 0.75pt + gray.darken(30%))
    line((3.3, 2.2), (4.2, 1.3), (2.5, 0.85), stroke: 0.75pt + gray.darken(30%))

    // 等误差椭圆示意
    circle((1.7, 2.2), radius: (0.42, 0.26), stroke: (dash: "dashed", paint: accent, thickness: 0.7pt))
    circle((3.3, 2.2), radius: (0.42, 0.26), stroke: (dash: "dashed", paint: accent, thickness: 0.7pt))
    circle((1.7, 2.2), radius: 0.08, fill: accent, stroke: none)
    content((1.45, 2.52), text(size: 7.2pt, weight: "bold", fill: accent)[$v_1 (bold(Q)_1)$])
    circle((3.3, 2.2), radius: 0.08, fill: accent, stroke: none)
    content((3.55, 2.52), text(size: 7.2pt, weight: "bold", fill: accent)[$v_2 (bold(Q)_2)$])

    // 中框：QEM 代价优化与优先队列
    rect((5.1, 0.4), (9.5, 4.6), fill: bluebg, stroke: 0.8pt + accent, radius: 0.12)
    content((7.3, 4.25), text(size: 7.8pt, weight: "bold", fill: accent)[2. QEM 累加与最优位置求解])
    content((7.3, 3.50), text(size: 7.4pt)[平面矩阵：$bold(K)_p = bold(p) bold(p)^top in RR^(4 times 4)$])
    content((7.3, 2.85), text(size: 7.4pt)[累加二次型：$bold(Q)_(bar(v)) = bold(Q)_1 + bold(Q)_2$])
    content((7.3, 2.15), text(size: 7.4pt)[极小化：$bar(bold(v))^* = argmin bar(bold(v))^top bold(Q)_(bar(v)) bar(bold(v))$])
    content((7.3, 1.45), text(size: 7.2pt)[求解 $nabla Delta(bar(bold(v))) = bold(0)$ 保留折痕锐边])
    content((7.3, 0.85), text(size: 7.2pt, fill: accent2)[最小堆按 $Delta(bar(bold(v))^*)$ 贪心弹出])

    // 右框：坍缩后局部拓扑更新
    rect((9.9, 0.4), (14.3, 4.6), fill: softbg, stroke: 0.8pt + accent2, radius: 0.12)
    content((12.1, 4.25), text(size: 7.8pt, weight: "bold", fill: accent2)[3. 坍缩后 $(v_1, v_2) -> bar(v)^*$（减 2 面）])

    // 局部网格线 (右：合并至中心 v_bar = (12.1, 2.2))
    line((12.1, 2.2), (12.1, 3.6), stroke: 0.8pt + gray.darken(30%))
    line((12.1, 2.2), (12.1, 0.85), stroke: 0.8pt + gray.darken(30%))
    line((12.1, 2.2), (10.5, 3.1), (12.1, 3.6), stroke: 0.8pt + gray.darken(30%))
    line((12.1, 2.2), (10.5, 1.3), (12.1, 0.85), stroke: 0.8pt + gray.darken(30%))
    line((12.1, 2.2), (13.7, 3.1), (12.1, 3.6), stroke: 0.8pt + gray.darken(30%))
    line((12.1, 2.2), (13.7, 1.3), (12.1, 0.85), stroke: 0.8pt + gray.darken(30%))
    line((10.5, 3.1), (10.5, 1.3), stroke: 0.8pt + gray.darken(30%))
    line((13.7, 3.1), (13.7, 1.3), stroke: 0.8pt + gray.darken(30%))

    circle((12.1, 2.2), radius: (0.50, 0.32), stroke: (dash: "dashed", paint: warn, thickness: 0.75pt))
    circle((12.1, 2.2), radius: 0.10, fill: warn, stroke: none)
    content((12.85, 2.20), frame: "rect", fill: white, stroke: none, padding: 0.04, text(size: 7.3pt, weight: "bold", fill: warn)[$bar(v)^* (bold(Q)_1 + bold(Q)_2)$])

    // 框间流程箭头
    line((4.72, 2.5), (5.08, 2.5), mark: (end: ">"), stroke: 0.9pt + accent)
    line((9.52, 2.5), (9.88, 2.5), mark: (end: ">"), stroke: 0.9pt + accent2)
  })),
  caption: [基于二次误差度量（QEM）的边坍缩简化流程。边 $(v_1, v_2)$ 坍缩为新顶点 $bar(v)^*$ 时，上下两个共享三角形退化消除（面片数减少 2），新顶点继承二次矩阵之和 $bold(Q)_1 + bold(Q)_2$ 并自动贴合多个关联切平面的交线以保留几何特征。],
) <fig:ch08-qem-collapse>

#figure(
  table(
    columns: (2.6cm, 2.2cm, 3.2cm, 3.2cm, 2.8cm),
    align: (left, center, left, left, left),
    [网格处理算子], [拓扑变化], [核心数学机制], [连续性 / 保特征性质], [典型时间复杂度],
    [隐式拉普拉斯平滑], [拓扑不变 \ （$V, E, F$ 恒定）], [求解 $(bold(M) - lambda bold(W)) bold(X)^(k+1) = bold(M) bold(X)^k$ 滤除高频曲率法向分量], [抑制网格凹凸噪声；过度迭代会导致体积收缩], [每步稀疏求解 $O(V)$ 至 $O(V^(1.5))$],
    [Loop 细分 \ @loop1987smooth], [三角形 1-to-4 \ （$F <- 4 F$）], [四次箱式样条掩模（边点 $3/8, 1/8$；顶点按度数 $beta$ 加权）], [正则点（$n=6$）$C^2$ 连续；奇异点（$n!=6$）$C^1$ 连续], [每轮细分严格线性 $O(F)$],
    [Catmull-Clark 细分 \ @catmull1978recursively], [任意多边形四边形化 \ （$F <- sum k_i$）], [双三次均匀 B 样条推广（面点、边点、原顶点三步更新）], [正则点（$n=4$）$C^2$ 连续；奇异点数自第 1 轮起恒定且 $C^1$], [每轮细分严格线性 $O(F)$],
    [QEM 边坍缩简化 \ @garland1997surface], [每次坍缩减 2 面 \ （$F <- F - 2$）], [累加平面二次矩阵 $bold(Q) = sum bold(p) bold(p)^top$，最小堆贪心坍缩], [新顶点自动落回切平面交线，强力保留折痕与尖角], [建堆加 $K$ 次坍缩 $O(E log E)$],
  ),
  caption: [多边形网格四大经典几何处理算子的拓扑演化、数学核与计算特性总结。],
) <tab:ch08-mesh-ops>

@fig:ch08-qem-collapse 与 @tab:ch08-mesh-ops 汇总了网格平滑、细分与简化的完整闭环：无论网格如何增删顶点，半边数据结构与局部微分/二次算子始终是支撑其高效演化的底层引擎。

== 现代演进：谱几何处理与自回归神经网格生成（MeshGPT） <sec:ch08-frontier>

进入几何深度学习与三维大模型时代，离散网格处理沿着「内蕴谱分析」与「离散 Token 自回归生成」两条主线发生深刻演进：

- 【已有成果】*拉普拉斯谱几何处理（Spectral Geometry Processing）与内蕴神经算子*：求解广义特征值问题 $bold(W) bold(phi)_k = - lambda_k bold(M) bold(phi)_k$（$0 = lambda_0 <= lambda_1 <= dots$），其特征向量 ${bold(phi)_k}$ 构成曲面流形上的正交 *傅里叶谐波基（Laplace-Beltrami Eigenfunctions）*@crane2013digital。由于余切矩阵 $bold(W)$ 与质量矩阵 $bold(M)$ 仅取决于曲面的内蕴度量（第一基本形式），谱基函数在等距非刚性形变（如人体姿态变化）下保持完全不变！现代内蕴网格神经网络（如 DiffusionNet）直接利用热核扩散算子 $exp(- t Delta_M)$ 在表面上传播特征，彻底摆脱了对特定三角形剖分方式的过拟合。
- 【已有成果】*自回归神经网格生成（MeshGPT 与艺术级布线拓扑）*：第 7 章讨论的神经 SDF 经 Marching Cubes 提取的网格往往呈现密集、杂乱的各向同性碎三角形，与人类三维美术师手工建模的紧凑、顺应特征流向（Edge Flow）的拓扑布线格格不入。Siddiqui 等人于 2024 年提出的 *MeshGPT*@siddiqui2024meshgpt 开创了直接生成显式网格的新范式：先通过图卷积与残差向量量化（RQ-VAE）将网格三角形编码为离散几何词表（Geometry Tokens），再训练解码器架构的 Transformer 按空间字典序*自回归预测下一个三角形的词元序列*。这种方式直接学习了人类建模师的切角、平面大三角与锐利折痕分布，一步生成无需后处理减面的紧凑艺术家级网格@siddiqui2024meshgpt。
- 【本书推断】*工业级神经网格生成的规模化与四边化趋势*：2024–2026 年相继涌现的 MeshAnything、EdgeRunner 与 BPT（Blocked and Patchified Tokenization）将自回归网格生成的面片上限从数百面推升至数万面，并引入半边游走编码将每三角形 Token 数压缩 50% 以上。展望未来，结合 Catmull-Clark 细分先验与可微 QEM 的*原生四边形神经网格生成*，将直接打通骨骼绑定动画（Rigging）与工业 CAD 边界表示（B-Rep）的最后一公里。

#keybox(title: [本章要点])[
  1. *二维流形与半边结构*：紧致可定向流形网格满足欧拉公式 $V - E + F = 2 - 2 g - b$ 及封闭三角网格比例律 $F approx 2 V, E approx 3 V$；半边结构通过配对半边 $h."twin"$ 与面内环绕指针 $h."next"$ 实现 $O(1)$ 的一环邻域遍历与局部拓扑重连。
  2. *离散微分几何基石*：余切 Laplace-Beltrami 算子 $(Delta_M f)_i = (1)/(2 A_i) sum (cot alpha_(i j) + cot beta_(i j))(f_j - f_i)$ 保持内蕴几何精度；其作用于顶点坐标直接给出平均曲率法向 $-2 H_i bold(n)_i$，而角亏高斯曲率 $K_i$ 严格满足离散 Gauss-Bonnet 定理 $sum_i A_i K_i = 2 pi chi(cal(M))$。
  3. *细分与简化对偶*：Loop 细分（三角形 1-to-4）与 Catmull-Clark 细分（任意多边形四边形化）在正则点达到 $C^2$ 连续、奇异点保持 $C^1$ 连续；QEM 网格简化通过累加平面二次矩阵 $bold(Q) = sum bold(p) bold(p)^top$ 与最小堆贪心边坍缩，在 $O(E log E)$ 时间内实现保特征减面。
  4. *谱方法与神经网格生成*：Laplace-Beltrami 特征基构成了流形上的等距不变傅里叶变换；以 MeshGPT 为代表的自回归模型将三角形序列化为离散 Token，实现了从「隐式场等值面提取」向「原生艺术家级显式网格生成」的跨越。
]
