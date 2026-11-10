#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 空间变换、齐次坐标与相机投影模型

计算机图形学的首要数学任务，是在不同局部参考系之间精确建立几何对象（点、方向向量、表面法线、切平面与协方差椭球）的代数变换法则，并最终将三维连续空间中的场景投射至二维离散像素平面 @marschner2021fundamentals @akenine2018realtime。无论是在经典实时光栅化管线中执行顶点着色，还是在神经辐射场（NeRF）与三维高斯泼溅（3DGS）@kerbl20233dgs 中对齐多视角相机位姿，空间变换与投影矩阵都是连接三维世界与二维图像的几何脊梁。

本章遵循全书统一的*右手坐标系（Right-Handed Coordinate System）*与*列向量左乘（$bold(p)' = bold(M) bold(p)$）*约定：先构建向量代数与正交标架（@sec:ch02-vectors），接着推导三维旋转的罗德里格斯（Rodrigues）公式与单位四元数插值（@sec:ch02-rotations），随后引入射影空间齐次坐标并严格证明法线逆转置变换法则（@sec:ch02-homogeneous），进而完整推导正交与透视投影矩阵及现代图形引擎标配的逆深度（Reversed-Z）浮点精度机制 @reed2015depth（@sec:ch02-projection），最后给出跨工业引擎与视觉重建框架的坐标系对齐矩阵（@sec:ch02-frontier）。

== 向量空间、内积外积与正交标架 <sec:ch02-vectors>

在三维欧几里得空间 $RR^3$ 中，我们严格区分两类基本几何实体：*向量（Vector）* $bold(v) in RR^3$ 描述带有方向与长度的自由位移，具有平移不变性；*点（Point）* $bold(p) in RR^3$ 描述空间中的绝对位置，只有选定坐标原点 $bold(o)$ 后才能等价于位置向量 $bold(p) - bold(o)$。两点的差 $bold(v) = bold(p)_2 - bold(p)_1$ 是一个向量，而两个点直接相加在仿射几何中并无意义（除非作为凸组合 $alpha bold(p)_1 + (1 - alpha) bold(p)_2$）。

=== 内积、外积与反对称叉积矩阵

给定标准正交基 ${bold(e)_x, bold(e)_y, bold(e)_z}$ 下的两个列向量 $bold(u) = (u_x, u_y, u_z)^top$ 与 $bold(v) = (v_x, v_y, v_z)^top$，其*欧氏内积（Dot Product）*定义为：
$ bold(u) dot bold(v) = bold(u)^top bold(v) = u_x v_x + u_y v_y + u_z v_z = norm(bold(u)) norm(bold(v)) cos theta, $ <eq:ch02-dot>
其中 $norm(bold(u)) = sqrt(bold(u)^top bold(u))$ 为欧氏范数，$theta in [0, pi]$ 为两向量夹角。在图形学中，内积承载三大核心计算：(i) 判定光线与表面法线的前后朝向（$bold(n) dot omega_i > 0$）；(ii) 计算 Lambert 漫反射余弦衰减项；(iii) 将向量 $bold(v)$ 分解为平行于单位向量 $hat(bold(u))$ 的正交投影分量 $bold(v)_parallel = (bold(v) dot hat(bold(u))) hat(bold(u))$ 与垂直分量 $bold(v)_perp = bold(v) - bold(v)_parallel$。

两个三维向量的*外积或叉积（Cross Product）* $bold(w) = bold(u) times bold(v)$ 生成一个同时正交于 $bold(u)$ 和 $bold(v)$ 的新向量，其方向遵循右手螺旋定则，模长等于二者张成的平行四边形面积 $norm(bold(u) times bold(v)) = norm(bold(u)) norm(bold(v)) sin theta$。为将叉积运算纳入矩阵线性代数框架，我们将向量 $bold(u)$ 映射为 $3 times 3$ *反对称矩阵（Skew-Symmetric Matrix）* $[bold(u)]_times in RR^(3 times 3)$：
$ bold(u) times bold(v) = [bold(u)]_times bold(v) = mat(0, -u_z, u_y; u_z, 0, -u_x; -u_y, u_x, 0) vec(v_x, v_y, v_z) = vec(u_y v_z - u_z v_y, u_z v_x - u_x v_z, u_x v_y - u_y v_x). $ <eq:ch02-cross>
反对称矩阵满足 $[bold(u)]_times^top = -[bold(u)]_times$，且对任意单位向量 $hat(bold(u)) in SS^2$，根据双重叉积恒等式 $hat(bold(u)) times (hat(bold(u)) times bold(v)) = (hat(bold(u)) dot bold(v)) hat(bold(u)) - bold(v)$，有极为重要的幂次约化性质：
$ [hat(bold(u))]_times^2 = hat(bold(u)) hat(bold(u))^top - bold(I)_3, quad [hat(bold(u))]_times^3 = -[hat(bold(u))]_times. $ <eq:ch02-skew-power>

=== 右手正交标架与 Gram-Schmidt 正交化

在局部着色（如法线贴图切空间 TBN）、相机位姿构造与刚体运动学中，我们需要频繁从单个主轴向量（如表面法线 $bold(n)$ 或相机视线方向 $bold(g)$）结合一个辅助参考向量 $bold(t)_"ref"$（通常取世界系上方向 $(0, 1, 0)^top$，共线时回退至 $(1, 0, 0)^top$）构造右手标准正交标架（Orthonormal Frame）${hat(bold(u)), hat(bold(v)), hat(bold(w))}$：
$ hat(bold(w)) = frac(bold(n), norm(bold(n))), quad hat(bold(u)) = frac(bold(t)_"ref" times hat(bold(w)), norm(bold(t)_"ref" times hat(bold(w)))), quad hat(bold(v)) = hat(bold(w)) times hat(bold(u)). $ <eq:ch02-frame>
以列向量拼接而成的基底矩阵 $bold(F) = mat(hat(bold(u)), hat(bold(v)), hat(bold(w))) in "SO"(3)$ 满足正交性 $bold(F)^top bold(F) = bold(I)_3$ 且 $det(bold(F)) = +1$。任意向量在局部标架下的坐标即为 $bold(p)_"local" = bold(F)^top bold(p)_"world"$，从局部标架变换回世界坐标系只需左乘 $bold(F)$。

== 线性变换、三维旋转（Rodrigues 公式与四元数）与仿射变换 <sec:ch02-rotations>

三维空间中的线性变换 $cal(T)(bold(v)) = bold(A) bold(v)$ 由矩阵 $bold(A) in RR^(3 times 3)$ 唯一确定，涵盖了非均匀缩放 $"diag"(s_x, s_y, s_z)$、错切（Shear）、镜像反射以及三维刚体旋转。其中，保持内积与右手定向不变的旋转矩阵构成特殊正交群 $"SO"(3) = { bold(R) in RR^(3 times 3) mid(|) bold(R)^top bold(R) = bold(I)_3, det(bold(R)) = 1 }$。

=== 轴角表示与 Rodrigues 旋转公式

根据欧拉旋转定理，三维空间中任意绕原点的刚体旋转均可等价表示为绕某一单位转轴 $hat(bold(u)) in SS^2$ 逆时针旋转角度 $theta in RR$。

#theorem(title: [罗德里格斯旋转公式（Rodrigues' Rotation Formula）])[
  设转轴为单位向量 $hat(bold(u)) = (u_x, u_y, u_z)^top in SS^2$，按右手定则绕 $hat(bold(u))$ 旋转角度 $theta$ 的线性变换矩阵 $bold(R)(hat(bold(u)), theta) in "SO"(3)$ 为：
  $ bold(R)(hat(bold(u)), theta) = cos theta bold(I)_3 + (1 - cos theta) hat(bold(u)) hat(bold(u))^top + sin theta [hat(bold(u))]_times. $ <eq:ch02-rodrigues>
]

#proof[
  对任意待旋转向量 $bold(v) in RR^3$，利用正交投影将其分解为平行于转轴的分量 $bold(v)_parallel$ 与正交于转轴的平面分量 $bold(v)_perp$：
  $ bold(v) = bold(v)_parallel + bold(v)_perp, quad bold(v)_parallel = (hat(bold(u)) dot bold(v)) hat(bold(u)) = (hat(bold(u)) hat(bold(u))^top) bold(v), quad bold(v)_perp = bold(v) - bold(v)_parallel = (bold(I)_3 - hat(bold(u)) hat(bold(u))^top) bold(v). $
  在绕轴 $hat(bold(u))$ 旋转过程中，轴向分量 $bold(v)_parallel$ 保持不变；正交分量 $bold(v)_perp$ 在垂直于 $hat(bold(u))$ 的二维平面内旋转角度 $theta$。构造该平面内与 $bold(v)_perp$ 正交且等长的向量 $bold(w) = hat(bold(u)) times bold(v)_perp = hat(bold(u)) times bold(v) = [hat(bold(u))]_times bold(v)$。在正交基 ${bold(v)_perp, bold(w)}$ 下，平面旋转结果为：
  $ bold(v)'_perp = cos theta bold(v)_perp + sin theta bold(w) = cos theta (bold(I)_3 - hat(bold(u)) hat(bold(u))^top) bold(v) + sin theta [hat(bold(u))]_times bold(v). $
  将旋转后的总向量 $bold(v)' = bold(v)_parallel + bold(v)'_perp$ 合并并提取公因式 $bold(v)$，即得 @eq:ch02-rodrigues。从李群与李代数视角看，利用 @eq:ch02-skew-power 对矩阵指数映射 $exp(theta [hat(bold(u))]_times) = sum_(k=0)^oo frac(theta^k, k!) [hat(bold(u))]_times^k$ 展开奇偶次幂，同样直接收敛至 @eq:ch02-rodrigues。
]

=== 欧拉角万向节死锁与单位四元数（Unit Quaternions）

在三维建模软件中，旋转常被拆解为绕三个坐标轴的级联欧拉角（如 $"Yaw-Pitch-Roll"$，即 $bold(R) = bold(R)_z (psi) bold(R)_y (theta) bold(R)_x (phi)$）。然而，当中间轴旋转角 $theta = plus.minus pi / 2$ 时，第一次旋转轴与第三次旋转轴在空间中重合，导致三自由度旋转退化为二自由度，系统丧失沿某一特定方向的瞬时旋转能力——这一奇异性称为*万向节死锁（Gimbal Lock）*。此外，对欧拉角直接做线性插值会导致角速度抖动与旋转路径扭曲。

为彻底消除万向节死锁并实现球面测地线平滑插值，Shoemake 于 1985 年将哈密顿*单位四元数（Unit Quaternions）*引入计算机图形学 @shoemake1985animating。四元数定义为包含一个实部标量 $q_w$ 与三个虚部向量 $bold(q)_v = (q_x, q_y, q_z)^top$ 的超复数 $bold(q) = q_w + q_x i + q_y j + q_z k = [q_w, bold(q)_v]$，虚数单位满足 $i^2 = j^2 = k^2 = i j k = -1$。绕单位轴 $hat(bold(u))$ 旋转角 $theta$ 对应的单位四元数 $bold(q) in HH_1$（满足 $norm(bold(q))^2 = q_w^2 + norm(bold(q)_v)^2 = 1$）编码为：
$ bold(q) = [cos frac(theta, 2), sin frac(theta, 2) hat(bold(u))]. $ <eq:ch02-quat>
将三维向量 $bold(v) in RR^3$ 提升为纯虚四元数 $tilde(bold(v)) = [0, bold(v)]$，则旋转作用等价于共轭夹乘运算 $tilde(bold(v))' = bold(q) circle.tiny tilde(bold(v)) circle.tiny bold(q)^(-1)$，其中单位四元数的逆即为其共轭 $bold(q)^(-1) = bold(q)^* = [q_w, -bold(q)_v]$。注意 $bold(q)$ 与 $-bold(q)$ 对应同一个三维旋转矩阵（$HH_1 approx "SU"(2)$ 对 $"SO"(3)$ 构成二重覆盖）。在骨骼动画与 3DGS 高斯椭球旋转协方差参数化 @kerbl20233dgs 中，给定两个姿态四元数 $bold(q)_0, bold(q)_1 in HH_1$（若 $bold(q)_0 dot bold(q)_1 < 0$ 先将 $bold(q)_1$ 取反以走最短弧），其*球面线性插值（SLERP）*公式 @shoemake1985animating 为：
$ "SLERP"(bold(q)_0, bold(q)_1; t) = frac(sin((1 - t) Omega), sin Omega) bold(q)_0 + frac(sin(t Omega), sin Omega) bold(q)_1, quad Omega = arccos(bold(q)_0 dot bold(q)_1), quad t in [0, 1]. $ <eq:ch02-slerp>

== 齐次坐标与模型—视图（Model-View）变换推导 <sec:ch02-homogeneous>

三维空间中的一般刚体或仿射变换包含线性变换矩阵 $bold(A) in RR^(3 times 3)$ 与平移向量 $bold(t) = (t_x, t_y, t_z)^top in RR^3$，即 $bold(p)' = bold(A) bold(p) + bold(t)$。由于平移项的存在，仿射变换在 $RR^3$ 中不是线性算子，无法将连续多次的“旋转 + 平移”合并为单个 $3 times 3$ 矩阵。

=== 射影空间齐次坐标与分块仿射矩阵

引入三维实射影空间 $PP^3$ 的*齐次坐标（Homogeneous Coordinates）*表示，将三维对象升维为四维列向量：
- *空间点（Point）*记为 $bold(p) = (x, y, z, 1)^top$（第 4 维权重 $w = 1$）；更一般地，对任意非零标量 $w != 0$，四元组 $(w x, w y, w z, w)^top$ 对应同一个欧氏三维点 $(x, y, z)^top$。
- *方向向量（Vector）*记为 $bold(v) = (v_x, v_y, v_z, 0)^top$（第 4 维权重 $w = 0$），代表射影空间无穷远超平面上的点，天然免疫平移变换。

在此表示下，$RR^3$ 中的仿射变换精确提升为 $RR^4$ 中的分块矩阵乘法：
$ vec(bold(p)', 1) = bold(M)_"affine" vec(bold(p), 1) = mat(bold(A), bold(t); bold(0)^top, 1) vec(bold(p), 1) = vec(bold(A) bold(p) + bold(t), 1), quad vec(bold(v)', 0) = mat(bold(A), bold(t); bold(0)^top, 1) vec(bold(v), 0) = vec(bold(A) bold(v), 0). $ <eq:ch02-homogeneous>
这种设计同时完美兼容了向量加减代数：两点之差 $(bold(p)_2, 1)^top - (bold(p)_1, 1)^top = (bold(p)_2 - bold(p)_1, 0)^top$ 自动变为 $w=0$ 的向量；点加向量 $(bold(p), 1)^top + (bold(v), 0)^top = (bold(p) + bold(v), 1)^top$ 仍为 $w=1$ 的点。

=== 表面法线的逆转置变换法则

当网格顶点经历模型变换 $bold(p)' = bold(M) bold(p)$ 时，若直接用左上角 $3 times 3$ 子矩阵 $bold(A)$ 乘以顶点法线 $bold(n)$，在存在非均匀缩放或错切时会导致变换后的法线不再垂直于切平面！

#proposition(title: [表面法线的协变/逆转置变换法则])[
  设三维光滑曲面在局部点处的切向量微元经历可逆线性变换 $bold(t)' = bold(A) bold(t)$（其中 $bold(A) in "GL"(3, RR)$ 为模型—视图矩阵左上角 $3 times 3$ 子矩阵）。为保持变换后法线向量 $bold(n)'$ 与切平面的正交关系 $bold(n)'^top bold(t)' = 0$，法线必须按 $bold(A)$ 的*逆转置矩阵（Inverse Transpose）*（或伴随矩阵 $"adj"(bold(A))^top$）变换：
  $ bold(n)' = frac((bold(A)^(-1))^top bold(n), norm((bold(A)^(-1))^top bold(n))). $ <eq:ch02-normal-matrix>
]

#proof[
  在变换前的局部空间中，表面单位法线 $bold(n)$ 与切平面内任意切向量 $bold(t)$ 正交，即内积满足矩阵乘法形式 $bold(n)^top bold(t) = 0$。由于切向量是由曲面上相邻两点相减得到的方向微元 $bold(t) = dif bold(p)$，经线性映射 $bold(A)$ 后，新的切向量为 $bold(t)' = bold(A) bold(t)$。我们在原正交条件中插入单位矩阵 $bold(I)_3 = bold(A)^(-1) bold(A)$：
  $ 0 = bold(n)^top bold(t) = bold(n)^top (bold(A)^(-1) bold(A)) bold(t) = (bold(n)^top bold(A)^(-1)) (bold(A) bold(t)) = ((bold(A)^(-1))^top bold(n))^top bold(t)'. $
  由此可见，向量 $tilde(bold(n))' = (bold(A)^(-1))^top bold(n)$ 与变换后的任意切向量 $bold(t)'$ 恒保持严格正交。进一步做单位化即可得到单位法线 $bold(n)'$。从微分几何角度看，切向量属于逆变向量（Contravariant Vector），而表面法线作为隐式函数梯度 $nabla phi$ 属于协变余向量（Covariant One-Form），二者在基底变换下的变换矩阵互为逆转置。特别地，若 $bold(A) = bold(R) in "SO"(3)$ 为纯旋转矩阵，因 $bold(R)^(-1) = bold(R)^top$，有 $(bold(R)^(-1))^top = bold(R)$，此时法线变换退化为与切向量一致的旋转矩阵。
]

=== 视图变换（View / LookAt Matrix）推导

在将所有物体通过各自的世界矩阵 $bold(M)_"model"$ 放置到统一的世界坐标系后，*视图变换（View Transformation）*将世界坐标系刚体变换至以相机光心（Eye Position）$bold(e) in RR^3$ 为原点、相机右方向为 $+hat(bold(u))$、上方向为 $+hat(bold(v))$、观察方向（Look-At Direction）$bold(g)$ 为 $-hat(bold(w))$（即相机看向局部 $-z$ 轴）的相机局部坐标系。给定光心 $bold(e)$、目标注视点 $bold(c)_"target"$ 与世界上方向 $bold(t)_"up"$，先按 @eq:ch02-frame 构造相机正交标架：
$ hat(bold(w)) = -frac(bold(g), norm(bold(g))) = frac(bold(e) - bold(c)_"target", norm(bold(e) - bold(c)_"target")), quad hat(bold(u)) = frac(bold(t)_"up" times hat(bold(w)), norm(bold(t)_"up" times hat(bold(w)))), quad hat(bold(v)) = hat(bold(w)) times hat(bold(u)). $ <eq:ch02-camera-axes>
视图矩阵 $bold(M)_"view"$ 是“相机到世界位姿矩阵 $bold(M)_"cam->world"$”的逆矩阵。等价地，它可分解为两步：第一步先用平移矩阵 $bold(T)(-bold(e))$ 将相机光心移至坐标原点，第二步用正交旋转矩阵 $bold(R)_"view"$ 的行向量将正交基 $(hat(bold(u)), hat(bold(v)), hat(bold(w)))$ 对齐至标准基底 $(bold(e)_x, bold(e)_y, bold(e)_z)$：
$ bold(M)_"view" = bold(R)_"view" bold(T)(-bold(e)) = mat(u_x, u_y, u_z, 0; v_x, v_y, v_z, 0; w_x, w_y, w_z, 0; 0, 0, 0, 1) mat(1, 0, 0, -e_x; 0, 1, 0, -e_y; 0, 0, 1, -e_z; 0, 0, 0, 1) = mat(hat(bold(u))^top, -hat(bold(u)) dot bold(e); hat(bold(v))^top, -hat(bold(v)) dot bold(e); hat(bold(w))^top, -hat(bold(w)) dot bold(e); bold(0)^top, 1). $ <eq:ch02-view>

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let bstyle = (radius: 0.12, fill: softbg, stroke: 0.85pt + accent)
    let pstyle = (radius: 0.12, fill: bluebg, stroke: 0.85pt + accent2)

    // 6 个坐标空间节点（分两排布局，清晰展示矩阵级联与透视除法）
    // 上排：局部空间 -> 世界空间 -> 相机/观察空间
    rect((0.2, 3.6), (3.6, 5.2), ..bstyle, name: "obj")
    content((1.9, 4.7), text(size: 8pt, weight: "bold")[局部模型空间])
    content((1.9, 4.1), text(size: 7.2pt)[Object Space $bold(p)_"obj" = (x,y,z,1)^top$])

    rect((5.1, 3.6), (8.5, 5.2), ..bstyle, name: "world")
    content((6.8, 4.7), text(size: 8pt, weight: "bold")[世界坐标空间])
    content((6.8, 4.1), text(size: 7.2pt)[World Space $bold(p)_"world"$])

    rect((10.0, 3.6), (13.6, 5.2), ..bstyle, name: "view")
    content((11.8, 4.7), text(size: 8pt, weight: "bold")[相机观察空间])
    content((11.8, 4.1), text(size: 7.2pt)[View Space $(x_e, y_e, z_e, 1)^top$])

    // 下排：裁剪空间 -> 归一化设备坐标 (NDC) -> 屏幕像素空间
    rect((10.0, 0.8), (13.6, 2.4), ..pstyle, name: "clip")
    content((11.8, 1.9), text(size: 8pt, weight: "bold", fill: accent2.darken(15%))[齐次裁剪空间])
    content((11.8, 1.3), text(size: 7.2pt)[Clip Space $(x_c, y_c, z_c, w_c)^top$])

    rect((5.1, 0.8), (8.5, 2.4), ..pstyle, name: "ndc")
    content((6.8, 1.9), text(size: 8pt, weight: "bold", fill: accent2.darken(15%))[归一化设备空间])
    content((6.8, 1.3), text(size: 7.2pt)[NDC $[-1,1]^2 times [0,1]$])

    rect((0.2, 0.8), (3.6, 2.4), ..pstyle, name: "screen")
    content((1.9, 1.9), text(size: 8pt, weight: "bold", fill: accent2.darken(15%))[屏幕像素与深度缓存])
    content((1.9, 1.3), text(size: 7.2pt)[Screen $[0,W] times [0,H]$])

    // 箭头与变换算子标注
    line((3.65, 4.4), (5.05, 4.4), mark: (end: ">"), stroke: 0.9pt + accent)
    content((4.35, 4.78), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt)[$bold(M)_"model"$])

    line((8.55, 4.4), (9.95, 4.4), mark: (end: ">"), stroke: 0.9pt + accent)
    content((9.25, 4.78), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt)[$bold(M)_"view"$])

    line((11.8, 3.55), (11.8, 2.45), mark: (end: ">"), stroke: 0.9pt + accent2)
    content((12.65, 3.0), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt)[$bold(M)_"proj"$])

    line((9.95, 1.6), (8.55, 1.6), mark: (end: ">"), stroke: 0.9pt + accent2)
    content((9.25, 2.02), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.0pt)[除以 $w_c = -z_e$])

    line((5.05, 1.6), (3.65, 1.6), mark: (end: ">"), stroke: 0.9pt + accent2)
    content((4.35, 2.02), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt)[$bold(M)_"viewport"$])
  })),
  caption: [计算机图形学标准空间坐标变换流水线。上排通过刚体/仿射矩阵 $bold(M)_"model"$ 与 $bold(M)_"view"$ 将顶点变换至相机局部坐标系；下排经投影矩阵 $bold(M)_"proj"$、透视除法（除以 $w_c$）与视口映射 $bold(M)_"viewport"$ 投射至屏幕像素坐标系。],
) <fig:ch02-pipeline>

@fig:ch02-pipeline 总结了从物体建模空间直达屏幕像素空间的完整六个阶段。其中前三步完全由线性矩阵乘法 $bold(M)_"MVP" = bold(M)_"proj" bold(M)_"view" bold(M)_"model"$ 合并执行，这正是齐次坐标在硬件流水线中的核心威力所在。

== 正交投影、透视投影矩阵与逆深度（Reversed-Z）精度分析 <sec:ch02-projection>

在相机观察空间中，视线沿 $-z$ 轴延伸。设近裁剪平面（Near Plane）与远裁剪平面（Far Plane）到光心的正距离分别为 $0 < n < f$，则在右手观察坐标系中，近、远平面的实际 $z$ 坐标分别为 $z_n = -n$ 与 $z_f = -f$。

=== 正交投影与透视挤压变换推导

*正交投影（Orthographic Projection）*将观察空间中的轴对齐长方体视景体 $[l, r] times [b, t] times [-f, -n]$ 线性平移并缩放为标准立方体（Canonical Cube，$[-1, 1]^3$）。由于右手系中 $z_e = -n$（近处）对应 $+1$ 或 $-1$ 存在 API 差异，按经典 OpenGL 标准（先映射到 $[-1, 1]^3$ 并翻转 $z$ 轴为左手 NDC 系，使近平面 $z_"ndc" = -1$、远平面 $z_"ndc" = +1$），正交投影矩阵为：
$ bold(M)_"ortho" = mat(frac(2, r - l), 0, 0, -frac(r + l, r - l); 0, frac(2, t - b), 0, -frac(t + b, t - b); 0, 0, -frac(2, f - n), -frac(f + n, f - n); 0, 0, 0, 1). $ <eq:ch02-ortho>

*透视投影（Perspective Projection）*模拟针孔相机成像规律（近大远小），其可视区域是一个被近平面 $z_e = -n$ 与远平面 $z_e = -f$ 截断的四棱台——*透视视锥体（View Frustum）*。根据相似三角形定理，观察空间点 $(x_e, y_e, z_e)$（其中 $z_e < 0$）投射到近平面 $z = -n$ 上的平面坐标为：
$ x_p = frac(n, -z_e) x_e, quad y_p = frac(n, -z_e) y_e. $ <eq:ch02-similar-triangle>
为了用 $4 times 4$ 齐次矩阵表达除以 $-z_e$ 的非线性运算，我们将透视投影分解为两步：$bold(M)_"persp" = bold(M)_"ortho" bold(M)_("persp" -> "ortho")$。其中“透视到正交挤压矩阵” $bold(M)_("persp" -> "ortho")$ 遵循三条几何不变量：(i) 近平面 $z_e = -n$ 上任意点的坐标保持严格不变；(ii) 远平面 $z_e = -f$ 上任意点的 $z$ 值保持不变（特别地，中心点 $(0, 0, -f, 1)^top$ 保持不变）；(iii) 齐次分量 $w_c$ 设为 $-z_e$，以便后续透视除法自动实现 @eq:ch02-similar-triangle。

据此，对任意点 $(x_e, y_e, z_e, 1)^top$，挤压后的齐次坐标应形如 $(-n x_e, -n y_e, A z_e + B, -z_e)^top$（或取正号 $(n x_e, n y_e, A z_e + B, -z_e)^top$）。按 $w_c = -z_e > 0$ 的标准正权重约定：
- 代入近平面 $z_e = -n$，要求挤压并除以 $w_c = n$ 后 $z' = -n$，故 $A (-n) + B = (-n) dot n = -n^2$；
- 代入远平面中心 $(0, 0, -f, 1)^top$，要求除以 $w_c = f$ 后 $z' = -f$，故 $A (-f) + B = (-f) dot f = -f^2$。

联立上述两个关于 $(A, B)$ 的线性方程，立即解得 $A = n + f$，$B = n f$！于是挤压矩阵（注意保持 $z_e = -n$ 时除以 $-z_e$ 得到 $-n$，第三行系数为 $-(n+f)$ 与 $-n f$）写为：
$ bold(M)_("persp" -> "ortho") = mat(n, 0, 0, 0; 0, n, 0, 0; 0, 0, -(n + f), -n f; 0, 0, -1, 0). $ <eq:ch02-squeeze>
将 @eq:ch02-ortho 与 @eq:ch02-squeeze 相乘（当视锥体对称时，设垂直视场角为 $"FOV"_y$、宽高比为 $a = W / H$，有 $t = n tan("FOV"_y / 2), b = -t, r = a t, l = -r$），即得经典对称透视投影矩阵：
$ bold(M)_"persp" = mat(frac(n, r), 0, 0, 0; 0, frac(n, t), 0, 0; 0, 0, -frac(f + n, f - n), -frac(2 f n, f - n); 0, 0, -1, 0) = mat(frac(cot("FOV"_y / 2), a), 0, 0, 0; 0, cot("FOV"_y / 2), 0, 0; 0, 0, -frac(f + n, f - n), -frac(2 f n, f - n); 0, 0, -1, 0). $ <eq:ch02-persp>

=== 非线性深度映射与逆深度（Reversed-Z）浮点精度分析

在现代图形 API（Vulkan、DirectX 12、Metal 与 WebGPU）中，NDC 空间的深度范围统一采用单侧区间 $z_"ndc" in [0, 1]$ 而非 $[-1, 1]$。设观测深度距离为正数 $d = -z_e in [n, f]$，将近平面 $d = n$ 映射为 $0$、远平面 $d = f$ 映射为 $1$ 的标准正向 $[0, 1]$ 深度函数为：
$ z_"std" (d) = frac(f, f - n) - frac(f n, (f - n) d) approx 1 - frac(n, d) quad (f >> n). $ <eq:ch02-z-std>
观察 @eq:ch02-z-std 可以发现一个严峻的数值缺陷：由于 $1 / d$ 的双曲线非线性特性，当 $d$ 从 $n$ 增加到 $2n$ 时，$z_"std"$ 已经消耗了 $[0, 0.5]$ 的一半区间；绝大部分远景（$d in [10n, f]$）被剧烈挤压在接近 $1.0$ 的狭窄区间内！而在 IEEE 754 32 位浮点数（FP32）表示中，浮点数由符号位、$8$ 位指数（Exponent）和 $23$ 位尾数（Mantissa）构成，其在接近 $0.0$ 处的指数可不断减小，分辨率极高；而在接近 $1.0$ 处指数固定为 $0$，最小可分辨间隔恒定为 $2^(-24) approx 5.96 times 10^(-8)$。这种“$1/d$ 挤压在 $1$ 附近”与“FP32 精度集中在 $0$ 附近”的错配，直接导致远距离表面发生严重的深度冲突闪烁（Z-Fighting）。

Reed 在其经典分析 @reed2015depth 中证明：只需将深度缓冲翻转，令*近平面 $d = n$ 映射为 $z_"rev" = 1$，远平面 $d = f$ 映射为 $z_"rev" = 0$*（即 *Reversed-Z 逆深度*），此时深度函数变为：
$ z_"rev" (d) = 1 - z_"std" (d) = frac(f n, (f - n) d) - frac(n, f - n) approx frac(n, d) quad (f -> oo). $ <eq:ch02-z-rev>
在 @eq:ch02-z-rev 中，随着距离 $d$ 增大，$n / d$ 趋向于 $0$ 的速度恰好与 FP32 浮点数在 $0$ 附近指数级加密的尾数精度相互抵消，从而在整个 $[n, oo)$ 视距范围内实现了近乎准均匀的对数深度分辨率！其对应的无穷远 Reversed-Z 透视矩阵极为简洁（第三行仅为 $(0, 0, 0, n)$）。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 左图：透视视锥体挤压为正交盒
    rect((0.2, 0.4), (6.5, 4.8), radius: 0.12, fill: softbg, stroke: 0.8pt + gray.lighten(20%))
    content((3.35, 4.45), text(size: 8pt, weight: "bold", fill: accent.darken(15%))[透视视锥体挤压 $bold(M)_("persp" -> "ortho")$])

    // 相机原点与视锥体边线
    circle((0.7, 2.4), radius: 0.08, fill: accent, stroke: none)
    content((0.7, 1.95), text(size: 7.2pt)[光心 $bold(e)$])
    line((0.7, 2.4), (3.5, 3.8), stroke: (dash: "dashed", paint: gray.darken(20%), thickness: 0.7pt))
    line((0.7, 2.4), (3.5, 1.0), stroke: (dash: "dashed", paint: gray.darken(20%), thickness: 0.7pt))

    // 梯形视锥体 (Near -> Far)
    line((1.7, 2.9), (3.5, 3.8), (3.5, 1.0), (1.7, 1.9), close: true, fill: bluebg, stroke: 0.9pt + accent)
    content((1.7, 1.5), text(size: 7pt)[$z=-n$])
    content((3.5, 0.68), text(size: 7pt)[$z=-f$])

    // 挤压箭头与右侧正交盒
    line((3.7, 2.4), (4.4, 2.4), mark: (end: ">"), stroke: 0.9pt + accent2)
    rect((4.6, 1.5), (6.2, 3.3), fill: bluebg, stroke: 0.9pt + accent2)
    content((5.4, 2.4), text(size: 7.2pt)[NDC 立方体])

    // 右图：Standard-Z vs Reversed-Z 曲线对比
    rect((7.0, 0.4), (13.8, 4.8), radius: 0.12, fill: softbg, stroke: 0.8pt + gray.lighten(20%))
    content((10.4, 4.45), text(size: 8pt, weight: "bold", fill: accent2.darken(15%))[深度映射曲线与 FP32 浮点精度分布])

    // 坐标轴
    line((7.8, 1.1), (13.3, 1.1), mark: (end: ">"), stroke: 0.8pt + ink)
    line((7.8, 1.1), (7.8, 4.0), mark: (end: ">"), stroke: 0.8pt + ink)
    content((12.7, 0.78), text(size: 7.2pt)[观察距离 $d = -z_e$])
    content((7.4, 3.85), text(size: 7.2pt)[$z_"ndc"$])
    content((7.5, 1.15), text(size: 7pt)[$0$])
    content((7.5, 3.55), text(size: 7pt)[$1$])

    // Standard-Z 曲线: 1 - n/d (上升趋近于1)
    bezier((8.1, 1.1), (13.0, 3.45), (8.6, 3.1), (10.5, 3.4), stroke: 1.1pt + warn)
    content((11.3, 3.72), text(size: 7.2pt, fill: warn.darken(10%))[标准正向 $z_"std" approx 1 - n / d$（远景挤在 $1$）])

    // Reversed-Z 曲线: n/d (下降趋近于0)
    bezier((8.1, 3.55), (13.0, 1.2), (8.6, 1.55), (10.5, 1.25), stroke: 1.1pt + accent)
    content((11.3, 1.62), text(size: 7.2pt, fill: accent.darken(15%))[逆深度 $z_"rev" approx n / d$（契合 $0$ 处高密度指数）])
  })),
  caption: [透视视锥体挤压变换（左）与标准深度 vs. Reversed-Z 逆深度曲线对比（右）。Reversed-Z 将远距离映射向 $0.0$，使 $n / d$ 的双曲衰减恰好与 IEEE 754 浮点数在 $0$ 附近的指数级高精度对齐 @reed2015depth。],
) <fig:ch02-frustum>

如 @fig:ch02-frustum 所示，Reversed-Z 配合 FP32 深度缓冲不仅无需额外显存开销，还将千米级大场景的远景有效深度尾数精度提升了数个数量级。下面给出完整的 MVP + 视口变换及 Reversed-Z 浮点分辨率对比的 Python（NumPy）验证代码：

```python
import numpy as np

def look_at_rh(eye: np.ndarray, target: np.ndarray, up: np.ndarray) -> np.ndarray:
    """构造右手坐标系相机视图矩阵 M_view (相机局部系看向 -z)"""
    w = eye - target
    w = w / np.linalg.norm(w)
    u = np.cross(up, w)
    u = u / np.linalg.norm(u)
    v = np.cross(w, u)
    M = np.eye(4, dtype=np.float64)
    M[0, :3], M[1, :3], M[2, :3] = u, v, w
    M[:3, 3] = -M[:3, :3] @ eye
    return M

def persp_reversed_z_infinite(fov_y_rad: float, aspect: float, near: float) -> np.ndarray:
    """构造无穷远平面 (f -> inf) 的 [0, 1] Reversed-Z 透视投影矩阵"""
    f_cot = 1.0 / np.tan(0.5 * fov_y_rad)
    return np.array([
        [f_cot / aspect, 0.0,   0.0,  0.0],
        [0.0,            f_cot, 0.0,  0.0],
        [0.0,            0.0,   0.0,  near],
        [0.0,            0.0,  -1.0,  0.0],
    ], dtype=np.float64)

# 验证远距离 (d = 5000m, near = 0.1m) 下 Standard-Z 与 Reversed-Z 的 FP32 最小可分辨深度间距
near, d_far = np.float32(0.1), np.float32(5000.0)
z_std = np.float32(1.0) - near / d_far
z_rev = near / d_far
# 利用 np.nextafter 测量单个 ULP (Unit in the Last Place) 对应的世界空间距离误差 (米)
d_std_next = near / (np.float32(1.0) - np.nextafter(z_std, np.float32(1.0)))
d_rev_next = near / np.nextafter(z_rev, np.float32(0.0))
# 输出结果: Standard-Z 最小可分辨间距约 14.9m (严重闪烁), 而 Reversed-Z 仅为 0.0003m!
```

== 现代演进与跨框架坐标系对齐 <sec:ch02-frontier>

在现代可微渲染与三维视觉工程实践中，最易引发隐蔽缺陷（Bug）的环节并非复杂的着色器方程，而是不同图形 API、物理仿真器与三维重建框架之间的*坐标系手性（Handedness）、相机朝向与 NDC 规范冲突*。例如，将 COLMAP 标定的相机位姿直接送入 OpenGL 或 PyTorch3D 管线会导致图像上下颠倒或前后翻转。

#figure(
  table(
    columns: (2.8cm, 1.8cm, 3.2cm, 2.5cm, 3.7cm),
    align: (left, center, left, center, left),
    [*框架 / 标准*], [*相机系手性*], [*相机局部轴朝向（右, 上, 前）*], [*NDC 深度范围*], [*向本书标准系（右 $+x$, 上 $+y$, 看向 $-z$）转换*],
    [本书 / 经典 OpenGL \ @marschner2021fundamentals], [右手系], [$+x$ 右，$+y$ 上，看向 $-z$], [$[-1, 1]$ \ （传统）], [基准参考系，转换矩阵为单位阵 $bold(I)_4$],
    [现代 Vulkan \ DirectX / WebGPU], [右手/左手], [Vulkan: $+x$ 右, $-y$ 上, $+z$ 前 \ DX: $+x$ 右, $+y$ 上, $+z$ 前], [$[0, 1]$ \ （支持 Reversed-Z）], [对相机系左乘 $"diag"(1, -1, -1, 1)$（Vulkan）并采用单侧深度投影],
    [COLMAP / OpenCV \ 3DGS @kerbl20233dgs], [右手系], [$+x$ 右，$-y$ 上（$+y$ 向下），看向 $+z$], [$[0, 1]$ \ （雅可比投影）], [对相机外参右乘轴翻转对角阵 $bold(C)_"flip" = "diag"(1, -1, -1, 1)$],
    [PyTorch3D], [右手系], [$-x$ 右（$+x$ 向左），$+y$ 上，看向 $+z$], [$[0, 1]$], [对相机局部系左乘 $"diag"(-1, 1, -1, 1)$ 以翻转 $x$ 与 $z$ 轴],
  ),
  caption: [主流图形学 API、计算机视觉标定工具与神经渲染框架的相机坐标系及 NDC 约定对比。跨系统传输相机外参矩阵 $bold(M)_"view"$ 时，必须通过正交翻转矩阵完成基底对齐。],
) <tab:ch02-conventions>

@tab:ch02-conventions 给出了四大主流体系的精确映射关系。特别地，设某相机在 COLMAP/3DGS 坐标系（$+x$ 右，$+y$ 下，$+z$ 前）下的“相机到世界”外参矩阵为 $bold(E)_"cv" = mat(bold(R)_"cv", bold(t)_"cv"; bold(0)^top, 1)$，将其无损转换为本书与 OpenGL 标准坐标系（$+x$ 右，$+y$ 上，看向 $-z$）下的相机外参矩阵 $bold(E)_"cg"$，只需在相机局部侧右乘对角翻转矩阵 $bold(D)_"flip" = "diag"(1, -1, -1, 1)$：
$ bold(E)_"cg" = bold(E)_"cv" bold(D)_"flip" = bold(E)_"cv" mat(1, 0, 0, 0; 0, -1, 0, 0; 0, 0, -1, 0; 0, 0, 0, 1), quad bold(M)_"view"^"cg" = bold(E)_"cg"^(-1) = bold(D)_"flip" bold(E)_"cv"^(-1). $ <eq:ch02-cv-to-cg>

结合近年来神经渲染与大场景引擎的技术进展，我们对空间变换与相机建模的前沿演进总结如下：
- 【已有成果】*Reversed-Z 与无穷远透视矩阵已成为实时渲染工业界绝对标准*：几乎所有现代商业游戏引擎（Unreal Engine 5、Unity HDRP）均默认采用 $[0, 1]$ Reversed-Z 配合 FP32 缓冲 @reed2015depth，彻底淘汰了传统 $[-1, 1]$ 线性映射。
- 【已有成果】*非针孔相机与李代数位姿优化的融合*：在 NeRF 与 3DGS 重建中，由于手持相机普遍存在广角径向畸变、鱼眼投影与卷帘快门（Rolling Shutter）效应，现代可微管线已将 $"SE"(3)$ 李代数切空间位姿梯度 $bold(xi) in frak("se")(3)$ 与局部雅可比仿射近似 $bold(J)$ 直接整合进光栅化内核 @kerbl20233dgs。
- 【本书推断】*64 位世界坐标（Large World Coordinates）与相机中心相对变换的普及*：在星球级数字孪生与自动驾驶仿真中，FP32 世界坐标在距离原点超过 $10 "km"$ 后会出现毫米级顶点抖动；将模型—视图变换重构为“CPU/双精度计算相对于相机原点的平移差 $Delta bold(p) = bold(p)_"world" - bold(e)$，再送入 GPU 执行 FP32 旋转投影”的相机相对渲染（Camera-Relative Rendering）架构，将成为所有大规模三维系统的基础规范。

#keybox(title: [本章要点])[
  1. *向量与旋转表示*：反对称矩阵 $[bold(u)]_times$ 将叉积转化为矩阵乘法；Rodrigues 公式给出了轴角到 $"SO"(3)$ 的解析映射；单位四元数 $bold(q) in HH_1$ 与 SLERP 消除了欧拉角万向节死锁并实现了测地线等速旋转插值。
  2. *齐次坐标与法线变换*：射影空间 $PP^3$ 将三维仿射变换统一为 $4 times 4$ 线性矩阵（点 $w=1$，方向向量 $w=0$）；为保持切平面正交性，表面法线必须按线性子矩阵的逆转置 $(bold(A)^(-1))^top$ 变换。
  3. *透视投影与 Reversed-Z*：透视投影本质是视锥体向正交盒的挤压变换 $bold(M)_("persp" -> "ortho")$ 加透视除法 $w_c = -z_e$；将近平面映射为 $1$、远平面映射为 $0$ 的 Reversed-Z 机制使 $n / d$ 非线性衰减完美契合 FP32 在 $0$ 附近的指数精度优势。
  4. *跨框架坐标系对齐*：在 OpenGL/本书标准系（$+x$ 右，$+y$ 上，看向 $-z$）与 COLMAP/3DGS 系（$+x$ 右，$+y$ 下，看向 $+z$）之间转换相机位姿，只需对局部轴施以对角矩阵 $"diag"(1, -1, -1, 1)$ 翻转。
]
