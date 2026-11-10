#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 信号采样、色彩科学与辐射度量学基础

在第 2 章建立了连续三维空间到二维平面的几何投射之后，本章继续回答计算机图形学的另外两个底层物理与数学问题：第一，连续的场景几何与辐射场信号如何被离散的像素阵列无走样地采样与重建；第二，光能在三维空间中传播并最终激发人类视觉感知的物理度量与色彩法则是什么。

本章由浅入深分为五个部分：首先从傅里叶频域视角阐述 Nyquist-Shannon 采样定理 @shannon1949communication 与走样（Aliasing）产生的数学机理（@sec:ch03-sampling）；接着推导重建滤波器族 @mitchell1988reconstruction 与 Cook 随机采样抗锯齿理论 @cook1986stochastic（@sec:ch03-reconstruction）；随后严格定义辐射度量学五大核心物理量并证明辐射亮度沿光线守恒定理 @nicodemus1977geometrical @pharr2023pbrt（@sec:ch03-radiometry）；进而建立光度学、CIE 色度空间、sRGB 伽马非线性编码与高动态范围色调映射 @reinhard2002photographic 的完整链路（@sec:ch03-color）；最后探讨广色域 HDR 与光谱渲染的现代演进（@sec:ch03-frontier）。

== 傅里叶分析、Nyquist-Shannon 采样定理与走样机理 <sec:ch03-sampling>

无论是光栅化管线在像素中心判断三角形覆盖关系，还是路径追踪器在像素窗口内投射离散光线，抑或是纹理映射器在屏幕上查询纹素（Texel），其数学本质都是用离散点阵对连续二维空间信号 $f(x, y)$（或时空信号 $f(x, y, t)$）执行*采样（Sampling）*，再通过显示设备将离散样本恢复为连续视觉信号——即*重建（Reconstruction）*。

=== 二维空间傅里叶变换与狄拉克梳采样

设连续二维图像信号 $f(x, y) in L^2(RR^2)$，其二维连续傅里叶变换（Continuous Fourier Transform, CFT）$hat(f)(xi_x, xi_y)$ 及其逆变换定义为：
$ hat(f)(xi_x, xi_y) = integral_(-oo)^(+oo) integral_(-oo)^(+oo) f(x, y) e^(-i 2 pi (xi_x x + xi_y y)) dif x dif y, $ <eq:ch03-cft>
$ f(x, y) = integral_(-oo)^(+oo) integral_(-oo)^(+oo) hat(f)(xi_x, xi_y) e^(i 2 pi (xi_x x + xi_y y)) dif xi_x dif xi_y, $ <eq:ch03-icft>
其中 $(xi_x, xi_y)$ 为空间频率（单位为周期/像素或 $"cycles/mm"$）。在频域中，平滑渐变的漫反射表面对应集中在原点 $(0, 0)$ 附近的*低频分量*；而锐利的几何轮廓遮挡边、硬阴影边界与精细棋盘格纹理则对应向高频无限延伸的*高频分量*。

以均匀间隔 $(Delta x, Delta y)$（对应采样频率 $f_(s, x) = 1 / Delta x, f_(s, y) = 1 / Delta y$）对连续信号 $f(x, y)$ 进行点采样，等价于在空间域将 $f(x, y)$ 乘以二维*狄拉克梳状函数（Dirac Comb / Shah Function）* $"III"_(Delta x, Delta y)(x, y)$：
$ f_s (x, y) = f(x, y) dot "III"_(Delta x, Delta y)(x, y) = f(x, y) sum_(m=-oo)^(+oo) sum_(n=-oo)^(+oo) delta(x - m Delta x, y - n Delta y). $ <eq:ch03-dirac-comb>
根据傅里叶变换的*卷积定理*——空间域的乘积严格对应频域的卷积，且间距为 $Delta x$ 的狄拉克梳的傅里叶变换仍为间距为 $f_s = 1 / Delta x$ 的频域狄拉克梳。以一维截面为例，采样后信号 $f_s (x)$ 的频谱 $hat(f)_s (xi)$ 为原始基带频谱 $hat(f)(xi)$ 以采样频率 $f_s$ 为周期的无穷周期延拓：
$ hat(f)_s (xi) = cal(F){ f(x) dot "III"_(Delta x)(x) } = f_s sum_(k=-oo)^(+oo) hat(f)(xi - k f_s). $ <eq:ch03-spectrum-rep>

=== Nyquist-Shannon 采样定理与频谱混叠

由 @eq:ch03-spectrum-rep 可知，精确从离散样本 $f_s$ 恢复原始连续信号 $f$ 的充要条件是：周期延拓出的各个副本频谱 $hat(f)(xi - k f_s)$（$k != 0$）与中心基带频谱 $hat(f)(xi)$（$k = 0$）之间*互不重叠*。

#theorem(title: [Nyquist-Shannon 采样定理 @shannon1949communication])[
  设连续信号 $f(x)$ 为严格带限（Band-Limited）信号，即存在最高截止频率 $f_"max" > 0$，使得对一切 $|xi| > f_"max"$ 恒有 $hat(f)(xi) = 0$。若均匀采样频率 $f_s = 1 / Delta x$ 严格满足奈奎斯特条件：
  $ f_s > 2 f_"max" quad ("其中" f_"Nyquist" = f_s / 2 "称为奈奎斯特极限频率"), $ <eq:ch03-nyquist>
  则原始连续信号 $f(x)$ 可通过在频域乘以截止频率为 $f_s / 2$ 的理想低通矩形滤波器（等价于在空间域卷积归一化 $"sinc"$ 函数）无损唯一重建。
]

反之，当采样率不足（$f_s < 2 f_"max"$，称为欠采样 Undersampling）或原始信号本身非带限（如三角形光栅化中的阶跃边缘，其频谱按 $1 / |xi|$ 衰减至无穷远，$f_"max" = oo$）时，相邻频谱副本 $|xi - f_s| < f_"max"$ 的高频尾部必然侵入基带区间 $[-f_s / 2, f_s / 2]$ 并与原始低频信号相加。这种*高频能量伪装（Alias）成低频假信号且无法通过后处理分离*的现象，即为*走样（Aliasing）*。在图形学中，走样表现为三种典型伪影：(i) *几何边缘锯齿（Jaggies）*：阶跃边界欠采样导致的阶梯状抖动；(ii) *纹理摩尔纹（Moiré Pattern）*：高频周期性纹理在远距离透视缩小时折叠出的低频条纹图案；(iii) *时间走样（Temporal Aliasing）*：高速旋转的车轮辐条在帧率采样不足时呈现倒转错觉，或亚像素高光在相机微移时剧烈闪烁（Fireflies / Shimmering）。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 左图：过采样 f_s > 2 f_max，频谱分离
    rect((0.2, 0.3), (6.6, 4.4), radius: 0.12, fill: softbg, stroke: 0.8pt + gray.lighten(20%))
    content((3.4, 4.05), text(size: 8pt, weight: "bold", fill: accent.darken(15%))[奈奎斯特充分采样（$f_s > 2 f_"max"$，无混叠）])

    line((0.6, 1.1), (6.2, 1.1), mark: (end: ">"), stroke: 0.8pt + ink)
    line((3.4, 0.8), (3.4, 3.6), mark: (end: ">"), stroke: 0.8pt + ink)
    content((6.0, 0.78), text(size: 7pt)[$xi$])
    content((3.78, 3.5), text(size: 7pt)[$hat(f)_s (xi)$])

    // 中心基带 (k=0) 与两侧副本 (k=-1, +1)
    line((2.5, 1.1), (3.4, 2.8), (4.3, 1.1), close: true, fill: bluebg, stroke: 1.0pt + accent)
    line((0.8, 1.1), (1.5, 2.5), (2.2, 1.1), close: true, fill: softbg, stroke: 0.8pt + gray.darken(20%))
    line((4.6, 1.1), (5.3, 2.5), (6.0, 1.1), close: true, fill: softbg, stroke: 0.8pt + gray.darken(20%))

    // 理想低通盒滤波器框
    rect((2.35, 1.1), (4.45, 3.05), stroke: (dash: "dashed", paint: accent2, thickness: 0.9pt))
    content((3.4, 3.25), text(size: 7pt, fill: accent2.darken(15%))[理想低通门 $[-f_s/2, f_s/2]$])
    content((1.5, 0.78), text(size: 7pt)[$-f_s$])
    content((3.4, 0.65), text(size: 7pt)[$0$])
    content((5.3, 0.78), text(size: 7pt)[$+f_s$])

    // 右图：欠采样 f_s < 2 f_max，频谱混叠折叠
    rect((7.0, 0.3), (13.6, 4.4), radius: 0.12, fill: softbg, stroke: 0.8pt + gray.lighten(20%))
    content((10.3, 4.05), text(size: 8pt, weight: "bold", fill: warn.darken(10%))[欠采样（$f_s < 2 f_"max"$，频谱重叠走样）])

    line((7.4, 1.1), (13.2, 1.1), mark: (end: ">"), stroke: 0.8pt + ink)
    line((10.3, 0.8), (10.3, 3.6), mark: (end: ">"), stroke: 0.8pt + ink)
    content((13.0, 0.78), text(size: 7pt)[$xi$])

    // 宽频谱互相交叠
    line((8.9, 1.1), (10.3, 2.8), (11.7, 1.1), close: true, fill: bluebg, stroke: 1.0pt + accent)
    line((7.6, 1.1), (8.9, 2.6), (10.2, 1.1), close: true, stroke: 0.9pt + warn)
    line((10.4, 1.1), (11.7, 2.6), (13.0, 1.1), close: true, stroke: 0.9pt + warn)

    // 混叠三角形高亮区
    line((8.9, 1.1), (9.58, 1.92), (10.2, 1.1), close: true, fill: redbg, stroke: 0.8pt + warn)
    line((10.4, 1.1), (11.02, 1.92), (11.7, 1.1), close: true, fill: redbg, stroke: 0.8pt + warn)
    content((10.3, 3.2), text(size: 7.2pt, fill: warn.darken(15%))[红色混叠区：高频折叠伪装为低频摩尔纹])
    content((8.9, 0.78), text(size: 7pt)[$-f_s$])
    content((10.3, 0.65), text(size: 7pt)[$0$])
    content((11.7, 0.78), text(size: 7pt)[$+f_s$])
  })),
  caption: [采样过程的频域周期延拓机理。左图满足奈奎斯特条件 $f_s > 2 f_"max"$，可通过低通滤波器完美剥离基带；右图因采样率不足导致相邻频谱副本侵入基带并发生混叠（红色区域），形成不可逆走样 @shannon1949communication。],
) <fig:ch03-aliasing>

@fig:ch03-aliasing 直观展示了频谱延拓与重叠机制。据此，消除或抑制走样仅有两条正交途径：(1) *提高有效采样率 $f_s$*（如超级采样抗锯齿 SSAA、多重采样 MSAA 或时间累积抗锯齿 TAA）；(2) *在采样前进行预滤波（Pre-filtering）以降低信号最高频率 $f_"max"$*，将超出 $f_s / 2$ 的高频分量提前滤除（如纹理 Mipmap 金字塔与 3DGS 的三维低通膨胀协方差滤波）。

== 重建滤波器、预滤波与随机采样抗锯齿底座 <sec:ch03-reconstruction>

获得离散采样点集 ${f(x_i, y_j)}$ 后，连续重建信号由离散样本与连续*重建滤波器（Reconstruction Filter）*核函数 $h(x, y)$ 的空间卷积给出：
$ tilde(f)(x, y) = (f_s * h)(x, y) = sum_i sum_j f(x_i, y_j) h(x - x_i, y - y_j). $ <eq:ch03-recon>
为保证常数亮度区域重建后不出现水波纹明暗跳变，重建核必须满足*单位分解性质（Partition of Unity）*：对任意连续位置 $x$，恒有 $sum_(i=-oo)^(+oo) h(x - i) = 1$。

=== 经典重建核与 Mitchell-Netravali 三次滤波器族

理想低通矩形滤波器在空间域对应无穷支撑的归一化正弦基函数 $"sinc"(x) = frac(sin(pi x), pi x)$。然而 $"sinc"(x)$ 存在两个致命工程缺陷：一是支撑域无穷大（按 $1/x$ 缓慢衰减），无法在有限窗口内截断计算；二是其负旁瓣（Negative Lobes）在强对比度阶跃边缘处会引发吉布斯（Gibbs）振铃伪影（Ringing / Overshoot）并产生非物理的负辐射度。

因此，实际渲染器普遍采用紧支撑（Compactly Supported）分段多项式或截断高斯核：
1. *盒式滤波器（Box Filter）*：$h_"box" (x) = 1$（当 $|x| <= 1/2$），其余为 $0$。它等价于对像素正方形内所有样本取算术平均，但在频域为缓慢衰减的 $"sinc"(xi)$，存在严重的频谱泄漏与块状走样。
2. *帐篷/双线性滤波器（Tent / Triangle Filter）*：$h_"tent" (x) = max(0, 1 - |x|)$（支撑半径为 $1$），由两个盒式滤波器自卷积得到，频域按 $"sinc"^2 (xi)$ 衰减，消除了零阶不连续性。
3. *Mitchell-Netravali 参数化三次滤波器族* @mitchell1988reconstruction：在支撑区间 $|x| < 2$ 上定义为带有两个自由参数 $(B, C)$ 的对称分段三次多项式（满足 $C^1$ 连续性与单位分解）：
   $ h_"MN" (x) = frac(1, 6) cases(
     (12 - 9B - 6C)|x|^3 + (-18 + 12B + 6C)|x|^2 + (6 - 2B) & quad |x| < 1,
     (-B - 6C)|x|^3 + (6B + 30C)|x|^2 + (-12B - 48C)|x| + (8B + 24C) & quad 1 <= |x| < 2,
     0 & quad |x| >= 2
   ) $ <eq:ch03-mitchell>
   Mitchell 与 Netravali 通过大规模主观视觉实验证明：在模糊（Blurring）、各向异性与振铃（Ringing）之间取得最优视觉平衡的黄金参数曲线为 $B + 2C = 1$，特别是 *$B = 1/3, C = 1/3$*（即标准 Mitchell 核，被 PBRT @pharr2023pbrt 等离线渲染器选作默认滤波器）；而当 $B = 0, C = 0.5$ 时则退化为经典的 Catmull-Rom 插值样条。

=== 随机采样（Stochastic Sampling）：把结构化走样转化为高频蓝噪声

在光线追踪与体积积分中，我们无法在采样前对任意未知的三维几何可见性函数做解析预滤波。若采用规则网格（Regular Grid）投射光线，周期性的狄拉克梳采样必然产生令人类视觉高度敏感的规则锯齿和摩尔条纹。

Cook 在 1986 年奠基性的《计算机图形学中的随机采样》@cook1986stochastic 中揭示了一个深刻的感知原理：人类视网膜视锥细胞本身并非规则晶格，而是遵循具有最小间距约束的*泊松盘分布（Poisson Disk Distribution）*。当我们用非均匀随机点过程替代规则晶格采样时，频域中原本位于 $k f_s$ 处的尖锐狄拉克冲激刺被均匀打散为连续平坦的宽带本底——*结构化低频走样（Aliasing）被转化为人类视觉系统极易容忍的高频随机噪声（Noise）*！工程上最常用的是*分层抖动采样（Stratified / Jittered Sampling）*：将单个像素均匀划分为 $M times M$ 个子网格（Strata），在每个子格 $(u, v) in {0, dots, M-1}^2$ 内独立生成均匀随机数 $(xi_1, xi_2) in [0, 1)^2$，采样坐标取为：
$ x_(u, v) = frac(u + xi_1, M), quad y_(u, v) = frac(v + xi_2, M). $ <eq:ch03-stratified>
分层采样既杜绝了纯均匀随机采样（Monte Carlo）的样本聚团（Clumping）现象，又保持了高频蓝噪声频谱特性，使积分方差以比纯随机采样更快的速率收敛。

== 辐射度量学核心物理量：通量、辐照度与辐射亮度 <sec:ch03-radiometry>

为了使渲染算子具备严格的物理可解释性，图形学采用*辐射度量学（Radiometry）*作为度量电磁辐射能量的数学框架 @nicodemus1977geometrical @pharr2023pbrt。在几何光学极限下（忽略波动衍射与偏振），光能在空间、时间、面积与方向维度上的微分密度构成了五大基础物理量。

=== 微分立体角（Differential Solid Angle）

在二维平面上，弧度（Radian）定义为圆弧长除以半径 $theta = l / r$（整圆为 $2 pi$）。推广至三维空间，以点 $bold(x)$ 为球心，任意三维锥体在半径为 $r$ 的球面上截出的球面面积 $A$ 与 $r^2$ 之比定义为*立体角（Solid Angle）* $Omega = A / r^2$，单位为*球面度（Steradian, $"sr"$）*，整个单位球面 $SS^2$ 对应的立体角为 $4 pi "sr"$，上半球面 $Omega^+$ 为 $2 pi "sr"$。

在球坐标系 $(theta, phi)$ 下（天顶角 $theta in [0, pi]$ 为方向向量 $omega$ 与表面法线 $bold(n)$ 的夹角，方位角 $phi in [0, 2 pi)$），单位球面上无穷小矩形微元的边长分别为 $dif theta$ 与 $sin theta dif phi$；若空间远处有一面积微元 $dif A$，其表面法线与观测连线的夹角为 $theta$，则*微分立体角 $dif omega$* 的两种等价计算式为：
$ dif omega = sin theta dif theta dif phi = frac(dif A cos theta, r^2). $ <eq:ch03-solid-angle>

=== 辐射度量学五大基本量严格定义

设微小时间间隔 $dif t$ 内传输的辐射总能量（Radiant Energy）为 $dif Q$（单位：焦耳 $"J"$），则单位时间内的辐射能量即为*辐射通量（Radiant Flux / Power）*：
$ Phi = frac(dif Q, dif t) quad ["单位：瓦特" "W" = "J/s"]. $ <eq:ch03-flux>
对辐射通量 $Phi$ 分别关于“立体角”、“面积”以及“投影面积 × 立体角”求偏导，即得刻画点光源、面接收器与空间光线束的三大核心密度量 @nicodemus1977geometrical：

#definition(title: [辐射强度、辐照度与辐射亮度（Intensity, Irradiance & Radiance）])[
  1. *辐射强度（Radiant Intensity）* $I(omega)$：点光源在单位立体角方向上发射的辐射通量密度：
     $ I(omega) = frac(dif Phi, dif omega) quad ["单位：" "W" dot "sr"^(-1)]. $ <eq:ch03-intensity>
  2. *辐照度（Irradiance）* $E(bold(x))$ 与 *辐射出射度（Radiosity）* $M(bold(x))$：表面点 $bold(x)$ 处单位真实面积接收（$E$）或向外发射（$M$）的辐射通量密度：
     $ E(bold(x)) = frac(dif Phi(bold(x)), dif A) quad ["单位：" "W" dot "m"^(-2)]. $ <eq:ch03-irradiance>
  3. *辐射亮度（Radiance）* $L(bold(x), omega)$：空间点 $bold(x)$ 沿方向 $omega$ 在*单位垂直投影面积（$dif A^perp = dif A cos theta$）*、*单位立体角（$dif omega$）*内传输的二阶微分辐射通量密度：
     $ L(bold(x), omega) = frac(dif^2 Phi(bold(x), omega), dif A cos theta dif omega) quad ["单位：" "W" dot "m"^(-2) dot "sr"^(-1)], $ <eq:ch03-radiance>
     其中 $theta$ 为方向 $omega$ 与表面法线 $bold(n)$ 的夹角，$cos theta = |bold(n) dot omega|$ 为 Lambert 余弦投影因子。
]

为什么在渲染管线与神经辐射场（NeRF）中，每条光线携带和追踪的基本物理量是*辐射亮度 $L(bold(x), omega)$* 而非通量或辐照度？下面的核心定理给出了答案。

#theorem(title: [真空光线辐射亮度守恒定理与辐照度半球积分 @nicodemus1977geometrical @pharr2023pbrt])[
  (i) *沿直线传播的不变性*：在无散射、无吸收的真空（或均匀透明介质）中，辐射亮度沿任意几何光线方向保持严格恒定，不随传播距离 $r$ 衰减：
  $ L(bold(x)_1, omega) = L(bold(x)_2, omega), quad forall bold(x)_2 = bold(x)_1 + r omega. $ <eq:ch03-invariance>
  (ii) *辐照度—辐射亮度积分关系*：表面点 $bold(x)$ 接收的总辐照度 $E(bold(x))$ 等于入射辐射亮度 $L_i (bold(x), omega_i)$ 乘以余弦因子在可见上半球面 $Omega^+$ 上的积分：
  $ E(bold(x)) = integral_(Omega^+) L_i (bold(x), omega_i) cos theta_i dif omega_i = integral_0^(2 pi) integral_0^(pi / 2) L_i (bold(x), theta_i, phi_i) cos theta_i sin theta_i dif theta_i dif phi_i. $ <eq:ch03-irradiance-integral>
]

#proof[
  (i) 考虑真空中沿连线方向 $omega$ 相距为 $r$ 的两个微小面元 $dif A_1$（位于 $bold(x)_1$，法线夹角 $theta_1$）与 $dif A_2$（位于 $bold(x)_2$，法线夹角 $theta_2$）构成的光束能量管（如 @fig:ch03-radiometry 右侧所示）。从 $dif A_1$ 位置看，$dif A_2$ 张成的微分立体角为 $dif omega_1 = frac(dif A_2 cos theta_2, r^2)$；反过来，从 $dif A_2$ 位置看，$dif A_1$ 张成的微分立体角为 $dif omega_2 = frac(dif A_1 cos theta_1, r^2)$。根据 @eq:ch03-radiance，由 $dif A_1$ 发出并穿过 $dif A_2$ 的二阶微分通量为 $dif^2 Phi_1 = L(bold(x)_1, omega) dif A_1 cos theta_1 dif omega_1$；而 $dif A_2$ 在立体角 $dif omega_2$ 内接收的微分通量为 $dif^2 Phi_2 = L(bold(x)_2, omega) dif A_2 cos theta_2 dif omega_2$。由真空能量守恒 $dif^2 Phi_1 = dif^2 Phi_2$，代入 $dif omega_1, dif omega_2$ 的几何表达式：
  $ L(bold(x)_1, omega) frac(dif A_1 cos theta_1 dif A_2 cos theta_2, r^2) = L(bold(x)_2, omega) frac(dif A_2 cos theta_2 dif A_1 cos theta_1, r^2). $
  两边约去对称几何吞吐量微元 $dif G = frac(dif A_1 cos theta_1 dif A_2 cos theta_2, r^2)$，即证 $L(bold(x)_1, omega) = L(bold(x)_2, omega)$！这正是为什么我们看到一堵均匀发光的墙面时，无论站在 $1 "m"$ 还是 $10 "m"$ 处，墙面在视网膜单个感光单元上的主观明暗度（正比于 Radiance）保持不变（距离变远虽然总通量按 $1/r^2$ 减小，但墙面占据的视网膜立体角同样按 $1/r^2$ 缩小，二者精确抵消）。
  (ii) 将 @eq:ch03-radiance 改写为 $dif^2 Phi = L_i (bold(x), omega_i) cos theta_i dif omega_i dif A$，两边同除以 $dif A$ 并对上半球面全部入射立体角 $omega_i in Omega^+$ 积分，立即得到 @eq:ch03-irradiance-integral。特别地，若上半球入射光为恒定各向同性环境光 $L_i (bold(x), omega_i) equiv L_0$，由于 $integral_0^(2pi) dif phi integral_0^(pi/2) cos theta sin theta dif theta = 2 pi dot frac(1, 2) = pi$，有经典朗伯恒等式 $E = pi L_0$（而非 $2 pi L_0$！）。
]

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 左图：表面微元 dA、投影面积 dA cos theta 与微分立体角 d omega
    rect((0.2, 0.3), (6.5, 4.5), radius: 0.12, fill: softbg, stroke: 0.8pt + gray.lighten(20%))
    content((3.35, 4.15), text(size: 8pt, weight: "bold", fill: accent.darken(15%))[辐射亮度 $L(bold(x), omega)$ 的微分几何定义])

    // 底部表面微元 dA
    line((1.2, 1.0), (3.6, 1.0), (4.1, 1.6), (1.7, 1.6), close: true, fill: bluebg, stroke: 0.9pt + accent)
    content((2.6, 0.7), text(size: 7.2pt)[表面微元 $dif A$])

    // 法线 n 与出射方向 omega
    line((2.65, 1.3), (2.65, 3.6), mark: (end: ">"), stroke: 0.9pt + accent)
    content((2.25, 3.45), text(size: 7.5pt)[法线 $bold(n)$])
    line((2.65, 1.3), (5.2, 3.3), mark: (end: ">"), stroke: 1.0pt + accent2)
    content((5.55, 3.45), text(size: 7.5pt, fill: accent2.darken(15%))[方向 $omega$])

    // 立体角锥与垂直投影面 dA cos theta
    line((2.65, 1.3), (4.6, 3.6), stroke: (dash: "dashed", paint: accent2, thickness: 0.7pt))
    line((2.65, 1.3), (5.5, 2.7), stroke: (dash: "dashed", paint: accent2, thickness: 0.7pt))
    content((4.6, 2.2), text(size: 7pt, fill: accent2.darken(10%))[立体角 $dif omega$])
    content((3.15, 2.25), text(size: 7pt)[$theta$])
    line((2.1, 1.95), (3.2, 0.65), stroke: 1.1pt + warn)
    content((4.65, 1.15), text(size: 7pt, fill: warn.darken(10%))[投影面 $dif A cos theta$])

    // 右图：真空光束能量管守恒 L(x1, w) = L(x2, w)
    rect((6.9, 0.3), (13.6, 4.5), radius: 0.12, fill: softbg, stroke: 0.8pt + gray.lighten(20%))
    content((10.25, 4.15), text(size: 8pt, weight: "bold", fill: accent2.darken(15%))[真空光线能量管与辐射亮度不变性])

    // 左端面元 dA1
    line((7.6, 1.2), (8.2, 2.8), stroke: 1.5pt + accent)
    content((7.55, 0.85), text(size: 7.2pt)[$dif A_1 (bold(x)_1)$])
    line((7.9, 2.0), (8.8, 2.3), mark: (end: ">"), stroke: 0.8pt + accent)
    content((8.55, 2.6), text(size: 7pt)[$bold(n)_1$])

    // 右端面元 dA2
    line((12.2, 1.5), (12.7, 3.2), stroke: 1.5pt + accent2)
    content((12.5, 1.15), text(size: 7.2pt)[$dif A_2 (bold(x)_2)$])
    line((12.45, 2.35), (11.55, 2.55), mark: (end: ">"), stroke: 0.8pt + accent2)
    content((11.65, 2.85), text(size: 7pt)[$bold(n)_2$])

    // 光束管上下边界与中心光线
    line((7.6, 1.2), (12.2, 1.5), stroke: (dash: "dashed", paint: gray.darken(20%), thickness: 0.7pt))
    line((8.2, 2.8), (12.7, 3.2), stroke: (dash: "dashed", paint: gray.darken(20%), thickness: 0.7pt))
    line((7.9, 2.0), (12.45, 2.35), mark: (end: ">"), stroke: 1.1pt + warn)
    content((10.2, 1.75), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt)[距离 $r$，$L(bold(x)_1, omega) = L(bold(x)_2, omega)$])
    content((10.2, 3.45), text(size: 7.2pt)[几何吞吐微元 $dif G = (dif A_1 cos theta_1 dif A_2 cos theta_2) / r^2$])
  })),
  caption: [辐射亮度 $L(bold(x), omega)$ 的局部投影几何定义（左）与真空中沿直线传播的辐射亮度守恒定理示意图（右）。由于两端面元相互张成的立体角与距离平方 $r^2$ 成反比，辐射亮度沿光线恒定不变 @nicodemus1977geometrical。],
) <fig:ch03-radiometry>

#figure(
  table(
    columns: (1.5cm, 3.2cm, 3.3cm, 2.5cm, 3.5cm),
    align: (center, left, center, center, left),
    [*符号*], [*辐射度量名称*], [*微分定义式*], [*SI 物理单位*], [*对应光度学量（Photometry）*],
    [$Q$], [辐射能量 (Radiant Energy)], [$Q$], [$"J"$（焦耳）], [光能量 $Q_v$（$"lm" dot "s"$）],
    [$Phi$], [辐射通量 (Radiant Flux)], [$dif Q / dif t$], [$"W"$（瓦特）], [光通量 $Phi_v$（流明 $"lm"$）],
    [$I(omega)$], [辐射强度 (Radiant Intensity)], [$dif Phi / dif omega$], [$"W" dot "sr"^(-1)$], [发光强度 $I_v$（坎德拉 $"cd" = "lm/sr"$）],
    [$E(bold(x))$], [辐照度 (Irradiance)], [$dif Phi / dif A$], [$"W" dot "m"^(-2)$], [光照度 $E_v$（勒克斯 $"lx" = "lm/m"^2$）],
    [$L(bold(x), omega)$], [辐射亮度 (Radiance)], [$frac(dif^2 Phi, dif A cos theta dif omega)$], [$"W" dot "m"^(-2) dot "sr"^(-1)$], [光亮度 $L_v$（尼特 $"nit" = "cd/m"^2$）],
  ),
  caption: [辐射度量学五大核心物理量的符号、微分定义、国际单位制（SI）及光度学感知对应表 @pharr2023pbrt。],
) <tab:ch03-radiometric-quantities>

@tab:ch03-radiometric-quantities 汇总了全书反复使用的辐射度量学符号体系。在后续章节中，点光源的强度由 $I$ 度量，表面微元接收的总光能由 $E$ 度量，而相机像素与光线追踪器采样的核心函数始终是辐射亮度 $L(bold(x), omega)$。

== 光度学、CIE 色度空间、sRGB 伽马校正与色调映射 <sec:ch03-color>

物理世界中的电磁辐射本质上是关于波长 $lambda in [380 "nm", 780 "nm"]$ 的连续*光谱功率分布（Spectral Power Distribution, SPD）* $L_lambda (lambda)$。*光度学（Photometry）*通过将物理辐射量按人类视网膜明视觉（Photopic）标准光视效率函数 $V(lambda)$（峰值位于绿光 $lambda = 555 "nm"$，最大转换系数 $K_m = 683 "lm/W"$）加权积分，将辐射亮度转化为人眼感知的*光亮度（Luminance，单位 $"nit" = "cd/m"^2$）*：
$ L_v = K_m integral_(380 "nm")^(780 "nm") L_lambda (lambda) V(lambda) dif lambda. $ <eq:ch03-luminance>

=== CIE 1931 XYZ 三刺激值与线性色度空间

人类视网膜拥有三类对长波（L）、中波（M）、短波（S）敏感的视锥细胞。这种三维投影机制意味着无穷维连续光谱 $L_lambda (lambda)$ 被压缩为三维感知空间——不同光谱分布完全可能激发相同的三刺激响应，这一现象称为*同色异谱（Metamerism）*，也是现代显示器仅用红（R）、绿（G）、蓝（B）三原色即可复现万千色彩的生理学基础。国际照明委员会（CIE）于 1931 年确立了标准观察者颜色匹配函数（Color Matching Functions）$bar(x)(lambda), bar(y)(lambda), bar(z)(lambda)$（其中 $bar(y)(lambda) equiv V(lambda)$ 直接代表感知光亮度），将任意光谱映射为与设备无关的 *CIE XYZ 三刺激值*：
$ X = integral L_lambda (lambda) bar(x)(lambda) dif lambda, quad Y = integral L_lambda (lambda) bar(y)(lambda) dif lambda, quad Z = integral L_lambda (lambda) bar(z)(lambda) dif lambda. $ <eq:ch03-cie-xyz>
对总刺激量归一化后得到的二维色度坐标 $(x, y) = (frac(X, X + Y + Z), frac(Y, X + Y + Z))$ 构成了著名的马蹄形 *CIE 1931 色度图（Chromaticity Diagram）*。任何基于三原色加法混色的物理显示色域（如 sRGB / Rec.709 或广色域 DCI-P3 / Rec.2020）在 $(x, y)$ 平面上都表现为一个以三原色色度点为顶点的凸三角形，且 CIE XYZ 与线性 sRGB 之间满足固定的 $3 times 3$ 线性矩阵变换（其中从线性 sRGB 计算相对光亮度 $Y$ 的标准权重为 $Y = 0.2126 R_"lin" + 0.7152 G_"lin" + 0.0722 B_"lin"$）。

=== 韦伯—费希纳定律与 sRGB 伽马校正（Gamma Correction）

根据心理物理学韦伯—费希纳定律（Weber-Fechner Law），人眼对亮度变化的感知大致呈对数/幂律关系：我们对暗部微弱的光强变化极其敏感（如从 $0.01$ 到 $0.02$），而对亮部同样的绝对物理能量增量（如从 $0.91$ 到 $0.92$）几乎无法察觉。如果将物理线性辐射度 $C_"lin" in [0, 1]$ 直接均匀量化为 8 位整数（$0..255$），会导致暗部出现严重的阶梯状色彩断层（Banding），而亮部则浪费了大量编码码字。

为此，工业界制定的 *sRGB 标准*采用近似幂函数 $C_"srgb" approx C_"lin"^(1 / 2.2)$ 的电光转换函数（精确形式由暗部线性段与幂指数 $1 / 2.4$ 拼接而成）对图像进行*伽马编码（Gamma Encoding）*存储；显示器硬件在显示时再施以 $C_"lin" approx C_"srgb"^(2.2)$ 解码还原为物理光强。这引出了渲染与神经图形学的一条黄金铁律：
- *一切物理光照积分、BRDF 着色、半透明 $alpha$ 混合、Mipmap 滤波与 NeRF/3DGS 体渲染合成，必须严格在线性空间（Linear RGB）中执行！*
- 若错误地在非线性 sRGB 空间直接相加两盏灯光，实际上计算的是 $(L_1^(1/2.2) + L_2^(1/2.2))^(2.2) != L_1 + L_2$，严重违背能量守恒定律并导致高光过曝与边缘发黑。

=== 高动态范围（HDR）色调映射（Tone Mapping）

真实自然界的辐射亮度跨度高达 $10^8 : 1$（正午日面约 $10^9 "nit"$，星光暗处约 $10^(-3) "nit"$），而标准动态范围（LDR / SDR）仅能表达 $[0, 1]$ 区间。将无上界的物理线性高动态范围辐射度 $L_"hdr" in [0, oo)$ 压缩至 $[0, 1]$ 显示区间的非线性算子称为*色调映射（Tone Mapping）*：
1. *Reinhard 全局色调映射算子* @reinhard2002photographic：借鉴胶片暗房曝光特性，通过简单的有理函数将 $[0, oo)$ 平滑压缩至 $[0, 1)$（常配合场景最高白点 $L_"white"$ 以允许极亮高光饱和）：
   $ L_"ldr" = frac(L_"hdr", 1 + L_"hdr"), quad "或扩展式" quad L_"ldr" = frac(L_"hdr" (1 + L_"hdr" / L_"white"^2), 1 + L_"hdr"). $ <eq:ch03-reinhard>
2. *ACES（学院色彩编码系统）电影级 S 型曲线*：现代游戏引擎与影视后期广泛采用 Narkowicz 拟合的 ACES Filmic 有理逼近曲线，同时提供自然的暗部趾部（Toe）对比度提升与亮部肩部（Shoulder）柔和滚降。

下面给出一段完整的 Python 代码，实现从物理线性 HDR 辐射度经 ACES / Reinhard 色调映射、CIE 亮度保持到精确分段 sRGB 编码的后处理管线：

```python
import numpy as np

def tone_map_aces(rgb_hdr: np.ndarray, exposure: float = 1.0) -> np.ndarray:
    """ACES Filmic 电影级色调映射算子 (Narkowicz 2015 有理分式拟合)"""
    x = np.maximum(0.0, rgb_hdr * exposure)
    a, b, c, d, e = 2.51, 0.03, 2.43, 0.59, 0.14
    return np.clip((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0)

def linear_to_srgb(rgb_lin: np.ndarray) -> np.ndarray:
    """IEC 61966-2-1 标准分段线性到 sRGB 非线性伽马转换"""
    x = np.clip(rgb_lin, 0.0, 1.0)
    return np.where(x <= 0.0031308, 12.92 * x, 1.055 * np.power(np.maximum(x, 1e-10), 1.0 / 2.4) - 0.055)
```

== 现代演进与广色域/光谱渲染管线 <sec:ch03-frontier>

随着高亮度 Mini-LED / OLED 显示终端与神经辐射场重建的普及，信号采样、辐射度量与色彩管线正在经历三大前沿变革：
- 【已有成果】*全链路 ACEScg / Rec.2020 广色域与原生 HDR 显示管线*：传统 sRGB 色域仅覆盖人眼可见色域（CIE 1931）的约 $35.9%$；现代工业级渲染器与影视管线已全面转向以 *ACEScg（AP1 原色）*作为内部线性渲染工作空间，并在终端通过 PQ（Perceptual Quantizer, SMPTE ST 2084）转换函数直接输出 $1000 "nit"$ 以上的原生 HDR 信号。
- 【已有成果】*主波长光谱采样（Hero Wavelength Spectral Sampling）*：三通道 RGB 渲染无法精确模拟薄膜干涉（肥皂泡虹彩）、棱镜色散（Dispersion）与荧光效应；现代离线渲染器（如 PBRT-v4 @pharr2023pbrt 与 Weta Manuka）采用光谱蒙特卡洛追踪，每条路径随机抽取一个主波长 $lambda_1$ 并捆绑四个等间距相伴波长协同遍历 BVH，以极小的额外开销实现了全光谱无偏渲染。
- 【本书推断】*面向未知传感器响应的可微色彩与神经抗锯齿统一建模*：在真实世界多视角重建（如 RawNeRF 与 Mip-Splatting）中，输入照片往往带有未知的自动白平衡、ISO 散粒噪声、非线性相机响应曲线（CRF）以及焦距变化导致的采样率跳变；将重建核预滤波（三维空间 EWA 低通滤波）与可微相机成像管线（ISP）联合纳入逆向优化闭环，是实现跨设备鲁棒神经重建的核心基石。

#keybox(title: [本章要点])[
  1. *采样定理与抗锯齿*：空间点采样对应频域周期延拓；当采样率 $f_s < 2 f_"max"$ 时高频混叠折叠为低频走样；预滤波（Mipmap/3D 低通核）通过削减 $f_"max"$ 消除混叠，随机分层采样 @cook1986stochastic 则将规则锯齿转化为视觉友好的高频蓝噪声。
  2. *辐射亮度守恒*：辐射亮度 $L(bold(x), omega) = frac(dif^2 Phi, dif A cos theta dif omega)$ 度量单位投影面积、单位立体角内的通量密度；它在真空直线传播中严格守恒，且表面辐照度满足半球余弦积分 $E = integral_(Omega^+) L_i cos theta_i dif omega_i$。
  3. *线性空间着色铁律*：sRGB 伽马编码（$gamma approx 2.2$）是为了匹配人眼韦伯—费希纳非线性感知并优化 8 位量化效率；一切光照积分、BRDF 计算、纹理插值与可微体渲染必须在线性辐射度空间执行，仅在最终输出前执行色调映射与伽马编码。
]
