#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 现代图形学概览：正向渲染与逆向可微管线

自伊万·萨瑟兰（Ivan Sutherland）于 1963 年在麻省理工学院展示交互式图形系统 Sketchpad @sutherland1963sketchpad 以来，计算机图形学（Computer Graphics, CG）走过了六十余年的演进历程。在经典教科书体系中 @marschner2021fundamentals @akenine2018realtime @pharr2023pbrt，图形学被严格界定为“由虚拟三维场景模型合成二维图像”的正向计算过程。然而，过去五年间，可微渲染（Differentiable Rendering）、神经辐射场（NeRF）@mildenhall2020nerf 与三维高斯泼溅（3D Gaussian Splatting, 3DGS）@kerbl20233dgs 的兴起，彻底打破了“正向合成”与“逆向重建”之间的学科藩篱 @tewari2022advances。

本章作为全书的总纲，首先从算子映射的视角统一界定正向图形学与逆向可微图形学（@sec:ch01-overview），接着剖析支撑经典图形学的四大数学与物理支柱（@sec:ch01-pillars），进而形式化阐述从正向渲染到神经辐射表示的范式转移（@sec:ch01-paradigm），随后梳理现代 GPU 硬件与面向数据编程抽象的协同演进（@sec:ch01-hardware），最后给出前沿演进研判与全书六大模块十三章的学习路线图（@sec:ch01-roadmap）。

== 什么是计算机图形学：从三维世界到二维图像的双向映射 <sec:ch01-overview>

从信息流动的几何与物理本质来看，计算机图形学与计算机视觉（Computer Vision）、摄影测量学（Photogrammetry）共同处理同一组核心对象：*三维场景参数*与*二维观测图像*。设三维世界的状态空间由四个正交子空间构成：几何形状空间 $cal(G)$（表面流形或体密度分布）、材质属性空间 $cal(M)$（双向散射分布函数或反射率张量）、照明环境空间 $cal(L)$（光源几何与辐射度分布）以及虚拟相机空间 $cal(C)$（内外参矩阵、快门与传感器响应）。记场景参数总体为元组 $Theta = (G, M, L, C) in cal(G) times cal(M) times cal(L) times cal(C)$，合成或观测到的二维多通道图像记为 $cal(I) in RR^(H times W times C_"ch")$。

#definition(title: [正向图形学与渲染算子（Forward Graphics & Rendering Operator）])[
  给定完备的三维场景描述 $Theta = (G, M, L, C)$，*正向图形学*研究如何通过模拟几何投射与光能传输物理规律，构造确定性或随机逼近映射
  $ cal(R): cal(G) times cal(M) times cal(L) times cal(C) -> cal(I), quad Theta |-> hat(cal(I)) = cal(R)(G, M, L, C), $ <eq:ch01-forward>
  其中映射 $cal(R)$ 称为*正向渲染算子*（Forward Rendering Operator），输出 $hat(cal(I))$ 为合成图像。
]

在物理世界中，算子 $cal(R)$ 由麦克斯韦电磁场方程在几何光学极限下的辐射传输规律所支配，其精确数学表述即卡吉亚（James Kajiya）于 1986 年提出的渲染方程（Rendering Equation）@kajiya1986rendering。正向图形学的核心挑战在于：场景几何 $G$ 可包含数以亿计的微多边形，算子 $cal(R)$ 涉及高维半球面上的递归路径积分，如何在严格的延迟预算（如实时渲染的 $16.67 "ms"$）或无偏物理精度下高效求解 @eq:ch01-forward，构成了光栅化管线 @akenine2018realtime 与蒙特卡洛路径追踪 @pharr2023pbrt 的主要课题。

#definition(title: [逆图形学与可微渲染（Inverse Graphics & Differentiable Rendering）])[
  给定一组真实世界或参考传感器捕获的多视角二维图像集合 ${cal(I)_"obs"^((k))}_(k=1)^K$，*逆图形学*旨在求解渲染算子的伪逆映射 $cal(R)^(-1)$，从二维观测中恢复潜在的三维几何、材质、光照或相机位姿：
  $ Theta^* = argmin_Theta sum_(k=1)^K cal(L)_"photo" (cal(R)(G, M, L, C_k), cal(I)_"obs"^((k))) + lambda cal(R)_"reg" (Theta). $ <eq:ch01-inverse>
  当渲染算子 $cal(R)$ 对场景参数 $Theta$ 几乎处处可微（或存在良定义的平滑替代梯度 $nabla_Theta cal(R)$）时，通过链式法则将图像域光度误差梯度 $partial cal(L)_"photo" / partial hat(cal(I))$ 反向传播至三维场景空间的计算范式，称为*可微渲染* @tewari2022advances。
]

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let boxstyle = (radius: 0.12, fill: softbg, stroke: 0.9pt + accent)
    let invstyle = (radius: 0.12, fill: bluebg, stroke: 0.9pt + accent2)

    // 左侧：三维场景参数空间 Theta
    rect((0.2, 1.5), (3.4, 5.1), ..boxstyle, name: "theta")
    content((1.8, 4.65), text(size: 8pt, weight: "bold", fill: accent.darken(15%))[三维场景参数 $Theta$])
    content((1.8, 4.05), text(size: 7.5pt)[几何流形/场 $G in cal(G)$])
    content((1.8, 3.45), text(size: 7.5pt)[材质散射属性 $M in cal(M)$])
    content((1.8, 2.85), text(size: 7.5pt)[辐射照明分布 $L in cal(L)$])
    content((1.8, 2.25), text(size: 7.5pt)[相机投影模型 $C in cal(C)$])

    // 中上：正向渲染算子 R
    rect((4.8, 3.8), (8.6, 5.1), ..boxstyle, name: "fwd")
    content((6.7, 4.68), text(size: 8pt, weight: "bold")[正向渲染算子 $cal(R)(Theta)$])
    content((6.7, 4.15), text(size: 7.5pt)[光栅化 / 路径追踪 / 体渲染积分])

    // 右上：合成图像 I_hat
    rect((10.0, 3.8), (13.6, 5.1), ..boxstyle, name: "ihat")
    content((11.8, 4.68), text(size: 8pt, weight: "bold")[合成图像 $hat(cal(I)) = cal(R)(Theta)$])
    content((11.8, 4.15), text(size: 7.5pt)[像素辐射度 $RR^(H times W times 3)$])

    // 右下：光度损失与观测监督
    rect((10.0, 1.5), (13.6, 2.9), ..invstyle, name: "loss")
    content((11.8, 2.45), text(size: 8pt, weight: "bold", fill: accent2.darken(15%))[光度与几何损失 $cal(L)_"photo"$])
    content((11.8, 1.9), text(size: 7.5pt)[对比真实观测图像 $cal(I)_"obs"$])

    // 中下：可微逆向算子与梯度反传
    rect((4.8, 1.5), (8.6, 2.9), ..invstyle, name: "bwd")
    content((6.7, 2.45), text(size: 8pt, weight: "bold", fill: accent2.darken(15%))[可微伴随算子 $nabla_Theta cal(R)$])
    content((6.7, 1.9), text(size: 7.5pt)[边界重参数化 / 伴随辐射传输])

    // 底部提示标注
    rect((3.8, 0.2), (9.6, 1.0), radius: 0.1, fill: redbg, stroke: 0.7pt + warn)
    content((6.7, 0.6), text(size: 7.5pt, fill: warn.darken(10%))[物理先验正则化 $lambda cal(R)_"reg"(Theta)$：消除病态逆问题（几何—光照歧义）])

    // 箭头连接：正向链路（上方，深青色）
    line((3.45, 4.45), (4.75, 4.45), mark: (end: ">"), stroke: 1.0pt + accent)
    content((4.1, 4.78), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt)[输入])
    line((8.65, 4.45), (9.95, 4.45), mark: (end: ">"), stroke: 1.0pt + accent)
    content((9.3, 4.78), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt)[合成])

    // 右侧向下：残差评估
    line((11.8, 3.75), (11.8, 2.95), mark: (end: ">"), stroke: 1.0pt + accent2)
    content((12.5, 3.35), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt)[残差 $hat(cal(I)) - cal(I)_"obs"$])

    // 逆向链路（下方，赭棕色）
    line((9.95, 2.2), (8.65, 2.2), mark: (end: ">"), stroke: 1.0pt + accent2)
    content((9.3, 2.52), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt)[$partial cal(L) / partial hat(cal(I))$])
    line((4.75, 2.2), (3.45, 2.2), mark: (end: ">"), stroke: 1.0pt + accent2)
    content((4.1, 2.52), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt)[更新 $Delta Theta$])

    // 正向算子到伴随算子的缓存连线
    line((6.7, 3.75), (6.7, 2.95), mark: (end: ">"), stroke: (dash: "dashed", paint: gray.darken(30%), thickness: 0.8pt))
    content((7.55, 3.35), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.0pt)[前向状态缓存])

    // 正则项向梯度注入
    line((6.7, 1.05), (6.7, 1.45), mark: (end: ">"), stroke: (dash: "dashed", paint: warn, thickness: 0.8pt))
  })),
  caption: [现代计算机图形学的正向合成（上路，深青色）与可微逆向重建（下路，赭棕色）双闭环架构。正向算子 $cal(R)$ 将三维场景参数 $Theta$ 投射为二维图像 $hat(cal(I))$；可微伴随算子 $nabla_Theta cal(R)$ 则将图像空间的光度误差反向传播回三维空间，驱动几何、材质与辐射场的联合优化。],
) <fig:ch01-forward-inverse>

如 @fig:ch01-forward-inverse 所示，正向合成与逆向重建并非彼此割裂的两个学科，而是同一物理生成模型的正演与反演两面。正向路径是良定（Well-Posed）的积分计算，而逆向路径则是典型的病态（Ill-Posed）反问题：由于三维到二维的透视投射丢失了深度维度，且像素颜色是表面反射率与入射光照的乘积耦合，无穷多组不同的 $(G, M, L)$ 组合可以产生完全相同的二维图像（例如把白色墙壁涂成暗灰色同时增强光源强度）。因此，现代图形学必须同时掌握正向算子 $cal(R)$ 的精确物理建模与逆向优化中的先验正则化设计。

== 正向图形学四大支柱：几何、渲染、成像与仿真 <sec:ch01-pillars>

在深入任何具体算法之前，我们需要建立正向图形学的全局数学鸟瞰。支撑整个经典与现代图形学大厦的理论体系，可归纳为紧密耦合的四大支柱 @marschner2021fundamentals：

=== 第一支柱：空间变换与几何表示（Geometry & Modeling）

任何图形管线的第一步都是在数学上回答“物体在哪里、形状是什么”。在空间布局层面，三维刚体与柔体的位置、朝向及相机投影均由射影空间 $PP^3$ 中的 $4 times 4$ 齐次变换矩阵 $bold(M) in RR^(4 times 4)$ 与单位四元数描述（第 2 章）。在形状表达层面，三维对象存在两大互补范式：
- *显式表示（Explicit Representation）*：以参数映射 $bold(s): Omega subset RR^2 -> RR^3$ 直接给出表面点的坐标，典型代表包括贝塞尔（Bézier）与 B 样条参数曲面（第 7 章）、多边形半边网格（Half-Edge Mesh，第 8 章）以及近年来兴起的三维各向异性高斯椭球集合 ${ (bold(mu)_i, bold(Sigma)_i, alpha_i, bold(c)_i) }$ @kerbl20233dgs（第 13 章）。显式表示易于进行空间变换和硬件光栅化，但难以处理拓扑结构的剧烈分裂与合并。
- *隐式表示（Implicit Representation）*：将表面定义为标量场 $phi: RR^3 -> RR$ 的零等值面 ${ bold(x) in RR^3 mid(|) phi(bold(x)) = 0 }$，包括代数曲面、有向距离场（Signed Distance Field, SDF）以及多层感知机参数化的神经隐式场（第 7、12 章）。隐式表示天然支持布尔运算、球体追踪求交与拓扑自适应演化，但提取显式网格需借助 Marching Cubes 等等值面离散化算子。

=== 第二支柱：渲染与光能传输（Rendering & Light Transport）

当几何表面与空间坐标确定后，渲染支柱回答“光子如何在场景中传播并汇聚到虚拟相机”。在几何光学近似下，辐射亮度（Radiance）$L(bold(x), omega)$ 沿真空直线的守恒性构成了光传输的基石（第 3 章）。表面点 $bold(x)$ 沿出射方向 $omega_o$ 辐射的亮度由 Kajiya 渲染方程 @kajiya1986rendering 唯一定出：
$ L_o (bold(x), omega_o) = L_e (bold(x), omega_o) + integral_(Omega^+) f_r (bold(x), omega_i, omega_o) L_i (bold(x), omega_i) (bold(n) dot omega_i) dif omega_i, $ <eq:ch01-kajiya>
其中 $L_e$ 为表面自发光，$f_r (bold(x), omega_i, omega_o)$ 为刻画材质微观光学特性的双向反射分布函数（BRDF），$Omega^+$ 为以表面单位法线 $bold(n) in SS^2$ 为极轴的上半球面。围绕 @eq:ch01-kajiya 的求解策略分化出两大主流管线：一是以局部光照近似结合屏幕空间/预计算全局光照的*实时光栅化管线*（第 4–6 章）@akenine2018realtime；二是以包围盒层次结构（BVH）加速光线求交、用蒙特卡洛重要性采样无偏求解无穷维路径积分的*物理基路径追踪管线*（第 9–10 章）@pharr2023pbrt。

=== 第三支柱：信号采样、色彩与成像科学（Sampling & Imaging）

无论是光栅化中的屏幕像素中心测试，还是路径追踪中的随机光线投射，本质上都是对连续高频辐射场信号 $L(x, y, t, lambda)$ 的离散采样过程。根据 Nyquist-Shannon 采样定理，当场景中包含硬阴影边界、亚像素几何细节或高频棋盘纹理时，有限采样率必然引发频谱混叠，在图像上表现为锯齿（Jaggies）、摩尔纹（Moiré Pattern）与时间闪烁。同时，在光谱维度上，连续波长分布的光谱功率需经 CIE 标准观察者匹配函数积分转换为三刺激值，并历经非线性伽马编码（sRGB）与高动态范围色调映射（Tone Mapping）方能正确呈现在物理显示设备上（第 3 章）。

=== 第四支柱：动力学动画与物理仿真（Animation & Simulation）

静态场景只是世界在单一时刻的切片；第四支柱赋予三维场景随时间演化的生命力。从数学上看，动画与仿真研究状态向量 $bold(q)(t) in RR^(3N)$ 随时间 $t$ 的轨迹微分方程：
$ bold(M)_"mass" frac(dif^2 bold(q), dif t^2) = bold(f)_"int" (bold(q), dot(bold(q))) + bold(f)_"ext" (t), $ <eq:ch01-dynamics>
其中 $bold(M)_"mass"$ 为质量矩阵，$bold(f)_"int"$ 与 $bold(f)_"ext"$ 分别为弹性内力与外力（如重力、碰撞接触力）。从骨骼蒙皮（Skeletal Skinning）的运动学插值，到隐式欧拉积分、基于位置的动力学（Position-Based Dynamics, PBD）以及物质点法（MPM），物理仿真不仅驱动着影视与游戏特效（第 11 章），更为具身智能机器人训练提供了高保真物理交互试验场。

== 现代范式转移：逆图形学、可微渲染与神经辐射表示 <sec:ch01-paradigm>

在传统正向管线中，三维内容创作高度依赖三维美术师手工雕刻网格、展开 UV 并绘制贴图，成本高昂且难以直接复制真实物理世界。2018 年以来，计算机图形学经历了一场深刻的范式转移：渲染管线不再只是一条单向的终点流水线，而是作为一个可微物理模块嵌入到端到端梯度优化闭环之中 @tewari2022advances。

=== 连续可微松弛与神经体渲染的崛起

要令 @eq:ch01-inverse 中的优化问题可通过梯度下降求解，核心障碍在于传统渲染算子 $cal(R)$ 中的*可见性不连续性*（Visibility Discontinuity）。在经典光栅化或光线追踪中，像素颜色对三角形顶点坐标 $Theta$ 的被积函数包含阶跃可见性项 $V(bold(x); Theta) in {0, 1}$。由于阶跃函数在遮挡边界外的导数恒为零、在边界处为狄拉克 $delta$ 分布，直接对像素内部求导无法提供推动遮挡边界移动的梯度信号。

为攻克这一难题，现代图形学演化出两条极具代表性的技术路线：
1. *显式表面可微渲染*：通过软光栅化（Soft Rasterization）的概率边缘松弛，或在蒙特卡洛路径追踪中显式分离内部积分与边界线积分（Edge Sampling / Reparameterization），精确计算辐射度对网格顶点与材质贴图的伴随导数（第 12 章）。
2. *连续体密度与辐射场表征*：彻底绕开离散表面网格的拓扑跳变，将三维场景建模为连续可微的消光密度场 $sigma(bold(x)) in RR_(>= 0)$ 与方向相关颜色场 $bold(c)(bold(x), omega) in [0, 1]^3$。沿相机光线 $bold(r)(t) = bold(o) + t bold(d)$ 的期望颜色由经典体渲染方程给出：
   $ hat(bold(C))(bold(r)) = integral_(t_n)^(t_f) T(t) sigma(bold(r)(t)) bold(c)(bold(r)(t), bold(d)) dif t, quad T(t) = exp(- integral_(t_n)^t sigma(bold(r)(s)) dif s). $ <eq:ch01-volrender>
   由于 @eq:ch01-volrender 对密度 $sigma$ 和颜色 $bold(c)$ 处处光滑可导，Mildenhall 等人提出的神经辐射场（NeRF）@mildenhall2020nerf 利用坐标多层感知机（MLP）结合高频位置编码直接拟合 $(sigma, bold(c))$，仅凭数十张多视角照片即可恢复出达到照片级真实感的新视角合成图像。

=== 从隐式神经场到 3D Gaussian Splatting 的显式回归

尽管 NeRF 在重建质量上取得了突破，但沿每条像素光线密集查询神经网络需要极高的算力，限制了其在实时渲染与交互式编辑中的应用。2023 年，Kerbl 等人提出的 3D Gaussian Splatting（3DGS）@kerbl20233dgs 完成了“神经隐式体渲染”与“经典显式光栅化”的精妙合流：它将场景表示为数百万个带有三维均值 $bold(mu)_i$、协方差矩阵 $bold(Sigma)_i$、不透明度 $alpha_i$ 与球谐方向颜色系数的三维高斯椭球，通过雅可比仿射近似将其直接投影至二维屏幕空间进行基于图块（Tile-Based）的高速 $alpha$ 混合排序光栅化，在维持全程可微的同时实现了 $1080"p"$ 分辨率下超过 $100 "FPS"$ 的实时辐射场渲染。

#figure(
  table(
    columns: (2.4cm, 2.8cm, 2.9cm, 3.1cm, 2.8cm),
    align: (left, left, left, left, left),
    [*管线范式*], [*核心几何表征*], [*前向计算复杂度*], [*可微性与梯度特性*], [*优势与典型场景*],
    [经典光栅化 \ @akenine2018realtime], [显式三角形网格 \ 顶点 + 纹理贴图], [$O(N_"tri" + H W)$ \ 硬件光栅化极快], [原生阶跃不可导；需软化边缘或屏幕空间近似], [超低延迟实时渲染 \ 游戏引擎、交互仿真],
    [物理路径追踪 \ @pharr2023pbrt], [显式网格 / 隐式 SDF + BVH 加速树], [$O(H W dot N_"spp" log N_"prim")$ \ 蒙特卡洛随机收敛], [需边界重参数化与伴随路径回传以消除方差], [全局光照物理金标准 \ 影视离线、逆材质恢复],
    [神经辐射场 (NeRF) \ @mildenhall2020nerf], [连续隐式体密度场 \ MLP / 哈希网格], [$O(H W dot N_"pts" C_"net")$ \ 逐光线体积分偏慢], [体渲染积分天然处处光滑可导，拓扑自由演化], [高保真多视角三维重建 \ 复杂半透明与反射场景],
    [三维高斯泼溅 (3DGS) \ @kerbl20233dgs], [显式三维各向异性高斯椭球点云], [$O(N_"gauss" log N_"gauss" + H W bar(k))$ \ 图块光栅化极快], [投影位置、协方差与球谐系数全链路解析可微], [实时新视角合成、动态场重建与具身数字孪生],
  ),
  caption: [现代图形学四大主流渲染与表征范式的核心特性对比。从经典光栅化与路径追踪到 NeRF 与 3DGS，几何表示与可微性设计呈现出“显式离散 → 隐式连续 → 显式可微核函数”的螺旋演进。],
) <tab:ch01-paradigms>

@tab:ch01-paradigms 系统对比了这四种范式的内在权衡。理解它们在表示空间、积分机制与梯度流上的共性与差异，正是本书贯穿始终的主线。

== 硬件演进与计算抽象：从固定管线到光追核心与张量着色 <sec:ch01-hardware>

图形学算法的每一次跃迁都与底层计算硬件的架构革新密不可分。早期图形处理器（如 20 世纪 90 年代的固定功能管线 GPU）仅将坐标变换、三角形光栅化与纹理混合固化为不可编程的专用集成电路。随着可编程着色器（Vertex/Fragment/Compute Shaders）的普及，现代 GPU 演进为高度并行的*单指令多线程（SIMT）*吞吐量处理器：数千个流处理器核心将每 $32$（或 $64$）个并行线程编组为一个线程束（Warp / Wavefront），锁步执行同一条指令流。

在 SIMT 模型下，图形程序员面临两条铁律：
1. *避免分支发散（Branch Divergence）*：若同一 Warp 内的不同像素或光线进入 `if-else` 的不同分支，硬件必须串行执行两个分支并掩码屏蔽非活动线程，导致吞吐量减半甚至急剧劣化。
2. *尊重存储层次与合并访存（Memory Coalescing）*：寄存器与片上共享内存（Shared Memory / L1 Cache）的带宽高达数十 $"TB/s"$，而片外全局显存（VRAM）延迟高达数百个时钟周期。无论是光栅化中的莫顿码（Morton Code）纹理块排布，还是 3DGS 中按 $16 times 16$ 屏幕图块（Tile）将数据预加载至共享内存 @kerbl20233dgs，本质上都是为了最大化空间局部性。

进入 2018 年以来，现代 GPU 进一步集成了三大异构计算单元：(i) *传统光栅化与可编程流多处理器（SM）*；(ii) *专用光线追踪核心（RT Cores）*，在硬件电路层面加速包围盒层次结构（BVH）遍历与光线—三角形求交测试；(iii) *张量核心（Tensor Cores）*，提供极高吞吐的半精度（FP16/BF16/FP8）矩阵乘加运算，直接赋能深度学习超分辨率（DLSS）、神经辐射缓存与神经材质解码。

与此同时，编写高性能、可微图形学代码的软件抽象也发生了变革。由胡渊鸣等人提出的 *Taichi（太极）*编程语言 @hu2019taichi 将“计算逻辑”与“稀疏空间数据结构（SNode）”解耦，并原生提供面向物理仿真与渲染内核的源到源自动微分（AutoDiff）编译器。下面给出一段基于 PyTorch 张量向量化风格的相机主光线生成与球面隐式场体渲染积分示例，直观展示现代图形学如何将百万像素的几何与积分运算表达为无显式循环的并行张量算子：

```python
import torch

def render_implicit_sphere(H: int = 256, W: int = 256, fov_deg: float = 60.0):
    """向量化生成相机光线并通过可微体渲染积分合成三维球体图像"""
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    # 1. 构建归一化像素网格 (H, W) 并映射至相机局部坐标系 (右手系, 看向 -z)
    j, i = torch.meshgrid(
        torch.linspace(0.5, H - 0.5, H, device=device),
        torch.linspace(0.5, W - 0.5, W, device=device), indexing="ij"
    )
    focal = 0.5 * W / torch.tan(torch.deg2rad(torch.tensor(fov_deg * 0.5)))
    dirs = torch.stack([(i - 0.5 * W) / focal, -(j - 0.5 * H) / focal, -torch.ones_like(i)], dim=-1)
    rays_d = dirs / torch.norm(dirs, dim=-1, keepdim=True)          # 单位光线方向 (H, W, 3)
    rays_o = torch.tensor([0.0, 0.0, 3.0], device=device).expand_as(rays_d)

    # 2. 定义待优化的场景参数：球心位置 mu 与软边界球体密度场
    mu = torch.tensor([0.15, -0.1, 0.0], device=device, requires_grad=True)
    t_vals = torch.linspace(1.5, 4.5, 64, device=device)            # 沿光线均匀采样 64 个深度点
    pts = rays_o.unsqueeze(-2) + rays_d.unsqueeze(-2) * t_vals.view(1, 1, -1, 1)  # (H, W, 64, 3)

    # 3. 计算可微体密度 sigma 与合成像素辐射度 (式 1.5 的离散求积法则)
    dist_sq = torch.sum((pts - mu) ** 2, dim=-1)
    sigma = 15.0 * torch.sigmoid(20.0 * (1.0 - dist_sq))            # 半径 r=1 的软球体密度
    delta_t = t_vals[1] - t_vals[0]
    alpha = 1.0 - torch.exp(-sigma * delta_t)                       # 局部区间不透明度
    trans = torch.cumprod(torch.cat([torch.ones_like(alpha[..., :1]), 1.0 - alpha[..., :-1] + 1e-10], dim=-1), dim=-1)
    weights = trans * alpha                                         # 体渲染权重 w_k = T_k * alpha_k
    image = torch.sum(weights.unsqueeze(-1) * torch.sigmoid(pts), dim=-2)
    return image, mu
```

在上述仅二十余行的代码中，`mu` 的梯度可直接通过 `image.mean().backward()` 自动反传至三维空间——这正是可微图形学将物理几何模型与现代张量自动微分无缝融合的缩影。

== 现代演进与全书路线图 <sec:ch01-roadmap>

站在 2026 年的时间节点审视计算机图形学的前沿版图，我们可以用三档证据标签对学科演进趋势做出清晰界定：
- 【已有成果】*神经渲染与传统管线的工业级混合部署已成定局*：在实时端，以虚幻引擎 5（Unreal Engine 5）的 Nanite 微多边形光栅化、Lumen 混合光线追踪与时空储层重采样（ReSTIR）为代表的现代实时管线已全面普及；在重建端，3DGS @kerbl20233dgs 及其抗锯齿演进算法已可通过网格光栅化器与光线追踪器同场混合渲染。
- 【本书推断】*正向物理管线与生成式世界模型正在汇流为统一架构*：纯粹依赖二维视频扩散模型的生成系统缺乏长期三维几何一致性与物理力学因果律，而纯传统图形管线面临资产创建瓶颈；将显式三维高斯/网格表征、可微物理仿真器（如 DiffTaichi）与预训练视觉生成先验深度耦合，是构建具身智能仿真底座与下一代空间计算引擎的必由之路。
- 【本书提出】*以“算子正演—伴随反演”为主轴的现代图形学教学体系*：传统教材往往将光栅化、几何网格、光线追踪视为孤立模块，把神经渲染当作课外阅读；本书将全书十三章组织为“数学物理底座 → 光栅化实时管线 → 几何表示与网格处理 → 物理基路径追踪 → 动画与物理仿真 → 可微与神经图形学”六大递进模块，在每一模块中显式打通从正向前向方程到逆向可微形式的理论桥梁。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let mstyle = (radius: 0.12, fill: softbg, stroke: 0.9pt + accent)
    let fstyle = (radius: 0.12, fill: bluebg, stroke: 0.95pt + accent2)

    // 模块一：顶部全宽底座
    rect((0.5, 6.2), (13.5, 7.5), ..mstyle, name: "m1")
    content((7.0, 7.1), text(size: 8pt, weight: "bold", fill: accent.darken(15%))[模块一：数学、信号与物理底座（第 1–3 章）])
    content((7.0, 6.55), text(size: 7.5pt)[第 1 章 现代图形学概览 · 第 2 章 空间变换与相机投影 · 第 3 章 信号采样、色彩与辐射度量学])

    // 模块二：左中（实时光栅化）
    rect((0.5, 3.8), (4.5, 5.4), ..mstyle, name: "m2")
    content((2.5, 5.0), text(size: 8pt, weight: "bold")[模块二：实时渲染管线])
    content((2.5, 4.5), text(size: 7.2pt)[第 4 章 光栅化与可见性])
    content((2.5, 4.1), text(size: 7.2pt)[第 5–6 章 纹理、GPU 与实时 GI])

    // 模块三：中中（几何处理）
    rect((5.0, 3.8), (9.0, 5.4), ..mstyle, name: "m3")
    content((7.0, 5.0), text(size: 8pt, weight: "bold")[模块三：几何表示与处理])
    content((7.0, 4.5), text(size: 7.2pt)[第 7 章 参数曲面与隐式 SDF])
    content((7.0, 4.1), text(size: 7.2pt)[第 8 章 半边网格与离散微分算子])

    // 模块四：右中（物理基渲染）
    rect((9.5, 3.8), (13.5, 5.4), ..mstyle, name: "m4")
    content((11.5, 5.0), text(size: 8pt, weight: "bold")[模块四：物理基路径追踪])
    content((11.5, 4.5), text(size: 7.2pt)[第 9 章 BVH 加速与渲染方程])
    content((11.5, 4.1), text(size: 7.2pt)[第 10 章 微表面 BRDF 与蒙特卡洛])

    // 模块五：左下（动画与物理仿真）
    rect((0.5, 1.2), (5.8, 2.8), ..mstyle, name: "m5")
    content((3.15, 2.38), text(size: 8pt, weight: "bold")[模块五：计算机动画与物理仿真])
    content((3.15, 1.85), text(size: 7.2pt)[第 11 章 骨骼蒙皮、隐式积分与基于位置的动力学 (PBD)])
    content((3.15, 1.45), text(size: 7.2pt)[物质点法 (MPM) 与可微物理仿真算子])

    // 模块六：右下（逆图形学与神经渲染）
    rect((6.5, 1.2), (13.5, 2.8), ..fstyle, name: "m6")
    content((10.0, 2.38), text(size: 8pt, weight: "bold", fill: accent2.darken(15%))[模块六：逆图形学、可微渲染与神经图形学])
    content((10.0, 1.85), text(size: 7.2pt)[第 12 章 可微光栅化/路径追踪、伴随微分与神经辐射场 (NeRF)])
    content((10.0, 1.45), text(size: 7.2pt)[第 13 章 3D Gaussian Splatting、2DGS、4D 动态场与生成式三维])

    // 箭头连接：模块一 -> 模块二、三、四
    line((2.5, 6.15), (2.5, 5.45), mark: (end: ">"), stroke: 0.9pt + accent)
    content((3.25, 5.8), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.0pt)[MVP 与采样])
    line((7.0, 6.15), (7.0, 5.45), mark: (end: ">"), stroke: 0.9pt + accent)
    content((7.75, 5.8), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.0pt)[向量与标架])
    line((11.5, 6.15), (11.5, 5.45), mark: (end: ">"), stroke: 0.9pt + accent)
    content((12.3, 5.8), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.0pt)[辐射度量学])

    // 模块间横向协同
    line((4.55, 4.6), (4.95, 4.6), mark: (end: ">", start: ">"), stroke: (dash: "dashed", paint: accent, thickness: 0.8pt))
    line((9.05, 4.6), (9.45, 4.6), mark: (end: ">", start: ">"), stroke: (dash: "dashed", paint: accent, thickness: 0.8pt))

    // 中层 -> 底层模块五与模块六
    line((2.5, 3.75), (2.5, 2.85), mark: (end: ">"), stroke: 0.9pt + accent)
    line((5.6, 3.75), (4.2, 2.85), mark: (end: ">"), stroke: 0.9pt + accent)
    line((3.8, 3.75), (7.5, 2.85), mark: (end: ">"), stroke: 0.9pt + accent2)
    content((5.5, 3.35), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.0pt)[光栅泼溅])
    line((7.6, 3.75), (9.2, 2.85), mark: (end: ">"), stroke: 0.9pt + accent2)
    content((8.7, 3.35), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.0pt)[SDF/场表征])
    line((11.5, 3.75), (11.5, 2.85), mark: (end: ">"), stroke: 0.9pt + accent2)
    content((12.3, 3.35), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.0pt)[体传输积分])

    // 模块五 <-> 模块六 交互
    line((5.85, 2.0), (6.45, 2.0), mark: (end: ">", start: ">"), stroke: 0.9pt + accent2)
  })),
  caption: [《现代计算机图形学导论》全书六大模块与十三章依赖关系图。模块一提供统一的齐次代数、采样理论与辐射度量底座；模块二至五构建正向图形学四大支柱；模块六将光栅化、隐式场与体传输积分汇流为可微与神经图形学闭环。],
) <fig:ch01-roadmap>

@fig:ch01-roadmap 展示了全书的知识拓扑结构。对于不同背景的读者，我们建议三条定制化学习路径：(i) *本科生与图形学入门读者*建议按第 1→2→3→4→5→7→9→10→12→13 章循序渐进，夯实正向基础后再进入可微渲染；(ii) *计算机视觉与三维重建研究者*可重点精读第 1、2、3、4、7、9、12、13 章，直接穿透相机投影矩阵、光栅化插值、体渲染方程与 3DGS 的底层数学细节；(iii) *游戏引擎与具身仿真工程师*可沿第 1→2→4→5→6→8→11→13 章推进，聚焦实时渲染管线、网格几何处理、PBD/MPM 物理仿真与实时高斯场景数字孪生。

#keybox(title: [本章要点])[
  1. *双向算子视角*：正向图形学研究渲染映射 $cal(R): (G, M, L, C) |-> hat(cal(I))$ 的高保真快速计算；逆图形学与可微渲染则通过构造伴随算子 $nabla_Theta cal(R)$，在光度损失与物理先验约束下从二维观测反演三维场景。
  2. *四大基础支柱*：空间变换与显隐式几何解决“形状与位置”，辐射度量与光能传输解决“明暗与着色”，信号采样与色彩科学解决“离散化与感知显示”，动力学与数值积分解决“时间演化与物理交互”。
  3. *表征与管线合流*：从离散三角形网格（光栅化/路径追踪）到连续隐式神经场（NeRF），再到显式各向异性三维高斯核（3DGS），现代图形学正走向“显式几何可微化、神经表示实时化”的深度融合。
  4. *硬件与算法协同*：SIMT 线程束锁步执行、片上共享内存局部性、RT Cores 硬件求交与 Tensor Cores 矩阵加速共同塑造了现代渲染管线与 Taichi/PyTorch 等数据并行编程范式的设计准则。
]
