#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 计算机动画与物理仿真：从骨骼运动学到基于位置的动力学

前十章构建了静态场景的几何表征与光传输理论，而真实世界本质上是随时间演化的动态系统。计算机动画与物理仿真旨在赋予三维几何体随时间连续演化的运动规律。本章首先从运动学视角出发，建立骨骼层级树的正向与逆向运动学（@sec:ch11-kinematics）以及驱动表面网格形变的线性混合与双四元数蒙皮算法（@sec:ch11-skinning）；随后进入基于牛顿力学的动力学仿真，系统分析显式、隐式与半隐式（辛）欧拉时间积分器的谱稳定性与相空间体积守恒性质（@sec:ch11-integrators）；接着完整推导实时图形学中最具影响力的基于位置的动力学（PBD 与 XPBD）约束投影框架并给出数值实现（@sec:ch11-pbd）；最后探讨物质点法（MPM）、二阶 GPU 加速求解器与可微物理引擎等现代前沿（@sec:ch11-frontier）。

== 关键帧插值、骨骼层级与正逆向运动学（FK / IK） <sec:ch11-kinematics>

在角色与机械动画中，直接逐帧指定成千上万个网格顶点的空间轨迹既低效又难以保持刚体结构。工程上通常引入低维度的抽象骨架（Skeleton），将其组织为由关节（Joints）与骨骼段构成的树状层级结构。

=== 骨骼层级树与正向运动学（Forward Kinematics）

设骨骼层级树包含 $K$ 个关节，第 $i$ 个关节在其父关节局部坐标系下的刚体变换矩阵记为 $bold(T)_i^("local")(theta_i) in "SE"(3)$，其中 $theta_i$ 为该关节的局部旋转与平移参数（通常由关键帧样条曲线与球面线性插值 SLERP 求得）。*正向运动学（FK）*通过自根节点向叶节点的递归链式左乘，唯一确定每个关节在世界坐标系下的位姿矩阵：

$ bold(T)_i^("world") = bold(T)_("parent"(i))^("world") bold(T)_i^("local")(theta_i) = product_(k in cal(P)(i)) bold(T)_k^("local")(theta_k), $ <eq:ch11-fk>

其中 $cal(P)(i)$ 表示从根节点到关节 $i$ 的有向路径。FK 计算具备严格的 $O(K)$ 线性复杂度且解析唯一，但在交互式动画设计中，动画师往往希望直接拖拽末端执行器（End-Effector，如手掌或脚踝）到达目标空间位置 $bold(e)_("target") in RR^3$，由此引出逆向运动学问题。

=== 逆向运动学（Inverse Kinematics）：雅可比阻尼最小二乘与启发式迭代

设全骨架的关节自由度向量为 $bold(theta) = (theta_1, theta_2, dots, theta_M)^top in RR^M$，末端执行器的当前世界坐标为非线性映射 $bold(e) = bold(f)(bold(theta)) in RR^3$。*逆向运动学（IK）*旨在求解非线性方程 $bold(f)(bold(theta)) = bold(e)_("target")$。对该映射做一阶泰勒展开，可得微分运动关系 $Delta bold(e) approx bold(J)(bold(theta)) Delta bold(theta)$，其中雅可比矩阵定义为：

$ bold(J)(bold(theta)) = (partial bold(e))/(partial bold(theta)) in RR^(3 times M), quad bold(J)_j (bold(theta)) = bold(a)_j times (bold(e) - bold(p)_j), $ <eq:ch11-jacobian>

此处 $bold(p)_j$ 与 $bold(a)_j in SS^2$ 分别为第 $j$ 个旋转关节的世界中心位置与旋转轴方向。由于通常 $M > 3$（冗余自由度系统），且当机械臂完全伸直到达工作空间边界时 $bold(J) bold(J)^top$ 接近奇异，直接求伪逆会导致关节角速度剧烈震荡。工程上普遍采用 *Levenberg-Marquardt 阻尼最小二乘法（Damped Least-Squares, DLS）*，通过最小化目标函数 $norm(bold(J) Delta bold(theta) - Delta bold(e))_2^2 + lambda^2 norm(Delta bold(theta))_2^2$ 得到稳健更新步：

$ Delta bold(theta) = bold(J)^top (bold(J) bold(J)^top + lambda^2 bold(I)_3)^(-1) Delta bold(e), $ <eq:ch11-dls>

其中阻尼因子 $lambda > 0$ 确保矩阵对称正定，在奇异构型附近平滑衰减步长。除矩阵求逆法外，实时游戏引擎还广泛采用两类免矩阵求逆的启发式算法：*循环坐标下降法（CCD）*从最末端关节向根节点逐个旋转以对齐目标方向；*前向后向到达逆运动学（FABRIK）*则在笛卡尔空间直接交替拉拽关节点位置并投影回刚性骨长约束，兼具极高收敛速度与自然姿态保持能力。

== 骨骼蒙皮：线性混合蒙皮（LBS）与双四元数蒙皮（DQS） <sec:ch11-skinning>

骨骼运动确定后，需要将关节刚体变换平滑传递至角色表面的多边形网格顶点，这一过程称为*骨骼蒙皮（Skeletal Skinning）*。

=== 线性混合蒙皮（Linear Blend Skinning）与体积坍缩伪影

设网格在绑定姿态（Bind Pose / T-Pose）下的顶点静止坐标为 $bold(v) in RR^4$（齐次坐标），第 $j$ 个关节在绑定姿态下的世界矩阵为 $bold(B)_j in "SE"(3)$，当前动画帧的世界矩阵为 $bold(M)_j = bold(T)_j^("world") in "SE"(3)$。变换矩阵 $bold(C)_j = bold(M)_j bold(B)_j^(-1)$ 先将顶点从世界绑定空间变换回关节 $j$ 的局部空间，再随当前关节运动变换回世界空间。*线性混合蒙皮（LBS）*将受多个骨骼影响的变形后顶点位置 $bold(v)'$ 定义为各骨骼变换矩阵的凸组合：

$ bold(v)' = sum_(j=1)^K w_j bold(M)_j bold(B)_j^(-1) bold(v) = (sum_(j=1)^K w_j bold(C)_j) bold(v), quad sum_(j=1)^K w_j = 1, quad w_j >= 0. $ <eq:ch11-lbs>

LBS 仅需矩阵线性加权，极易在 GPU 顶点着色器中并行加速。然而其核心数学缺陷在于：*特殊欧氏群 $"SE"(3)$ 与特殊正交群 $"SO"(3)$ 对矩阵加法并不封闭*。例如，考虑肘部或手腕处受两个权重各为 $w_1 = w_2 = 0.5$ 的骨骼控制，若骨段 1 保持静止（$bold(R)_1 = bold(I)$），骨段 2 绕轴旋转 $180^circle.small$（$bold(R)_2 = "diag"(1, -1, -1)$），则混合后的线性矩阵为 $0.5 bold(I) + 0.5 bold(R)_2 = "diag"(1, 0, 0)$。此时该矩阵的秩退化为 1，截面上所有顶点坍缩至旋转轴线上的一点，产生著名的*「糖果包装纸」（Candy-Wrapper）扭曲坍缩伪影*。

=== 双四元数蒙皮（Dual Quaternion Skinning）

为从根本上消除体积坍缩，Kavan 等人提出了*双四元数蒙皮（DQS）*@kavan2008geometric，直接在刚体变换流形 $"SE"(3)$ 的覆盖群 $"Spin"(3) lt.closed RR^3$ 上执行插值。一个单位双四元数定义为 $hat(q) = bold(q)_0 + epsilon bold(q)_epsilon$，其中幂零元满足 $epsilon != 0$ 且 $epsilon^2 = 0$，实部 $bold(q)_0$ 为表示旋转的单位四元数（$norm(bold(q)_0) = 1$），偶部 $bold(q)_epsilon = frac(1, 2) bold(t) bold(q)_0$ 编码平移四元数 $bold(t) = (0, t_x, t_y, t_z)$。将每个骨骼的刚体变换 $bold(C)_j$ 转换为单位双四元数 $hat(q)_j$ 后，DQS 计算加权线性组合并做单位化投影（DLB）：

$ hat(b) = (sum_(j=1)^K w_j hat(q)_j) / (norm(sum_(j=1)^K w_j bold(q)_(0, j))), $ <eq:ch11-dqs>

其中必须确保相近骨骼的实部满足符号一致性 $bold(q)_(0, 1) dot bold(q)_(0, j) >= 0$ 以选取最短球面弧。由于单位化后的 $hat(b)$ 严格对应 $"SE"(3)$ 中的纯刚体螺旋变换，DQS 在任意大角度扭转下均能完美保持关节截面的刚性体积。

== 常微分方程时间积分：显式欧拉、半隐式（辛）欧拉与隐式欧拉 <sec:ch11-integrators>

当动画对象从预设动作的角色扩展到布料、毛发、流体与弹性软体时，必须求解牛顿第二定律支配的常微分方程组（ODE）：

$ bold(M) dot.double(bold(x)) = bold(f)(bold(x), dot(bold(x))), $ <eq:ch11-newton>

其中 $bold(M) in RR^(3N times 3N)$ 为对角质量矩阵，$bold(x), dot(bold(x)) in RR^(3N)$ 分别为广义坐标与速度，$bold(f)$ 汇总重力、弹簧内力与阻尼力。引入速度变量 $bold(v) = dot(bold(x))$，可将二阶系统降阶为一阶耦合系统：$dot(bold(x)) = bold(v)$，$dot(bold(v)) = bold(M)^(-1) bold(f)(bold(x), bold(v))$。数值仿真将时间轴离散化为步长 $Delta t$，从第 $n$ 步状态 $(bold(x)^n, bold(v)^n)$ 推进至 $(bold(x)^(n+1), bold(v)^(n+1))$。

#proposition(title: [三类一阶欧拉积分器的谱半径与相空间守恒性])[
考虑无阻尼一维简谐振子模型测试方程 $dot.double(x) = -omega^2 x$（固有角频率 $omega = sqrt(k / m)$），记状态向量 $bold(y)^n = (x^n, v^n)^top$，单步转移关系为 $bold(y)^(n+1) = bold(A) bold(y)^n$。三类欧拉积分器的稳定性特征如下：
1. *显式欧拉（Explicit / Forward Euler）*：$x^(n+1) = x^n + Delta t v^n$，$v^(n+1) = v^n - Delta t omega^2 x^n$。其放大矩阵特征值模长为 $abs(lambda) = sqrt(1 + (omega Delta t)^2) > 1$，对任意步长 $Delta t > 0$ *无条件不稳定*，系统机械能呈指数级爆炸。
2. *隐式欧拉（Implicit / Backward Euler）*：$x^(n+1) = x^n + Delta t v^(n+1)$，$v^(n+1) = v^n - Delta t omega^2 x^(n+1)$。特征值模长为 $abs(lambda) = 1 / sqrt(1 + (omega Delta t)^2) < 1$，对任意大步长 *无条件稳定*，但引入人为数值耗散（Numerical Damping），相空间轨迹向原点衰减。
3. *半隐式 / 辛欧拉（Symplectic Euler）*：先显式更新速度 $v^(n+1) = v^n - Delta t omega^2 x^n$，再以新速度更新位置 $x^(n+1) = x^n + Delta t v^(n+1)$。转移矩阵满足行列式 $det bold(A) = 1$（严格保持相空间面积），当 $omega Delta t < 2$ 时特征值满足 $abs(lambda) = 1$，系统能量在真实哈密顿量附近有界振荡而不发散。
]

#proof[
将三类更新格式写成矩阵形式 $bold(y)^(n+1) = bold(A) bold(y)^n$：
对显式欧拉，$bold(A)_("exp") = mat(1, Delta t; -omega^2 Delta t, 1)$，特征多项式为 $lambda^2 - 2 lambda + 1 + (omega Delta t)^2 = 0$，复特征根 $lambda = 1 plus.minus i omega Delta t$，故谱半径 $rho(bold(A)_("exp")) = sqrt(1 + (omega Delta t)^2) > 1$。
对隐式欧拉，$bold(A)_("imp") = mat(1, -Delta t; omega^2 Delta t, 1)^(-1)$，其特征值为 $(1 plus.minus i omega Delta t)^(-1)$，故 $rho(bold(A)_("imp")) = (1 + (omega Delta t)^2)^(-1/2) < 1$。
对半隐式（辛）欧拉，消去中间步骤可得 $bold(A)_("sym") = mat(1 - (omega Delta t)^2, Delta t; -omega^2 Delta t, 1)$。直接计算行列式得 $det bold(A)_("sym") = (1 - (omega Delta t)^2) + (omega Delta t)^2 = 1$，满足辛几何（Symplecticity）面积守恒条件。其特征方程为 $lambda^2 - (2 - (omega Delta t)^2) lambda + 1 = 0$；当 $0 < omega Delta t < 2$ 时，判别式 $Delta = (omega Delta t)^2 ((omega Delta t)^2 - 4) < 0$，共轭复根模长平方恰等于常数项 $det bold(A)_("sym") = 1$，故 $abs(lambda) = 1$。
]

对于一般非线性力场 $bold(f)(bold(x), bold(v))$，Baraff 与 Witkin 在开创性的布料仿真工作中引入了隐式欧拉线性化求解器@baraff1998large。对时刻 $n+1$ 的力做一阶泰勒展开 $bold(f)(bold(x)^n + Delta t bold(v)^(n+1)) approx bold(f)(bold(x)^n) + Delta t frac(partial bold(f), partial bold(x)) bold(v)^(n+1)$，记速度增量 $Delta bold(v) = bold(v)^(n+1) - bold(v)^n$，可导出对称正定稀疏线性方程组：

$ (bold(M) - Delta t^2 (partial bold(f))/(partial bold(x))) Delta bold(v) = Delta t (bold(f)(bold(x)^n) + Delta t (partial bold(f))/(partial bold(x)) bold(v)^n), $ <eq:ch11-implicit>

该方程可通过预条件共轭梯度法（PCG）高效求解，使高刚度布料在大时间步长下依然保持绝对稳定。@fig:ch11-phase-space 直观对比了三类欧拉积分器在简谐振子相空间 $(x, v)$ 中的演化轨迹。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 左侧：相空间轨迹图
    rect((0.2, 0.3), (7.8, 5.5), fill: softbg, stroke: 0.7pt + softline, radius: 0.12)
    content((4.0, 5.15), text(size: 8pt, weight: "bold")[简谐振子相空间 $(x, v)$ 演化轨迹对比])
    // 坐标轴
    line((0.8, 2.7), (7.2, 2.7), mark: (end: ">"), stroke: 0.8pt + ink)
    line((4.0, 0.6), (4.0, 4.8), mark: (end: ">"), stroke: 0.8pt + ink)
    content((7.0, 2.4), text(size: 7.5pt)[$x$])
    content((4.3, 4.65), text(size: 7.5pt)[$v$])
    // 辛欧拉：守恒椭圆轨道
    circle((4.0, 2.7), radius: (1.7, 1.25), stroke: 1.3pt + accent)
    // 显式欧拉：向外发散螺旋（折线近似）
    line((5.7, 2.7), (5.7, 3.6), (4.4, 4.2), (2.3, 3.8), (1.7, 1.9), (3.1, 0.8), (6.2, 1.2), (6.9, 3.5), mark: (end: ">"), stroke: (paint: warn, thickness: 1.0pt, dash: "dashed"))
    // 隐式欧拉：向内衰减螺旋
    line((5.7, 2.7), (5.2, 1.9), (4.1, 1.8), (3.2, 2.3), (3.4, 3.1), (4.1, 3.2), (4.5, 2.8), (4.15, 2.65), mark: (end: ">"), stroke: (paint: accent2, thickness: 1.0pt))
    // 起点标记
    circle((5.7, 2.7), radius: 0.08, fill: ink, stroke: none)
    content((6.25, 2.92), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7pt)[初值 $(x_0, 0)$])

    // 右侧：图例与谱性质总结盒
    rect((8.2, 3.8), (14.3, 5.4), fill: redbg, stroke: 0.9pt + warn, radius: 0.12)
    content((11.25, 4.95), text(size: 8pt, weight: "bold", fill: warn)[显式欧拉（红色虚线：向外发散）])
    content((11.25, 4.45), text(size: 7.5pt)[谱半径 $abs(lambda) = sqrt(1 + (omega Delta t)^2) > 1$])
    content((11.25, 4.02), text(size: 7.5pt)[相体积膨胀，机械能指数爆炸])

    rect((8.2, 2.05), (14.3, 3.65), fill: bluebg, stroke: 0.9pt + accent, radius: 0.12)
    content((11.25, 3.2), text(size: 8pt, weight: "bold", fill: accent.darken(15%))[半隐式 / 辛欧拉（青色实线：闭合轨道）])
    content((11.25, 2.7), text(size: 7.5pt)[$det bold(A) = 1$，当 $omega Delta t < 2$ 时 $abs(lambda) = 1$])
    content((11.25, 2.27), text(size: 7.5pt)[严格保持相空间面积，能量有界守恒])

    rect((8.2, 0.3), (14.3, 1.9), fill: softbg, stroke: 0.9pt + accent2, radius: 0.12)
    content((11.25, 1.45), text(size: 8pt, weight: "bold", fill: accent2.darken(15%))[隐式欧拉（棕色实线：向内收缩）])
    content((11.25, 0.95), text(size: 7.5pt)[谱半径 $abs(lambda) = 1 / sqrt(1 + (omega Delta t)^2) < 1$])
    content((11.25, 0.52), text(size: 7.5pt)[无条件稳定，含人为数值阻尼耗散])
  })),
  caption: [三类欧拉积分器在简谐振子相空间 $(x, v)$ 中的轨迹演化与谱稳定性对比。显式欧拉沿切线飞出等能面导致能量爆炸；隐式欧拉向内螺旋衰减；半隐式（辛）欧拉则严格保持相空间面积并在修正哈密顿等能面上稳定环绕。],
) <fig:ch11-phase-space>

== 质点弹簧系统与基于位置的动力学（PBD / XPBD）推导 <sec:ch11-pbd>

传统质点弹簧系统（Mass-Spring System）依据胡克定律计算弹力 $bold(f)_(i j) = -k (norm(bold(x)_i - bold(x)_j) - l_0) frac(bold(x)_i - bold(x)_j, norm(bold(x)_i - bold(x)_j))$ 并通过力积分推进位置，在处理不可伸长约束或自碰撞极易出现过冲（Overshooting）或昂贵的全局线性求解开销。

=== 位置约束流形投影（PBD）与柔度矩阵扩展（XPBD）

Müller 等人提出的*基于位置的动力学（Position Based Dynamics, PBD）*@muller2007position 彻底跳过了内力到加速度的二阶积分步骤，直接将粒子位置投影到非线性的几何约束流形 $C(bold(x)) = 0$（或不等式碰撞约束 $C(bold(x)) >= 0$）上。设各粒子的逆质量为 $w_i = 1 / m_i$，外力经半隐式预测得到试探位置 $tilde(bold(x))$。为在当前位置 $bold(x)$ 附近消去约束残差，PBD 对约束做一阶泰勒线性化：

$ C(bold(x) + Delta bold(x)) approx C(bold(x)) + nabla C(bold(x)) dot Delta bold(x) = 0. $ <eq:ch11-pbd-taylor>

为保持系统线动量与角动量守恒，位置修正量 $Delta bold(x)_i$ 必须限制在逆质量加权的约束梯度方向上，即 $Delta bold(x)_i = lambda w_i nabla_(bold(x)_i) C(bold(x))$。代入 @eq:ch11-pbd-taylor 解出拉格朗日乘子 $lambda$，即得单个约束的 *Gauss-Seidel 投影公式*：

$ Delta bold(x)_i = - (w_i C(bold(x))) / (sum_j w_j norm(nabla_(bold(x)_j) C(bold(x)))^2) nabla_(bold(x)_i) C(bold(x)). $ <eq:ch11-pbd-proj>

对于连接质点 $i, j$ 且原长为 $l_0$ 的距离约束 $C(bold(x)_i, bold(x)_j) = norm(bold(x)_i - bold(x)_j) - l_0$，其梯度为单位方向向量 $nabla_(bold(x)_i) C = bold(n)_(i j) = (bold(x)_i - bold(x)_j) / norm(bold(x)_i - bold(x)_j)$，$nabla_(bold(x)_j) C = -bold(n)_(i j)$，故分母化简为标量 $w_i + w_j$。

原始 PBD 的显著缺陷是：*模型表现出的等效刚度强烈依赖于 Gauss-Seidel 迭代次数与时间步长 $Delta t$*。为此，Macklin 等人提出了*扩展基于位置的动力学（XPBD）*@macklin2016xpbd，从弹性势能 $U(bold(x)) = frac(1, 2) bold(C)(bold(x))^top bold(alpha)^(-1) bold(C)(bold(x))$ 的隐式欧拉鞍点方程出发，引入时间步长缩放的*柔度（Compliance）参数* $tilde(alpha) = alpha / Delta t^2$（其中柔度 $alpha = 1 / k$ 为刚度的倒数）。在每次 Gauss-Seidel 迭代中，XPBD 追踪累积拉格朗日乘子 $lambda$ 并计算乘子增量：

$ Delta lambda = (-C(bold(x)) - tilde(alpha) lambda) / (sum_j w_j norm(nabla_(bold(x)_j) C(bold(x)))^2 + tilde(alpha)), quad lambda <- lambda + Delta lambda, quad Delta bold(x)_i = w_i Delta lambda nabla_(bold(x)_i) C(bold(x)). $ <eq:ch11-xpbd>

当柔度 $alpha -> 0$ 时，@eq:ch11-xpbd 退化为绝对刚性的原始 PBD 投影 @eq:ch11-pbd-proj；当 $alpha > 0$ 时，XPBD 给出了与步长 $Delta t$ 及迭代次数解耦的物理精确弹性响应。@fig:ch11-pbd-loop 展示了 XPBD 单个时间步的完整计算流水线，@tab:ch11-sim-methods 汇总了主流物理仿真方法的核心特性对比。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let bstyle = (radius: 0.12, fill: softbg, stroke: 0.9pt + accent)
    // 步骤 1：外力与位置预测
    rect((0.2, 1.5), (3.3, 3.6), ..bstyle)
    content((1.75, 3.15), text(size: 8pt, weight: "bold")[1. 辛欧拉位置预测])
    content((1.75, 2.5), text(size: 7.5pt)[$bold(v)^* = bold(v)^n + Delta t bold(M)^(-1) bold(f)_("ext")$])
    content((1.75, 1.95), text(size: 7.5pt)[$tilde(bold(x)) = bold(x)^n + Delta t bold(v)^*, quad lambda = 0$])

    // 步骤 2：Gauss-Seidel 约束投影循环
    rect((4.1, 1.1), (9.9, 4.0), fill: bluebg, stroke: 1.0pt + accent2, radius: 0.12)
    content((7.0, 3.6), text(size: 8pt, weight: "bold", fill: accent2.darken(15%))[2. XPBD 约束流形投影（迭代 $N_("iter")$ 次）])
    content((7.0, 2.95), text(size: 7.5pt)[对每个约束计算残差 $C(tilde(bold(x)))$ 与梯度 $nabla C$])
    content((7.0, 2.3), text(size: 7.5pt)[更新乘子：$Delta lambda = (-C - tilde(alpha) lambda) / (sum w_j norm(nabla_j C)^2 + tilde(alpha))$])
    content((7.0, 1.6), text(size: 7.5pt)[直接修正坐标：$tilde(bold(x))_i <- tilde(bold(x))_i + w_i Delta lambda nabla_i C$])

    // 步骤 3：确定位置与反算速度
    rect((10.7, 1.5), (14.3, 3.6), ..bstyle)
    content((12.5, 3.15), text(size: 8pt, weight: "bold")[3. 位置提交与速度更新])
    content((12.5, 2.5), text(size: 7.5pt)[$bold(x)^(n+1) = tilde(bold(x))$])
    content((12.5, 1.95), text(size: 7.5pt)[$bold(v)^(n+1) = (bold(x)^(n+1) - bold(x)^n) / Delta t$])

    // 正向箭头
    line((3.35, 2.55), (4.05, 2.55), mark: (end: ">"), stroke: 0.9pt + accent)
    line((9.95, 2.55), (10.65, 2.55), mark: (end: ">"), stroke: 0.9pt + accent)

    // 底部时间步闭环返回线
    line((12.5, 1.45), (12.5, 0.4), (1.75, 0.4), (1.75, 1.45), mark: (end: ">"), stroke: (paint: accent, thickness: 0.85pt, dash: "dashed"))
    content((7.0, 0.4), frame: "rect", fill: white, stroke: none, padding: 0.08, text(size: 7.5pt)[推进至下一时间步 $n <- n + 1$（碰撞响应与阻尼修正）])
  })),
  caption: [XPBD（扩展基于位置的动力学）单步仿真管线。算法先通过外力做辛欧拉试探步预测位置 $tilde(bold(x))$，再经多轮 Gauss-Seidel 迭代将顶点直接拉回柔度加权的约束流形，最后由位置差分直接导出完全相容的新速度 $bold(v)^(n+1)$。],
) <fig:ch11-pbd-loop>

#figure(
  table(
    columns: (2.6cm, 2.6cm, 2.5cm, 3.2cm, 3.3cm),
    align: (left, center, center, left, left),
    [仿真积分/方法], [时间步稳定性], [单步计算开销], [核心优势], [主要局限与适用场景],
    [显式欧拉积分], [极差（易爆炸）], [$O(N)$ 极低], [实现极简，免线性求解], [仅适用极小步长非刚性粒子],
    [半隐式（辛）欧拉], [条件稳定（$omega Delta t < 2$）], [$O(N)$ 极低], [保相空间面积，能量守恒好], [高刚度弹簧仍需微小子步],
    [隐式欧拉 @baraff1998large], [无条件稳定], [高（稀疏矩阵求逆）], [支持大步长高刚度布料], [数值耗散明显，自碰撞耦合难],
    [PBD / XPBD @macklin2016xpbd], [无条件稳定], [$O(N_("iter") M)$ 中等], [直接控制位置，碰撞投影极稳], [极高刚度下需子步加速收敛],
    [物质点法（MPM）@sulsky1995application], [CFL 条件/隐式稳定], [高（粒子—网格传输）], [自然处理大变形、断裂与相变], [内存带宽密集，适合雪/沙/软体],
  ),
  caption: [计算机图形学主流物理仿真与时间积分方法综合对比],
) <tab:ch11-sim-methods>

=== 算法实现：基于 NumPy 的 XPBD 柔体绳索/布料距离约束求解器

以下代码实现了带重力与固定锚点的 XPBD 柔体链条仿真器，严格对应 @eq:ch11-xpbd 的拉格朗日乘子累加与速度反算流程：

```python
import numpy as np

def step_xpbd_rope(x, v, inv_mass, edges, rest_len, compliance, dt, n_iters=15):
    """执行单步 XPBD 距离约束求解: x, v 形状为 (N, 3), inv_mass 形状为 (N,)"""
    g = np.array([0.0, -9.81, 0.0])
    # 1. 辛欧拉外力速度更新与试探位置预测 (被固定的锚点 inv_mass == 0 保持不动)
    v_pred = v + dt * (inv_mass[:, None] > 0) * g
    x_pred = x + dt * v_pred
    alpha_tilde = compliance / (dt * dt)
    lambdas = np.zeros(len(edges), dtype=np.float64)

    # 2. Gauss-Seidel 约束投影循环
    for _ in range(n_iters):
        for k, (i, j) in enumerate(edges):
            w_i, w_j = inv_mass[i], inv_mass[j]
            if w_i + w_j == 0.0:
                continue
            diff = x_pred[i] - x_pred[j]
            dist = np.linalg.norm(diff) + 1e-12
            C = dist - rest_len[k]                  # 距离约束残差 C(x)
            grad_i = diff / dist                    # 约束梯度 n_ij
            d_lambda = (-C - alpha_tilde * lambdas[k]) / (w_i + w_j + alpha_tilde)
            lambdas[k] += d_lambda
            x_pred[i] += w_i * d_lambda * grad_i
            x_pred[j] -= w_j * d_lambda * grad_i

    # 3. 由最终投影位置反算相容速度
    v_next = (x_pred - x) / dt
    return x_pred, v_next
```

== 连续介质与现代物理前沿：物质点法（MPM）、二阶加速与可微物理 <sec:ch11-frontier>

当仿真对象涉及剧烈拓扑变化（如冰雪崩塌、泥沙流动、弹性体撕裂与固液相变）时，纯拉格朗日网格会因单元严重扭曲而失效。

- *欧拉—拉格朗日混合物质点法（MPM）*：Sulsky 等人提出的物质点法（Material Point Method）@sulsky1995application 融合了拉格朗日粒子与欧拉背景网格的优势。每个时间步分为三个阶段：首先通过 B 样条核函数将粒子携带的质量、动量与形变梯度 $bold(F)_p$ 散射至规则背景网格节点（*P2G, Particle-to-Grid*）；随后在背景网格上无网格畸变地求解动量守恒方程并施加边界碰撞；最后将更新后的网格速度插值回粒子并平流粒子位置（*G2P, Grid-to-Particle*）【已有成果】。
- *GPU 二阶块坐标下降与极速收敛*：传统 XPBD 的一阶 Gauss-Seidel 迭代在处理高刚度材料与巨大质量比（如重球压在轻薄丝绸上）时收敛缓慢。Lan 等人提出的二阶模板下降法（Second-Order Stencil Descent）@lan2023second 与块坐标下降（Vertex Block Descent, VBD）直接在每个顶点的 $3 times 3$ 局部海森矩阵（Hessian）上做牛顿步求解，兼具二阶超线性收敛率与 GPU 极致并行度，实现了百万级顶点的实时高刚度仿真【已有成果】。
- *可微物理（Differentiable Physics）与梯度反传*：Hu 等人提出的 *DiffTaichi* 编译器@hu2020difftaichi 将前向物理仿真算子自动微分，通过伴随状态法（Adjoint Method）与检查点技术（Checkpointing）沿数千个时间步反向传播任务损失梯度 $nabla_theta cal(L)(bold(x)^T)$，使机器人控制器参数与软体驱动策略可通过基于梯度的优化在数十次迭代内快速收敛（比无梯度强化学习快数个数量级）【已有成果】。展望未来，将可微 MPM/XPBD 求解器与第 12–13 章的可微渲染器（NeRF / 3DGS）无缝级联，直接从多视角真实视频中联合反演物体的几何、外观材质与杨氏模量/摩擦系数等内禀物理属性，正成为具身智能「数字孪生世界模型」的核心支柱【本书推断】。

#keybox(title: [本章要点])[
1. *骨骼运动学与蒙皮*：正向运动学通过树状层级矩阵左乘求解世界位姿，逆向运动学利用阻尼最小二乘（DLS）避免奇异位姿震荡；双四元数蒙皮（DQS）在刚体流形上插值，彻底根除了线性混合蒙皮（LBS）的扭转体积坍缩伪影。
2. *ODE 时间积分谱性质*：显式欧拉谱半径恒大于 1（无条件发散）；隐式欧拉无条件稳定但引入数值阻尼；半隐式（辛）欧拉满足 $det bold(A) = 1$，在稳定域内严格保持相空间体积与长期能量守恒。
3. *XPBD 与现代物理前沿*：XPBD 将位置直接投影至约束流形并引入时间缩放柔度 $tilde(alpha) = alpha / Delta t^2$，实现了与步长及迭代次数无关的物理刚度；物质点法（MPM）、二阶 GPU 求解器与可微物理（DiffTaichi）则将物理仿真推向任意相变与梯度逆优化时代。
]
