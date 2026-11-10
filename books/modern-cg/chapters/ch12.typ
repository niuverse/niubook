#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 逆图形学、可微渲染与神经辐射场（NeRF）

本书前十一章构建了从三维参数（几何、材质、光源、相机与物理状态）生成二维像素图像的*正向图形学（Forward Graphics）*管线。然而在三维视觉重建、数字孪生资产生成与机器人场景理解中，核心需求往往相反：给定一组二维真实观测图像，如何逆向推演并重建出背后的三维几何、辐射场与材质参数？本章正式进入*逆图形学（Inverse Graphics）*与*神经渲染（Neural Rendering）*领域：首先剖析经典渲染管线不可微的数学根源与雷诺输运定理边界积分分解（@sec:ch12-partial-rendering）；随后介绍可微光栅化与可微路径追踪的工程解法（@sec:ch12-partial-methods）；接着从光学吸收—发射模型严格推导连续体渲染积分与天然可微的离散 Alpha 合成（@sec:ch12-volume-rendering）；在此基础上深入剖析神经辐射场（NeRF）的傅里叶位置编码与分层重要性采样机制（@sec:ch12-nerf）；最后探讨 Mip-NeRF 抗锯齿、Instant-NGP 多分辨率哈希编码与 NeuS 神经隐式表面重建等现代演进（@sec:ch12-frontier）。

== 逆图形学优化框架与可微渲染的梯度障碍 <sec:ch12-partial-rendering>

设三维场景由可优化参数向量 $theta in RR^D$（包含网格顶点坐标、BRDF 反射率、光源强度或神经网络权重）完整刻画，正向渲染器记为映射算子 $cal(R) : theta |-> cal(I)(theta)$。给定真实相机拍摄的参考图像 $cal(I)_("ref")$，逆图形学将其表述为最小化光度重投影损失（Photometric Loss）的优化问题：

$ theta^* = argmin_theta cal(L)(cal(R)(theta), cal(I)_("ref")). $ <eq:ch12-inv-opt>

要利用梯度下降或 Adam 优化器高效求解 @eq:ch12-inv-opt，必须由链式法则计算损失对场景参数的雅可比传导：

$ (partial cal(L))/(partial theta) = (partial cal(L))/(partial cal(I)) (partial cal(R)(theta))/(partial theta). $ <eq:ch12-chain>

然而，第 3–4 章所述的传统光栅化与第 9 章的光线投射管线中，包含两个破坏连续可微性的硬判决操作：*三角形边界覆盖测试*（Heaviside 阶跃函数 $H(E(bold(x); theta)) in {0, 1}$）与 *Z-Buffer 遮挡深度比较*（分段常值选择算子）。当对逐像素采样值直接调用自动微分（Autodiff）时，阶跃函数在边界外处处导数为零，在边界上导数为无穷大的狄拉克 $delta$ 脉冲，导致几何顶点坐标完全无法获得有效梯度信号。

#theorem(title: [像素积分的雷诺输运定理与边界不连续梯度分解])[
设单个像素的滤波积分域为 $Omega subset RR^2$，被积辐射亮度函数 $f(bold(x); theta)$ 在随参数 $theta$ 运动的几何剪影轮廓（Silhouette）或遮挡边界曲线 $Gamma(theta) subset Omega$ 两侧发生跳跃不连续，而在子区域内部处处光滑。记像素积分值为 $I(theta) = integral_Omega f(bold(x); theta) d bold(x)$，则其关于场景参数 $theta$ 的精确梯度分解为*内部光滑积分（Interior Integral）*与*边界曲线积分（Boundary Integral）*之和 @li2018differentiable：

$ nabla_theta I(theta) = integral_(Omega without Gamma(theta)) nabla_theta f(bold(x); theta) d bold(x) + integral_(Gamma(theta)) Delta f(bold(x)) (bold(n)_Gamma (bold(x)) dot (partial bold(x)_Gamma)/(partial theta)) d ell(bold(x)), $ <eq:ch12-reynolds>

其中 $bold(n)_Gamma$ 为边界曲线 $Gamma(theta)$ 在屏幕空间的向外单位法向量，$partial bold(x)_Gamma / partial theta$ 为边界点随场景参数 $theta$ 变化而产生的屏幕运动速度，跳跃量 $Delta f(bold(x)) = f_("in")(bold(x)) - f_("out")(bold(x))$ 为边界内侧（前景）与外侧（背景）的辐射亮度差。
]

#proof[
将像素区域按不连续边界 $Gamma(theta)$ 划分为互不相交的内部光滑子域 $Omega_1(theta)$ 与外部子域 $Omega_2(theta)$，使得 $I(theta) = integral_(Omega_1(theta)) f_1(bold(x); theta) d bold(x) + integral_(Omega_2(theta)) f_2(bold(x); theta) d bold(x)$。对具有含参动边界的区域积分应用二维雷诺输运定理（Reynolds Transport Theorem，即高维莱布尼茨积分法则）：

$ nabla_theta integral_(Omega_k (theta)) f_k (bold(x); theta) d bold(x) = integral_(Omega_k (theta)) nabla_theta f_k (bold(x); theta) d bold(x) + integral_(partial Omega_k (theta)) f_k (bold(x); theta) (bold(n)_k dot (partial bold(x))/(partial theta)) d ell(bold(x)). $

像素外框固定不随 $theta$ 移动（即像素外框上 $partial bold(x) / partial theta = bold(0)$），唯有公共分割边界 $Gamma(theta)$ 随参数运动，且两侧法向量相反（$bold(n)_1 = -bold(n)_2 = bold(n)_Gamma$）。将两区域梯度相加并合并 $Gamma(theta)$ 上的线积分项，即得 @eq:ch12-reynolds。
]

@eq:ch12-reynolds 揭示了逆图形学的核心机制：常规自动微分仅能捕获第一项内部积分（如材质颜色、光照强度的梯度），而*几何顶点位置与可见性变化的梯度完全蕴含在第二项边界线积分中*。@fig:ch12-boundary-grad 展示了硬光栅化的零梯度陷阱与两类可微近似策略。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 左栏：三角形跨越像素边界示意
    rect((0.2, 0.4), (4.6, 5.2), fill: softbg, stroke: 0.8pt + softline, radius: 0.12)
    content((2.4, 4.85), text(size: 8pt, weight: "bold")[1. 像素内的几何边界运动])
    // 像素网格框
    rect((0.9, 1.1), (3.9, 4.1), fill: white, stroke: 0.9pt + ink)
    // 三角形局部覆盖区域
    line((0.9, 1.1), (3.4, 1.1), (1.7, 4.1), (0.9, 4.1), close: true, fill: bluebg, stroke: none)
    line((3.4, 1.1), (1.7, 4.1), stroke: 1.4pt + accent)
    // 像素中心采样点
    circle((2.4, 2.6), radius: 0.08, fill: warn, stroke: none)
    content((2.95, 2.85), text(size: 7pt, fill: warn)[像素中心 $bold(x)_p$])
    // 边界法向速度箭头
    line((2.55, 2.6), (3.35, 3.05), mark: (end: ">"), stroke: 1.0pt + accent2)
    content((3.1, 3.45), frame: "rect", fill: white, stroke: none, padding: 0.04, text(size: 7pt, fill: accent2.darken(15%))[边界速度 $partial bold(x)_Gamma / partial theta$])
    content((2.4, 0.72), text(size: 7.2pt)[前景 $f_("in")$ 与背景 $f_("out")$ 在 $Gamma$ 跳变])

    // 中栏：硬阶跃函数与零梯度平台
    rect((4.9, 0.4), (9.5, 5.2), fill: redbg, stroke: 0.8pt + warn, radius: 0.12)
    content((7.2, 4.85), text(size: 8pt, weight: "bold", fill: warn)[2. 硬光栅化阶跃与零梯度平台])
    line((5.4, 1.5), (9.1, 1.5), mark: (end: ">"), stroke: 0.8pt + ink)
    line((7.2, 1.1), (7.2, 4.3), mark: (end: ">"), stroke: 0.8pt + ink)
    content((8.95, 1.22), text(size: 7pt)[边函数 $E$])
    // 阶跃曲线 H(E)
    line((5.5, 1.5), (7.2, 1.5), stroke: 1.4pt + warn)
    line((7.2, 1.5), (7.2, 3.7), stroke: (paint: warn, thickness: 1.0pt, dash: "dashed"))
    line((7.2, 3.7), (8.9, 3.7), stroke: 1.4pt + warn)
    content((6.3, 2.2), text(size: 7.2pt, fill: warn)[$partial H / partial E = 0$])
    content((8.1, 4.0), text(size: 7.2pt, fill: warn)[$partial H / partial E = 0$])
    content((7.2, 0.72), text(size: 7.2pt)[处处导数为 0，顶点无法移动])

    // 右栏：软光栅化 Sigmoid 与边界采样
    rect((9.8, 0.4), (14.4, 5.2), fill: bluebg, stroke: 0.8pt + accent, radius: 0.12)
    content((12.1, 4.85), text(size: 8pt, weight: "bold", fill: accent.darken(15%))[3. 软化松弛与显式边界采样])
    line((10.3, 1.5), (14.0, 1.5), mark: (end: ">"), stroke: 0.8pt + ink)
    line((12.1, 1.1), (12.1, 4.3), mark: (end: ">"), stroke: 0.8pt + ink)
    // Sigmoid 平滑近似曲线
    bezier((10.4, 1.55), (12.1, 2.6), (11.4, 1.55), (11.8, 2.1), stroke: 1.3pt + accent)
    bezier((12.1, 2.6), (13.8, 3.65), (12.4, 3.1), (12.8, 3.65), stroke: 1.3pt + accent)
    // 导数钟形曲线示意
    bezier((10.6, 1.5), (12.1, 3.9), (11.5, 1.5), (11.8, 3.9), stroke: (paint: accent2, thickness: 1.0pt, dash: "dashed"))
    bezier((12.1, 3.9), (13.6, 1.5), (12.4, 3.9), (12.7, 1.5), stroke: (paint: accent2, thickness: 1.0pt, dash: "dashed"))
    content((13.1, 2.3), text(size: 7pt, fill: accent.darken(15%))[软概率 $cal(D)_j$])
    content((11.2, 3.6), text(size: 7pt, fill: accent2.darken(15%))[非零梯度带])
    content((12.1, 0.72), text(size: 7.2pt)[SoftRas 平滑松弛 / Redner 边采样])
  })),
  caption: [三角形光栅化中的可见性不连续与可微渲染梯度恢复机制。（左）几何边界 $Gamma(theta)$ 扫过像素区域；（中）传统硬光栅化以阶跃函数 $H(E)$ 采样像素中心，导致梯度处处为零；（右）软光栅化将阶跃平滑为 Sigmoid 概率场，或由雷诺输运定理直接对边界线积分采样。],
) <fig:ch12-boundary-grad>

== 可微光栅化（SoftRas / Nvdiffrast）与可微路径追踪 <sec:ch12-partial-methods>

围绕如何高效计算或近似 @eq:ch12-reynolds 中的边界梯度，现代可微渲染形成了两大技术路线：*离散网格可微光栅化*与*基于物理的可微蒙特卡洛路径追踪*。

=== 概率软光栅化（SoftRas）与模块化抗锯齿光栅化（Nvdiffrast）

Liu 等人提出的 *Soft Rasterizer（SoftRas）*@liu2019softras 采用「前向算子平滑松弛」策略：放弃硬性的二值覆盖测试，将像素 $p$ 相对于三角形面片 $f_j$ 的覆盖关系定义为基于欧氏有向距离 $d(p, f_j)$ 的 Sigmoid 连续概率场：

$ cal(D)_j (p) = "sigmoid"(s_(p, j) dot (d^2(p, f_j)) / sigma), $ <eq:ch12-softras>

其中符号 $s_(p, j) in {+1, -1}$ 标识像素中心位于三角形内部或外部，温度超参数 $sigma > 0$ 控制边界模糊带宽；深度 Z-Buffer 亦替换为 Softmax 概率加权聚合。SoftRas 使被遮挡或远离目标位置的顶点也能接收到长程平滑梯度，但代价是前向渲染图像本身变得半透明模糊。

为兼具硬件光栅化的极速精确前向输出与边界可微性，Laine 等人提出了 *Nvdiffrast*@laine2020modular。Nvdiffrast 将硬件光栅化拆解为四个正交的可微原语算子：*光栅化（Rasterize）*、*重心插值（Interpolate）*、*纹理采样（Texture）*与*屏幕空间抗锯齿（Antialias）*。其前向过程直接调用 GPU 硬件光栅器生成精确像素结果，仅在最后的 `Antialias` 阶段检测具有材质或深度跳变的剪影轮廓边（Silhouette Edges），利用像素跨边的局部覆盖面积解析近似 @eq:ch12-reynolds 的边界线积分，从而在每秒数千帧的吞吐率下提供无偏边界梯度。

=== 边采样（Redner）与辐射反向传播（Mitsuba 2 / 3）

在需要全局光照、软阴影与多次弹射折射的物理渲染场景中，必须对第 9 章的渲染方程求导。Li 等人提出的 *Redner*@li2018differentiable 首次实现了无偏可微光线追踪：它在常规路径采样处理内部积分的同时，专门对三维网格的剪影轮廓边（Primary & Secondary Silhouette Edges）执行显式蒙特卡洛采样，严格估计 @eq:ch12-reynolds 中的边界线积分项。

当场景待优化参数维度 $D$ 极高（如百万级体素密度或高分辨率位移贴图）时，沿每条光线保存完整的自动微分计算图会耗尽 GPU 显存。Nimier-David 等人在 *Mitsuba 2*@nimier2019mitsuba 及后续的辐射反向传播（Radiative Backpropagation）理论中证明：损失梯度 $partial cal(L) / partial theta$ 在场景中的反向传播满足与正向辐射传输完全对偶的*伴随传输方程（Adjoint Light Transport）*。通过在反向阶段再次发射伴随光线（Adjoint Rays）动态重算中间辐射量，可将可微路径追踪的显存复杂度从 $O(N_("bounces"))$ 降至常数级 $O(1)$。

== 连续体渲染积分、透射率推导与离散 Alpha 合成 <sec:ch12-volume-rendering>

三角形网格在逆向重建中面临严峻的*拓扑障碍*：梯度下降只能微调已有顶点位置，极难自适应地改变网格亏格（Genus）、产生孔洞或表达烟雾、毛发等半透明结构。2020 年兴起的神经辐射场彻底抛弃了离散表面边界，转而将三维场景建模为充满空间的*连续光学吸收—发射体积场（Absorption-Emission Volume）*@max1995optical。

=== Max 光学体积衰减微分方程与连续体渲染积分

根据 Max 提出的经典体积光学模型@max1995optical，设三维空间中每一点 $bold(x) in RR^3$ 具有两个连续属性：*体密度（Volume Density / 消光系数）* $sigma(bold(x)) >= 0$，刻画光线穿过无穷小距离 $d t$ 时被微粒遮挡或散射的微分概率；以及沿观察方向 $bold(d) in SS^2$ 发射的*方向辐射颜色* $bold(c)(bold(x), bold(d)) in [0, 1]^3$。

考虑一条从相机光心 $bold(o)$ 沿单位方向 $bold(d)$ 发射的射线 $bold(r)(t) = bold(o) + t bold(d)$，行进区间为近远裁剪面 $[t_n, t_f]$。记*透射率（Transmittance）* $T(t)$ 为光子从起点 $t_n$ 传播到深度 $t$ 而不被任何粒子吸收的存活概率。在无穷小区间 $[t, t + d t]$ 内，透射率的相对衰减量正比于局部体密度：

$ d T(t) = -sigma(bold(r)(t)) T(t) d t quad ==> quad (d ln T(t))/(d t) = -sigma(bold(r)(t)). $ <eq:ch12-beer-ode>

在初值条件 $T(t_n) = 1$ 下对 @eq:ch12-beer-ode 积分，即得著名的*比尔—朗伯定律（Beer-Lambert Law）*：

$ T(t) = exp(-integral_(t_n)^t sigma(bold(r)(s)) d s). $ <eq:ch12-transmittance>

深度 $t$ 处的无穷小体元对相机贡献的期望颜色等于「光子存活到达 $t$ 的概率 $T(t)$」乘以「在 $d t$ 内发生碰撞发光的概率 $sigma(bold(r)(t)) d t$」再乘以「局部发射颜色 $bold(c)(bold(r)(t), bold(d))$」。沿整条射线积分，即得*连续体渲染方程（Volume Rendering Integral）*：

$ bold(C)(bold(r)) = integral_(t_n)^(t_f) T(t) sigma(bold(r)(t)) bold(c)(bold(r)(t), bold(d)) d t. $ <eq:ch12-vol-int>

=== 分段常值数值求积与离散 Alpha 合成推导

为在计算机中数值求解 @eq:ch12-vol-int，将射线区间 $[t_n, t_f]$ 划分为 $N$ 个采样段 $[t_i, t_(i+1)]$，段长记为 $delta_i = t_(i+1) - t_i$。假设在第 $i$ 段内体密度与颜色近似为常数 $sigma_i, bold(c)_i$，则到第 $i$ 段起点的累积透射率离散化为：

$ T_i = exp(-sum_(j=1)^(i-1) sigma_j delta_j) = product_(j=1)^(i-1) exp(-sigma_j delta_j). $ <eq:ch12-disc-t>

对第 $i$ 个子区间 $[t_i, t_(i+1)]$ 精确解析积分，注意到 $-sigma_i exp(-sigma_i (t - t_i))$ 的原函数恰为 $exp(-sigma_i (t - t_i))$：

$ integral_(t_i)^(t_(i+1)) T(t) sigma_i bold(c)_i d t = T_i bold(c)_i integral_0^(delta_i) sigma_i exp(-sigma_i s) d s = T_i (1 - exp(-sigma_i delta_i)) bold(c)_i. $ <eq:ch12-quad-step>

定义第 $i$ 个采样段的不透明度（Opacity）为 $alpha_i = 1 - exp(-sigma_i delta_i) in [0, 1)$，则有 $exp(-sigma_j delta_j) = 1 - alpha_j$。将其代回 @eq:ch12-disc-t 与 @eq:ch12-quad-step 并对全射线求和，即严格导出经典的前向后（Front-to-Back）*离散 Alpha 合成公式*：

$ hat(bold(C))(bold(r)) = sum_(i=1)^N T_i alpha_i bold(c)_i, quad "其中" quad alpha_i = 1 - exp(-sigma_i delta_i), quad T_i = product_(j=1)^(i-1) (1 - alpha_j). $ <eq:ch12-alpha-comp>

#remark(title: [为什么体渲染天然克服了边界不可微障碍？])[
对比 @eq:ch12-reynolds 与 @eq:ch12-alpha-comp 可以看出：在体渲染框架下，空间采样点坐标 $bold(r)(t_i)$ 由固定相机射线决定，而物体的「存在性」与「几何表面」被编码为连续实数值密度 $sigma_i in [0, infinity)$。由于指数函数 $exp(-sigma_i delta_i)$ 与乘积加权和关于每个 $(sigma_i, bold(c)_i)$ 均是*无穷阶光滑（$C^infinity$）解析可微*的，无需任何复杂的剪影边采样，仅靠标准反向传播即可端到端地从空无一物的均匀密度场中「凝聚」出任意拓扑的三维几何！
]

== 神经辐射场（NeRF）：高频位置编码、分层体积采样与光度重建 <sec:ch12-nerf>

Mildenhall 等人在 ECCV 2020 提出的*神经辐射场（Neural Radiance Fields, NeRF）*@mildenhall2020nerf 将上述可微体渲染推向了照片级新视角合成的巅峰。NeRF 不使用显式三维体素网格存储场景（以免遭受 $O(N^3)$ 立方显存爆炸），而是用一个紧凑的多层感知机（MLP）$F_Theta$ 隐式拟合连续的 5D 辐射场：

$ F_Theta : (gamma(bold(x)), gamma(bold(d))) |-> (sigma(bold(x)), bold(c)(bold(x), bold(d))), $ <eq:ch12-nerf-mlp>

其中网络架构施加了一个关键的物理归纳偏置：*体密度 $sigma$ 仅由空间坐标 $bold(x)$ 决定（确保多视角几何一致性），而发射颜色 $bold(c)$ 同时依赖空间坐标 $bold(x)$ 与观察方向 $bold(d)$（从而能够拟合第 10 章所述的微表面高光等视角相关非朗伯外观）*。

=== 神经网络谱偏置与傅里叶高频位置编码

若直接将三维笛卡尔坐标 $bold(x) = (x, y, z) in [-1, 1]^3$ 输入标准 ReLU MLP，重建出的渲染图像会严重丢失高频纹理与锐利几何边缘，呈现过度平滑的模糊伪影。Tancik 等人从神经正切核（Neural Tangent Kernel, NTK）谱分析理论证明@tancik2020fourier：标准 MLP 在训练过程中存在显著的*低频谱偏置（Spectral Bias）*——对应较大特征值的低频分量收敛极快，而高频分量特征值呈指数衰减，难以在有限步内拟合。

为克服谱偏置，NeRF 在进入 MLP 前引入确定性的*傅里叶位置编码（Positional Encoding）*映射 $gamma : RR -> RR^(2L)$，将标量坐标提升至多尺度三角函数基空间：

$ gamma(p) = (sin(2^0 pi p), cos(2^0 pi p), sin(2^1 pi p), cos(2^1 pi p), dots, sin(2^(L-1) pi p), cos(2^(L-1) pi p)). $ <eq:ch12-pos-enc>

对空间位置 $bold(x)$ 各分量取 $L = 10$（最高频率 $2^9 pi$）以捕获精细几何与纹理，对视角方向 $bold(d)$ 取较低的 $L = 4$ 以保证高光随视角平滑过渡。

=== 粗到细（Coarse-to-Fine）分层逆变换重要性采样

真实场景中绝大多数三维空间是空气（$sigma = 0$），唯有靠近物体薄表面处的极窄区间对积分 @eq:ch12-alpha-comp 有贡献。为此，NeRF 结合第 9 章的蒙特卡洛逆变换采样思想，设计了两级分层采样策略：
1. *粗网络（Coarse Network）分层均匀采样*：将射线 $[t_n, t_f]$ 等分为 $N_c = 64$ 个区间，在每个区间内均匀随机抖动采样一点 $t_i$，评估粗网络得到权重 $w_i = T_i alpha_i$。
2. *细网络（Fine Network）逆 CDF 重要性采样*：将归一化权重 $hat(w)_i = w_i / sum_j w_j$ 视为沿射线的分段常值概率密度函数（PDF），构造其累积分布函数（CDF）并执行逆变换采样，在权重高峰（即物体真实表面）附近密集增补 $N_f = 128$ 个采样点，合并 $N_c + N_f$ 个点共同评估细网络。

训练时，同时最小化粗网络与细网络合成颜色与真实像素颜色 $bold(C)_("gt")(bold(r))$ 之间的 $L_2$ 光度均方误差损失：

$ cal(L)_("NeRF") = sum_(bold(r) in cal(R)_("batch")) (norm(hat(bold(C))_c (bold(r)) - bold(C)_("gt")(bold(r)))_2^2 + norm(hat(bold(C))_f (bold(r)) - bold(C)_("gt")(bold(r)))_2^2). $ <eq:ch12-nerf-loss>

@fig:ch12-nerf-pipeline 给出了 NeRF 从相机射线采样到光度损失反向传播的端到端计算架构。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let bstyle = (radius: 0.12, fill: softbg, stroke: 0.9pt + accent)
    // 1. 射线采样
    rect((0.2, 1.5), (3.0, 3.8), ..bstyle)
    content((1.6, 3.35), text(size: 8pt, weight: "bold")[1. 相机射线采样])
    content((1.6, 2.65), text(size: 7.5pt)[$bold(r)(t_i) = bold(o) + t_i bold(d)$])
    content((1.6, 2.0), text(size: 7.2pt)[分层采样 + 逆 CDF])

    // 2. 傅里叶位置编码
    rect((3.6, 1.5), (6.3, 3.8), ..bstyle)
    content((4.95, 3.35), text(size: 8pt, weight: "bold")[2. 高频位置编码])
    content((4.95, 2.65), text(size: 7.5pt)[$gamma(bold(x)) in RR^(60)$])
    content((4.95, 2.0), text(size: 7.5pt)[$gamma(bold(d)) in RR^(24)$])

    // 3. MLP 辐射场网络
    rect((6.9, 1.5), (9.7, 3.8), fill: bluebg, stroke: 0.9pt + accent2, radius: 0.12)
    content((8.3, 3.35), text(size: 8pt, weight: "bold", fill: accent2.darken(15%))[3. MLP 隐式场 $F_Theta$])
    content((8.3, 2.65), text(size: 7.5pt)[8 层全连接 (256 维)])
    content((8.3, 2.0), text(size: 7.5pt)[输出 $(sigma_i, bold(c)_i)$])

    // 4. 可微体渲染合成
    rect((10.3, 1.5), (14.3, 3.8), ..bstyle)
    content((12.3, 3.35), text(size: 8pt, weight: "bold")[4. 可微 Alpha 体合成])
    content((12.3, 2.65), text(size: 7.5pt)[$alpha_i = 1 - exp(-sigma_i delta_i)$])
    content((12.3, 2.0), text(size: 7.5pt)[$hat(bold(C))(bold(r)) = sum_(i=1)^N T_i alpha_i bold(c)_i$])

    // 前向箭头
    line((3.05, 2.65), (3.55, 2.65), mark: (end: ">"), stroke: 0.9pt + accent)
    line((6.35, 2.65), (6.85, 2.65), mark: (end: ">"), stroke: 0.9pt + accent)
    line((9.75, 2.65), (10.25, 2.65), mark: (end: ">"), stroke: 0.9pt + accent)

    // 底部反向传播闭环
    rect((4.8, 0.2), (11.8, 1.0), fill: redbg, stroke: 0.8pt + warn, radius: 0.1)
    content((8.3, 0.6), text(size: 7.5pt, weight: "bold", fill: warn)[5. 光度重建损失 $cal(L)_("MSE") = norm(hat(bold(C))(bold(r)) - bold(C)_("gt")(bold(r)))_2^2$ 反向传播更新权重 $Theta$])
    line((12.3, 1.45), (12.3, 0.6), (11.85, 0.6), mark: (end: ">"), stroke: (paint: warn, thickness: 0.9pt, dash: "dashed"))
    line((4.75, 0.6), (8.3, 0.6), (8.3, 1.45), mark: (end: ">"), stroke: (paint: warn, thickness: 0.9pt, dash: "dashed"))
  })),
  caption: [神经辐射场（NeRF）端到端前向可微渲染与反向训练流水线。空间采样点经高频傅里叶位置编码后送入 MLP 预测密度与视角相关颜色，再经天然可微的分段常值体积求积合成像素颜色，由 2D 光度损失直接驱动 3D 隐式场收敛。],
) <fig:ch12-nerf-pipeline>

=== 算法实现：基于 PyTorch 的傅里叶编码与可微体积渲染算子

以下 PyTorch 代码实现了 NeRF 的高频位置编码与离散体积求积合成算子（支持自动微分反向传播）：

```python
import torch

def positional_encoding(x: torch.Tensor, L: int = 10) -> torch.Tensor:
    """计算输入坐标 x (..., D) 的 L 阶傅里叶高频位置编码"""
    freqs = (2.0 ** torch.arange(L, device=x.device, dtype=x.dtype)) * torch.pi
    scaled = x.unsqueeze(-1) * freqs                        # 形状: (..., D, L)
    enc = torch.cat([torch.sin(scaled), torch.cos(scaled)], dim=-1)
    return torch.cat([x, enc.flatten(-2)], dim=-1)          # 拼接原始坐标与高频基

def volume_render_radiance(sigmas: torch.Tensor, rgbs: torch.Tensor, z_vals: torch.Tensor):
    """可微体渲染求积: sigmas (B, N), rgbs (B, N, 3), z_vals (B, N) 为采样深度"""
    deltas = z_vals[:, 1:] - z_vals[:, :-1]
    deltas = torch.cat([deltas, torch.full_like(deltas[:, :1], 1e10)], dim=-1)
    alphas = 1.0 - torch.exp(-torch.relu(sigmas) * deltas)  # alpha_i = 1 - exp(-sigma_i * delta_i)
    # 计算累积透射率 T_i = product_{j=1}^{i-1} (1 - alpha_j)
    trans = torch.cumprod(torch.cat([torch.ones_like(alphas[:, :1]), 1.0 - alphas + 1e-10], dim=-1), dim=-1)[:, :-1]
    weights = trans * alphas                                # 采样点贡献权重 w_i = T_i * alpha_i
    comp_rgb = torch.sum(weights.unsqueeze(-1) * rgbs, dim=1)
    depth = torch.sum(weights * z_vals, dim=1)              # 期望终止深度图
    return comp_rgb, depth, weights
```

== 现代加速与几何化：多分辨率哈希编码（Instant-NGP）、抗锯齿与神经隐式表面（NeuS） <sec:ch12-frontier>

原始 NeRF 虽画质惊艳，但存在三大工程瓶颈：（1）单条无限细射线采样在多距离观察下产生严重混叠锯齿；（2）每个采样点均需查询 8 层大 MLP，训练一个场景耗时长达 1–2 天；（3）体密度场 $sigma(bold(x))$ 缺乏明确等值面，用 Marching Cubes 提取出的网格充满噪声凹凸。2021–2026 年的演进逐一攻克了上述难题（综合对比见 @tab:ch12-neural-fields）：

- *圆锥台积分位置编码与抗锯齿（Mip-NeRF）*：Barron 等人提出的 *Mip-NeRF*@barron2021mipnerf 将无限细射线升级为匹配像素截面大小的*三维圆锥台（Conical Frustum）*，将圆锥台截段近似为多元高斯分布，解析推导其傅里叶特征的期望积分（Integrated Positional Encoding, IPE），使高频特征在远距离大体积积分段上自动指数衰减，实现了连续尺度的原生三维抗锯齿【已有成果】。
- *多分辨率空间哈希编码（Instant-NGP）*：Müller 等人提出的 *Instant-NGP*@muller2022instant 将场景参数从庞大的 MLP 权重迁移至 $L = 16$ 层从粗到细的*可学习空间哈希特征表（Multiresolution Hash Encoding）*。任意空间点 $bold(x)$ 在第 $l$ 层分辨率网格的体素顶点通过空间异或哈希函数 $h(bold(x)) = ( xor_(i=1)^3 x_i pi_i ) mod T$ 直接映射为定长特征向量，经三线性插值与各层拼接后仅需通过一个极浅的 2 层 64 维微型 MLP 即可解码出 $(sigma, bold(c))$。即使精细层发生哈希碰撞，不同尺度层的不相干梯度也能自动消解冲突，将 NeRF 训练时间从十余小时缩短至 *5 秒以内*【已有成果】。
- *无偏神经隐式符号距离场（NeuS）*：为从多视角图像中恢复高精度水密网格，Wang 等人提出的 *NeuS*@wang2021neus 将第 7 章的符号距离场（SDF）$f(bold(x)) = 0$ 嵌入体渲染框架。通过构造以零等值面为中心逻辑斯谛分布（S-density）的不透明密度函数 $rho(t) = max(-(d Phi_s)/(d t)(f(bold(r)(t))) / Phi_s (f(bold(r)(t))), 0)$，NeuS 严格消除了传统密度转换中的一阶视角深度偏差，并结合程函方程正则化项 $cal(L)_("Eikonal") = (norm(nabla f(bold(x)))_2 - 1)^2$ 重建出光滑精确的三维几何表面【已有成果】。在现代混合架构中，多分辨率哈希网格结合神经 SDF 已成为高保真静物表面重建的标准基座【本书推断】。

#figure(
  table(
    columns: (2.7cm, 3.0cm, 2.3cm, 2.6cm, 3.6cm),
    align: (left, left, center, center, left),
    [神经场景表征方法], [空间编码与核心原语], [典型训练耗时], [提取几何质量], [核心突破与适用场景],
    [原始 NeRF @mildenhall2020nerf], [傅里叶编码 + 8 层 MLP], [12–24 小时], [粗糙（含密度噪声）], [开创连续体渲染新视角合成],
    [Mip-NeRF @barron2021mipnerf], [圆锥台积分位置编码 IPE], [10–20 小时], [中等], [解决多尺度焦距与距离锯齿],
    [Instant-NGP @muller2022instant], [多分辨率哈希表 + 微型 MLP], [5 秒 – 2 分钟], [中等], [哈希特征解耦参数，极速收敛],
    [NeuS @wang2021neus], [神经 SDF + 无偏 S-density], [2–6 小时], [极高（光滑水密网格）], [消除表面深度偏差，精确重建],
  ),
  caption: [代表性神经辐射场与神经隐式表面方法的核心指标与特性对比],
) <tab:ch12-neural-fields>

#keybox(title: [本章要点])[
1. *可微渲染与边界梯度*：雷诺输运定理表明像素积分关于几何参数的导数包含内部光滑积分与剪影边界曲线积分；SoftRas 通过概率平滑松弛恢复梯度，Nvdiffrast 与 Redner 则直接对剪影轮廓边界执行解析抗锯齿或蒙特卡洛采样。
2. *连续体渲染与 Alpha 合成*：从比尔—朗伯指数衰减定律出发，沿射线分段常值求积可严格导出离散 Alpha 合成公式 $hat(bold(C)) = sum_i T_i alpha_i bold(c)_i$；其关于密度与颜色处处无穷阶可微，天然消除了离散网格的拓扑跳变障碍。
3. *NeRF 家族演进*：傅里叶高频位置编码克服了 MLP 的低频谱偏置；Mip-NeRF 以圆锥台积分实现原生抗锯齿；Instant-NGP 借助多分辨率空间哈希表实现秒级训练；NeuS 则通过无偏 SDF 密度转换打通了体渲染与高精度表面几何重建的桥梁。
]
