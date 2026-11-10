#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 实时全局光照近似：阴影、环境光与屏幕空间技术

第 5 章介绍的局部光照模型假定着色点 $bold(x)$ 与光源之间不存在任何遮挡物，且完全忽略了场景中其他表面反射过来的间接光。然而在真实物理世界中，光线被物体阻挡会投下具有半影过渡的软阴影（Soft Shadows），天空穹顶的漫射光会在凹陷角落产生柔和的明暗遮蔽（Ambient Occlusion），而光滑地面则会映出周围物体的倒影。这些跨越单个图元边界、依赖全局场景几何的光照效应统称为*全局光照*（Global Illumination, GI）。

在离线路径追踪（第 8 章）问世并进入实时硬件之前，如何在严苛的每帧 16.6 毫秒（60 FPS）预算内逼真地近似全局阴影、环境光与单次/多次反射，构成了过去三十年实时渲染算法创新的主线。本章首先从 Williams 的经典阴影贴图出发，剖析深度走样与斜率偏移，推导百分比渐近软阴影（PCSS）与基于切比雪夫不等式的方差阴影贴图（VSM）（@sec:ch06-shadows）；其次探讨大尺度开放世界中的级联阴影贴图（CSM）对数切分与虚拟阴影贴图架构（@sec:ch06-csm）；随后引入球谐函数（SH）正交基，详述环境光低频卷积与预计算辐射传输（PRT）的内积加速原理及 Python 实现（@sec:ch06-prt）；接着剖析屏幕空间环境光遮蔽（SSAO / GTAO）、屏幕空间反射（SSR）与辐射度探针体积（@sec:ch06-ssgi）；最后在前沿视野中推导时空水塘重采样（ReSTIR）如何将百万动态光源与实时路径追踪推向工业落地（@sec:ch06-frontier）。

== 实时阴影：Shadow Mapping、自遮挡走样、PCF 与软阴影（PCSS / VSM） <sec:ch06-shadows>

在光栅化管线中，判断着色点 $bold(x)$ 是否能「看见」光源点 $bold(p)_"light"$（即可见性函数 $V(bold(x) <-> bold(p)_"light") in {0, 1}$），不能直接发射一条阴影射线，因为光栅化器没有全局场景加速结构。1978 年，Lance Williams 提出了极为巧妙的图像空间两趟算法——*阴影贴图*（Shadow Mapping）@williams1978casting，将「点与光源之间的可见性」转化为「从光源视角出发的 Z-Buffer 深度比较」：
1. *第一趟（Light Pass，生成阴影贴图）*：将虚拟相机置于光源位置，以光源的视图—投影矩阵 $bold(M)_"light"$ 光栅化整个场景，不计算任何颜色，仅将最前端片元的深度值写入一张分辨率为 $W_s times H_s$ 的深度纹理 $z_"map"(bold(u))$。
2. *第二趟（Camera Pass，阴影查询与着色）*：从主相机视角正常渲染场景。对于每个可见片元的世界空间坐标 $bold(x)$，通过矩阵变换 $bold(q)_L = bold(M)_"light" vec(bold(x), 1)$ 并执行透视除法，得到该点在光源裁剪空间中的二维纹理坐标 $bold(u)_L in [0, 1]^2$ 以及它距离光源的真实深度 $d_"receiver"$（接收点深度）。若 $d_"receiver" > z_"map"(bold(u)_L)$，说明在光源到 $bold(x)$ 的连线上存在更近的遮挡物（Blocker），判定 $V = 0$（处于阴影中）；否则判定 $V = 1$（被照亮）。

=== 自遮挡走样（Shadow Acne）、斜率深度偏移与 PCF 滤波

若直接按严格不等式 $d_"receiver" > z_"map"(bold(u)_L)$ 执行测试，受光表面会出现大面积黑白相间的摩尔条纹，称为*阴影粉刺*（Shadow Acne）。其几何成因在于：阴影贴图的纹素是离散的，当表面法线 $bold(n)$ 与光线方向 $omega_i$ 存在夹角 $theta$ 时，单个阴影纹素投射到倾斜表面上覆盖了一段具有深度跨度 $Delta z approx s_"texel" tan theta$ 的斜面；纹素中心记录的单一深度 $z_"map"$ 会比斜面上半侧的接收点深度 $d_"receiver"$ 更浅，导致表面错误地「遮挡了自己」。

为消除自遮挡走样，工程上引入随入射倾角自适应调整的*斜率尺度深度偏移*（Slope-Scale Depth Bias）：
$ epsilon(theta) = b_0 + b_1 tan theta = b_0 + b_1 (sqrt(1 - (bold(n) dot omega_i)^2))/(max(epsilon_0, bold(n) dot omega_i)), $ <eq:ch06-slope-bias>
将阴影判据放宽为 $d_"receiver" - epsilon(theta) > z_"map"(bold(u)_L)$。然而，若偏移量 $epsilon$ 过大，物体与地面接触处的阴影会向远离光源一侧退缩，产生仿佛物体脱离地面漂浮的*阴影悬浮瑕疵*（Peter-Panning）。

除了自遮挡，当相机靠近阴影边界时，阴影贴图有限的纹素分辨率会导致生硬的阶梯状锯齿。值得注意的是，我们*绝不能直接对阴影贴图 $z_"map"$ 做双线性插值或高斯模糊*——因为可见性判定算子 $H(d_"receiver" - z)$ 是非线性的阶跃函数，深度的平均再比较 $H(d_"receiver" - EE[z])$ 仍然只能输出非黑即白的 $0$ 或 $1$。正确的做法是 *百分比渐近滤波*（Percentage-Closer Filtering, PCF）：在片元着色器中对当前坐标 $bold(u)_L$ 周围邻域（如圆盘 Poisson Disk 分布）采集 $K$ 个深度样本 $z_"map"(bold(u)_L + delta bold(u)_k)$，先逐一执行二值深度比较，再对 $K$ 个比较结果求加权平均：
$ V_"PCF"(bold(x)) = (1)/(K) sum_(k=1)^K II(d_"receiver" - epsilon <= z_"map"(bold(u)_L + delta bold(u)_k)) in [0, 1]. $ <eq:ch06-pcf>

=== 百分比渐近软阴影（PCSS）与半影相似三角形推导

固定滤波半径的 PCF 只能将阴影边缘均匀模糊，无法反映真实面光源（Area Light）物理软阴影的核心特征——*接触硬化*（Contact Hardening）：遮挡物紧贴接收面处阴影极其锐利，而随着接收面远离遮挡物，半影（Penumbra）宽度线性展宽。2005 年，Randima Fernando 提出了经典的*百分比渐近软阴影*（Percentage-Closer Soft Shadows, PCSS）三步算法@fernando2005pcss（几何构造见 @fig:ch06-pcss）：
1. *遮挡物搜索（Blocker Search）*：在阴影贴图上以 $bold(u)_L$ 为中心、与光源尺寸成正比的窗口内采样，找出所有满足 $z_"map" < d_"receiver"$ 的有效遮挡样本，计算其*平均遮挡物深度* $d_"blocker"$（若无遮挡样本则直接提前返回全亮 $V = 1$）。
2. *半影宽度估计（Penumbra Estimation）*：将面光源（宽度 $w_"light"$）、平均遮挡平面（深度 $d_"blocker"$）与接收平面（深度 $d_"receiver"$）近似为三个平行平面。由 @fig:ch06-pcss 的对顶相似三角形比例关系，立即导出半影宽度公式：
   $ (w_"penumbra")/(d_"receiver" - d_"blocker") = (w_"light")/(d_"blocker") quad ==> quad w_"penumbra" = (d_"receiver" - d_"blocker")/(d_"blocker") w_"light". $ <eq:ch06-pcss>
3. *可变核 PCF 滤波*：以 $w_"penumbra"$ 作为滤波核半径执行 @eq:ch06-pcf 的 PCF 采样。当物体接触地面时 $d_"receiver" -> d_"blocker"$，由 @eq:ch06-pcss 知 $w_"penumbra" -> 0$，自然重现了接触硬化现象@fernando2005pcss。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 面光源平面 (顶层 y = 4.6)
    line((2.2, 4.6), (6.2, 4.6), stroke: 2.2pt + accent2)
    content((4.2, 4.95), text(size: 8pt, weight: "bold", fill: accent2)[面光源宽度 $w_"light"$])
    // 遮挡物平面 (中层 y = 2.6)
    line((4.2, 2.6), (8.2, 2.6), stroke: 2.2pt + ink)
    content((7.4, 2.95), text(size: 7.5pt, weight: "bold")[遮挡物（Blocker）])
    // 接收面平面 (底层 y = 0.6)
    line((1.2, 0.6), (11.5, 0.6), stroke: 1.5pt + accent)
    content((9.8, 0.25), text(size: 7.8pt, weight: "bold", fill: accent)[接收平面（Receiver）])

    // 半影极限光线 (左端 (2.2, 4.6) 过遮挡左缘 (4.2, 2.6) 到 (6.2, 0.6); 右端 (6.2, 4.6) 过遮挡左缘 (4.2, 2.6) 到 (2.2, 0.6))
    line((2.2, 4.6), (6.2, 0.6), stroke: (dash: "dashed", paint: accent2, thickness: 0.9pt))
    line((6.2, 4.6), (2.2, 0.6), stroke: (dash: "dashed", paint: accent2, thickness: 0.9pt))

    // 半影区域高亮
    rect((2.2, 0.52), (6.2, 0.68), fill: warn.lighten(30%), stroke: none)
    rect((6.2, 0.52), (10.5, 0.68), fill: gray.darken(20%), stroke: none)
    content((4.2, 0.25), text(size: 7.8pt, weight: "bold", fill: warn)[半影区 $w_"penumbra"$])
    content((8.1, 0.95), text(size: 7.3pt)[本影区（Umbra）])

    // 左侧深度尺寸标注
    line((0.8, 4.6), (0.8, 2.6), mark: (start: ">", end: ">"), stroke: 0.8pt + accent)
    content((0.8, 3.6), frame: "rect", fill: white, stroke: none, padding: 0.06, text(size: 7.3pt, fill: accent)[$d_"blocker"$])
    line((1.6, 4.6), (1.6, 0.6), mark: (start: ">", end: ">"), stroke: 0.8pt + accent)
    content((1.6, 1.6), frame: "rect", fill: white, stroke: none, padding: 0.06, text(size: 7.3pt, fill: accent)[$d_"receiver"$])

    // 右侧推导卡片
    rect((8.8, 2.2), (13.8, 4.7), fill: softbg, stroke: 0.8pt + accent, radius: 0.1)
    content((11.3, 4.25), text(size: 7.8pt, weight: "bold")[PCSS 三步软阴影管线])
    content((11.3, 3.65), text(size: 7.3pt)[① 搜索邻域求平均 $d_"blocker"$])
    content((11.3, 3.05), text(size: 7.3pt)[② 相似三角形算 $w_"penumbra"$])
    content((11.3, 2.5), text(size: 7.3pt)[③ 可变核半径 PCF 采样])
  })),
  caption: [PCSS（百分比渐近软阴影）的平行平面相似三角形几何模型。面光源左、右两端发出的极限光线穿过遮挡物边缘，在接收平面上围出宽度为 $w_"penumbra" = (d_"receiver" - d_"blocker") w_"light" \/ d_"blocker"$ 的半影过渡带。],
) <fig:ch06-pcss>

=== 方差阴影贴图（VSM）与单边切比雪夫不等式

PCSS 在半影较宽时需要每像素采集 32 至 64 个深度样本，仍无法直接利用硬件 Mipmap 或可分离高斯模糊进行预滤波。2006 年，William Donnelly 与 Andrew Lauritzen 提出了*方差阴影贴图*（Variance Shadow Maps, VSM）@donnelly2006variance，将确定性的深度比较巧妙转化为概率分布的尾部上界估计。

#theorem(title: [方差阴影贴图（VSM）与单边切比雪夫可见性上界])[
  设阴影贴图在 Light Pass 阶段同时记录深度的一阶矩 $M_1 = z$ 与二阶矩 $M_2 = z^2$。对这两张矩纹理在滤波核窗口内做线性预滤波（如硬件三线性 Mipmap、高斯模糊或积分图 SAT），得到局部深度分布的期望 $mu = EE[z] = hat(M)_1$ 与方差 $sigma^2 = EE[z^2] - (EE[z])^2 = hat(M)_2 - hat(M)_1^2$。对于深度为 $t = d_"receiver"$ 的接收点，当 $t > mu$ 时，局部遮挡物深度 $z >= t$（即接收点未被遮挡）的概率满足单边切比雪夫（Cantelli）不等式上界：
  $ PP(z >= t) <= p_"max"(t) = (sigma^2)/(sigma^2 + (t - mu)^2). $ <eq:ch06-vsm-chebyshev>
]

#proof[
  对任意实参数 $u > 0$，利用单调性与马尔可夫不等式可得：
  $ PP(z - mu >= t - mu) <= PP((z - mu + u)^2 >= (t - mu + u)^2) <= (EE[(z - mu + u)^2])/((t - mu + u)^2) = (sigma^2 + u^2)/((t - mu + u)^2). $
  对右端关于 $u > 0$ 求导并令导数为零，求得极小值点 $u^* = sigma^2 \/ (t - mu)$。将 $u^*$ 代回上式化简，即得单边切比雪夫紧上界 $p_"max"(t) = sigma^2 \/ (sigma^2 + (t - mu)^2)$。在单平面遮挡假设下，$p_"max"(t)$ 直接作为软阴影可见性 $V_"VSM"(bold(x))$ 的解析近似@donnelly2006variance。
]

VSM 的最大突破在于一阶矩 $M_1$ 与二阶矩 $M_2$ 都是*纯线性量*，因此可以毫无阻碍地使用硬件各向异性 Mipmap 与双趟可分离高斯模糊，以 $O(1)$ 的着色采样开销获得极其平滑的软阴影！其主要局限是当两个不同深度的遮挡物边缘重叠在同一个滤波窗口内时，方差 $sigma^2$ 会被剧烈拉大，导致后方本影区出现不自然的亮斑——称为*漏光瑕疵*（Light Bleeding），工程上常结合指数阴影贴图（ESM）或矩阴影贴图（MSM）予以抑制。

== 大场景阴影架构：级联阴影贴图（CSM）与虚拟阴影贴图 <sec:ch06-csm>

在广袤的开放世界场景中，相机视锥体从近裁剪面 $n = 0.1$ m 一直延伸至远裁剪面 $f = 2000$ m。若仅用单张阴影贴图覆盖整个视锥体，近处角色脚下 $1$ m 宽的地面只能分到寥寥几个纹素，产生严重的*透视走样*（Perspective Aliasing）。

=== 级联阴影贴图（CSM）与对数—均匀混合切分

*级联阴影贴图*（Cascaded Shadow Maps, CSM）将相机视锥体沿深度轴切分为 $K$ 个子视锥体（通常 $K = 4$），并为每个子视锥体独立渲染一张同分辨率（如 $2048 times 2048$）的紧密正交阴影贴图。如何确定切分平面深度 $n = z_0 < z_1 < dots.c < z_K = f$？
- 若按*均匀切分* $z_i^"uni" = n + (i \/ K)(f - n)$，近处子视锥依然过大，透视走样严重；
- 若按理论上使透视走样恒定的*对数切分* $z_i^"log" = n (f \/ n)^(i \/ K)$，第一级级联又会过度集中在相机鼻尖前几厘米处，造成纹素浪费。
因此，工业界标准方案采用*对数—均匀混合切分公式*（Practical Split Scheme）：
$ z_i = lambda n ((f)/(n))^(i \/ K) + (1 - lambda) (n + (i)/(K) (f - n)), quad i in {0, 1, dots, K}, $ <eq:ch06-csm-split>
其中混合权重通常取 $lambda in [0.7, 0.9]$。此外，当主相机平移或旋转时，若每帧紧贴子视锥重新计算光源正交包围盒，阴影贴图的纹素世界尺寸与相位会随帧发生微变，引发剧烈的阴影边缘闪烁（Shadow Shimmering）。稳定化 CSM 的铁律是：(1) 以子视锥的*固定半径外接球*决定正交投影宽高，使缩放比例对相机旋转完全不变；(2) 将光源正交投影中心在阴影纹素网格上做*整纹素取整对齐*（Texel Snapping），确保世界空间中静止物体的阴影纹素采样相位恒定不变。

=== 虚拟阴影贴图（Virtual Shadow Maps）

CSM 虽解决了大视野分辨率分配，但在微多边形场景中需要在每一帧将高模几何重复光栅化 $K$ 遍。现代引擎（如 Unreal Engine 5）进而演进出*虚拟阴影贴图*（Virtual Shadow Maps）：为每个光源建立高达 $16384 times 16384$ 的虚拟高分辨率深度表，将其划分为 $128 times 128$ 大小虚拟页（Page）；渲染器先分析当前帧屏幕 G-Buffer 的深度分布，*仅对屏幕可见像素实际命中的虚拟页分配物理显存并光栅化几何簇*，且对于静态几何体直接跨帧缓存复用物理页，实现了从厘米级近景到千米级远景的统一亚像素锐利阴影。

== 球谐函数（SH）正交基、环境光卷积与预计算辐射传输（PRT） <sec:ch06-prt>

除点光源与方向光外，真实场景时刻沐浴在来自整片天空与周围环境的无穷远全景入射光 $L_"env"(omega_i)$ 之中。对于理想漫反射表面，在无遮挡假设下，其出射辐照度（Irradiance）$E(bold(n))$ 是入射环境光与半余弦核 $hat(A)(theta_i) = max(0, cos theta_i)$ 在单位球面 $SS^2$ 上的积分：
$ E(bold(n)) = integral_(SS^2) L_"env"(omega_i) max(0, bold(n) dot omega_i) dif omega_i. $ <eq:ch06-irradiance-int>
若在每个像素处对一张高动态范围环境贴图（HDR Environment Map）实时暴力数值积分，计算量完全无法承受。如何在频域中紧致表示球面信号并瞬间完成球面卷积？

=== 实球谐函数正交基与 Ramamoorthi-Hanrahan 九系数定理

正如傅里叶级数是圆周或直线上平方可积函数的正交基，*球谐函数*（Spherical Harmonics, SH）是单位球面 $SS^2$ 上平方可积函数空间 $L^2(SS^2)$ 的完备标准正交基。在极角（天顶角）$theta in [0, pi]$ 与方位角 $phi in [0, 2 pi)$ 参数化下（对应单位向量 $omega = (sin theta cos phi, sin theta sin phi, cos theta)^top$），阶数（Band）为 $l >= 0$、次数为 $m in {-l, dots, l}$ 的*实球谐基函数* $Y_l^m (theta, phi)$ 由伴随勒让德多项式 $P_l^(|m|)(cos theta)$ 与三角函数耦合而成。前 3 阶（$l in {0, 1, 2}$，共计 $(2 + 1)^2 = 9$ 个基函数）在笛卡尔坐标 $(x, y, z) = omega in SS^2$ 下具有极其简洁的多项式解析式：
$ Y_0^0 = (1)/(2) sqrt((1)/(pi)), quad (Y_1^(-1), Y_1^0, Y_1^1) = sqrt((3)/(4 pi)) (y, z, x), $ <eq:ch06-sh-l01>
$ (Y_2^(-2), Y_2^(-1), Y_2^1) = (1)/(2) sqrt((15)/(pi)) (x y, y z, x z), quad Y_2^0 = (1)/(4) sqrt((5)/(pi)) (3 z^2 - 1), quad Y_2^2 = (1)/(4) sqrt((15)/(pi)) (x^2 - y^2). $ <eq:ch06-sh-l2>
球谐基满足标准正交性 $integral_(SS^2) Y_l^m (omega) Y_(l')^(m')(omega) dif omega = delta_(l l') delta_(m m')$ 以及*旋转不变性*（即对球面信号施加任意三维旋转 $bold(R) in "SO"(3)$，其第 $l$ 阶球谐系数仅在第 $l$ 阶内部的 $2 l + 1$ 个通道间做正交线性变换，绝不向其他阶泄漏能量）。

2001 年，Ravi Ramamoorthi 与 Pat Hanrahan 证明了一个惊人的频域衰减定理@ramamoorthi2001efficient：在 @eq:ch06-irradiance-int 中，漫反射余弦核 $hat(A)(theta) = max(0, cos theta)$ 是关于 $z$ 轴旋转对称的带状谐波（Zonal Harmonics，仅 $m = 0$ 项非零），其球谐展开系数 $hat(A)_l = sqrt(4 pi \/ (2 l + 1)) A_l$ 满足：
- $l = 0, 1, 2$ 时，卷积权重为 $hat(A)_0 = pi$、$hat(A)_1 = 2 pi \/ 3$、$hat(A)_2 = pi \/ 4$；
- 所有大于 $1$ 的奇数阶（$l = 3, 5, 7, dots$）系数*恒等于零*（$hat(A)_l = 0$）！
- 偶数阶（$l >= 4$）系数按 $l^(-5\/2)$ 极速衰减（$hat(A)_4 = -pi \/ 24$，能量占比不足 $1%$）。
因此，漫反射表面天然是一个极强的球面低通滤波器！无论入射环境光 $L_"env"$ 包含多么高频的细节，根据球谐 *Funk-Hecke 卷积定理*，只需保留前 3 阶共 *9 个球谐系数* $L_l^m = integral_(SS^2) L_"env"(omega) Y_l^m (omega) dif omega$，即可捕获超过 $99%$ 的漫反射辐照度能量（平均像素误差 $< 1%$）@ramamoorthi2001efficient：
$ E(bold(n)) approx sum_(l=0)^2 sum_(m=-l)^l hat(A)_l L_l^m Y_l^m (bold(n)). $ <eq:ch06-sh-irradiance>

=== 预计算辐射传输（PRT）：将软阴影与互反射化为实时向量内积

@eq:ch06-sh-irradiance 虽然解决了无遮挡漫反射环境光，却忽略了物体自身的遮挡 $V(bold(x), omega_i)$ 与局部多次弹射互反射。2002 年，Peter-Pike Sloan 等人提出了里程碑式的*预计算辐射传输*（Precomputed Radiance Transfer, PRT）框架@sloan2002precomputed（架构见 @fig:ch06-prt-pipeline）：利用球谐基的正交完备性，将「动态低频环境光源」与「静态网格自身的复杂辐射传输算子」彻底解耦！

具体而言，将单次反射（含软自阴影）乃至多次漫反射弹射统一写成作用于入射环境光 $L_"env"$ 的线性算子。将 $L_"env"(omega_i) approx sum_(k=1)^(N_"SH") l_k Y_k (omega_i)$（其中 $k$ 为 $(l, m)$ 的扁平化索引，$N_"SH" = (L + 1)^2$）代入带可见性的漫反射积分：
$ L_o (bold(x)) = (rho_d (bold(x)))/(pi) integral_(Omega^+) L_"env"(omega_i) V(bold(x), omega_i) max(0, bold(n)(bold(x)) dot omega_i) dif omega_i = sum_(k=1)^(N_"SH") l_k underbrace(((rho_d (bold(x)))/(pi) integral_(Omega^+) V(bold(x), omega_i) max(0, bold(n)(bold(x)) dot omega_i) Y_k (omega_i) dif omega_i), t_k (bold(x))) = bold(l)^top bold(t)(bold(x)). $ <eq:ch06-prt-diffuse>
如 @eq:ch06-prt-diffuse 所示，积分号内与顶点相关的传输向量 $bold(t)(bold(x)) = (t_1(bold(x)), dots, t_(N_"SH")(bold(x)))^top$ 仅取决于物体自身的几何遮挡与多次散射，完全与外部光照无关！因此在离线烘焙阶段，可以用蒙特卡洛路径追踪耗费数分钟在每个顶点（或光照贴图纹素）处精确预计算传输向量 $bold(t)(bold(x))$；而在实时运行期，无论环境光如何旋转或动态变化，每个顶点或片元只需执行一次 $O(N_"SH")$ 的*向量点积* $bold(l)^top bold(t)(bold(x))$（对于光泽材质 Glossy BRDF，则预计算传输矩阵 $bold(T)(bold(x))$ 并执行矩阵—向量乘法 $bold(T)(bold(x)) bold(l)$），即可在零光线追踪开销下实时呈现出柔和的面光源软自阴影与色彩溢色（Color Bleeding）@sloan2002precomputed！

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 左侧：离线预计算阶段
    rect((0.3, 0.4), (7.6, 4.9), fill: softbg, stroke: 0.8pt + softline, radius: 0.08)
    content((3.95, 4.55), text(size: 8pt, weight: "bold", fill: accent)[离线烘焙 / 预处理阶段（Offline Precomputation）])
    // 顶部分支：环境贴图投影
    rect((0.6, 2.8), (4.0, 4.1), fill: white, stroke: 0.8pt + accent, radius: 0.08)
    content((2.3, 3.65), text(size: 7.5pt, weight: "bold")[HDR 环境贴图 $L_"env"(omega)$])
    content((2.3, 3.1), text(size: 7.2pt)[球面正交投影 $integral L_"env" Y_k dif omega$])
    line((4.05, 3.45), (4.95, 3.45), mark: (end: ">"), stroke: 0.9pt + accent)
    rect((5.0, 2.95), (7.3, 3.95), fill: bluebg, stroke: 0.8pt + accent, radius: 0.08)
    content((6.15, 3.45), text(size: 7.5pt, weight: "bold")[光照系数向量 $bold(l)$])

    // 底部分支：场景路径追踪预计算传输向量
    rect((0.6, 0.8), (4.0, 2.3), fill: white, stroke: 0.8pt + accent2, radius: 0.08)
    content((2.3, 1.85), text(size: 7.5pt, weight: "bold")[三维网格几何 + 材质])
    content((2.3, 1.35), text(size: 7.2pt)[离线路径追踪自阴影与互反射])
    content((2.3, 0.98), text(size: 7.0pt)[$integral V(bold(x), omega) cos theta_i Y_k (omega) dif omega$])
    line((4.05, 1.55), (4.95, 1.55), mark: (end: ">"), stroke: 0.9pt + accent2)
    rect((5.0, 1.05), (7.3, 2.05), fill: redbg, stroke: 0.8pt + accent2, radius: 0.08)
    content((6.15, 1.55), text(size: 7.5pt, weight: "bold")[传输向量场 $bold(t)(bold(x))$])

    // 右侧：实时渲染阶段
    rect((8.3, 0.4), (13.9, 4.9), fill: softbg, stroke: 0.8pt + softline, radius: 0.08)
    content((11.1, 4.55), text(size: 8pt, weight: "bold", fill: accent2)[实时运行阶段（Real-Time Runtime）])
    line((7.35, 3.45), (8.95, 2.95), mark: (end: ">"), stroke: 0.9pt + accent)
    line((7.35, 1.55), (8.95, 2.35), mark: (end: ">"), stroke: 0.9pt + accent2)
    rect((9.0, 2.0), (13.3, 3.4), fill: white, stroke: 1pt + accent, radius: 0.08)
    content((11.15, 2.95), text(size: 7.8pt, weight: "bold")[着色器 $O(N_"SH")$ 极速内积])
    content((11.15, 2.35), text(size: 7.5pt, fill: accent)[$L_o (bold(x)) = sum_(k=1)^(N_"SH") l_k (bold(R)) thin t_k (bold(x))$])
    line((11.15, 1.95), (11.15, 1.45), mark: (end: ">"), stroke: 0.9pt + accent)
    rect((9.0, 0.7), (13.3, 1.4), fill: bluebg, stroke: 0.8pt + accent, radius: 0.08)
    content((11.15, 1.05), text(size: 7.5pt, weight: "bold")[实时软阴影 + 漫反射/光泽互反射])
  })),
  caption: [预计算辐射传输（PRT）的双阶段解耦架构。离线阶段利用蒙特卡洛积分将昂贵的可见性 $V(bold(x), omega)$ 与多次弹射烘焙为顶点/纹素上的球谐传输向量 $bold(t)(bold(x))$；实时阶段仅需将旋转后的环境光系数 $bold(l)$ 与 $bold(t)(bold(x))$ 做 $O(N_"SH")$ 向量内积。],
) <fig:ch06-prt-pipeline>

=== 算法实现：前 3 阶实球谐基求值、环境贴图投影与辐照度重建

下面给出可运行的 Python（NumPy）实现，演示前 3 阶（9 系数）实球谐基函数求值、等距柱状环境贴图（Equirectangular Map）球谐投影以及漫反射辐照度 $E(bold(n))$ 的无采样快速重建：

```python
import numpy as np

def eval_sh9(dirs):
    """
    计算前 3 阶 (l <= 2, 共 9 个) 实球谐基函数值 Y_l^m(x, y, z)
    dirs: (..., 3) 归一化方向向量 [x, y, z] -> 返回 (..., 9)
    """
    x, y, z = dirs[..., 0], dirs[..., 1], dirs[..., 2]
    sh = np.empty(dirs.shape[:-1] + (9,), dtype=np.float64)
    sh[..., 0] = 0.28209479177387814                      # Y_0^0
    sh[..., 1] = 0.4886025119029199 * y                   # Y_1^-1
    sh[..., 2] = 0.4886025119029199 * z                   # Y_1^0
    sh[..., 3] = 0.4886025119029199 * x                   # Y_1^1
    sh[..., 4] = 1.0925484305920792 * x * y               # Y_2^-2
    sh[..., 5] = 1.0925484305920792 * y * z               # Y_2^-1
    sh[..., 6] = 0.31539156525252005 * (3.0 * z * z - 1.0)# Y_2^0
    sh[..., 7] = 1.0925484305920792 * x * z               # Y_2^1
    sh[..., 8] = 0.5462742152960396 * (x * x - y * y)     # Y_2^2
    return sh

def project_envmap_to_sh9(env_map):
    """将 (H, W, 3) 等距柱状全景 HDR 环境贴图投影为 (9, 3) 球谐光照系数 L_k"""
    H, W, _ = env_map.shape
    theta = (np.arange(H) + 0.5) / H * np.pi          # 极角 [0, pi]
    phi   = (np.arange(W) + 0.5) / W * (2.0 * np.pi)  # 方位角 [0, 2*pi]
    tt, pp = np.meshgrid(theta, phi, indexing="ij")
    dirs = np.stack([np.sin(tt) * np.cos(pp), np.sin(tt) * np.sin(pp), np.cos(tt)], axis=-1)
    # 球面立体角微元 d_omega = sin(theta) * d_theta * d_phi
    d_omega = np.sin(tt) * (np.pi / H) * (2.0 * np.pi / W)
    sh_basis = eval_sh9(dirs)  # (H, W, 9)
    return np.einsum("hwk,hwc,hw->kc", sh_basis, env_map, d_omega)

def eval_diffuse_irradiance(normals, sh_coeffs):
    """利用 Ramamoorthi-Hanrahan 9 系数公式 (6.8) 快速计算表面法线处的漫反射辐照度 E(n)"""
    A_hat = np.array([np.pi, 2*np.pi/3, 2*np.pi/3, 2*np.pi/3,
                      np.pi/4, np.pi/4, np.pi/4, np.pi/4, np.pi/4])
    sh_n = eval_sh9(normals)  # (..., 9)
    return np.einsum("...k,k,kc->...c", sh_n, A_hat, sh_coeffs)
```

== 屏幕空间全局光照：SSAO / GTAO、屏幕空间反射（SSR）与辐射探针 <sec:ch06-ssgi>

PRT 虽然优雅，但要求场景几何必须静态预烘焙。为了在完全动态的场景中实时获得近场接触阴影、环境遮蔽与光滑反射，工业界提出了一整套直接将当前帧 *G-Buffer（深度缓冲 + 法线缓冲 + 颜色缓冲）视为场景几何 2.5D 局部代理*的*屏幕空间技术*（Screen-Space Techniques）。

=== 屏幕空间环境光遮蔽：从 SSAO 到地平线积分 GTAO

当环境光 $L_"env"$ 近似为各向同性常量 $L_a$ 时，@eq:ch06-prt-diffuse 简化为平均余弦可见性——*环境光遮蔽*（Ambient Occlusion, AO）：
$ A(bold(x)) = (1)/(pi) integral_(Omega^+) V(bold(x), omega_i) max(0, bold(n) dot omega_i) dif omega_i in [0, 1]. $ <eq:ch06-ao-def>
1. *SSAO / HBAO+（体积采样型）*：对于像素对应的三维点 $bold(x)$，在其法线上半球 $Omega^+$ 的局部半径 $R$ 内生成 $K$ 个三维随机采样点 $bold(s)_k$，将其投影回屏幕空间读取深度缓冲 $z_"buf"$；若 $bold(s)_k$ 的深度深于 $z_"buf"$（且深度差在合理范围内以排除远景误遮挡），则累加遮蔽贡献，最后经双边滤波（Bilateral Blur）降噪。
2. *GTAO（Ground-Truth Ambient Occlusion，真实感地平线积分）*：现代引擎（如 Unreal Engine 与 Unity HDRP）广泛采用基于切片地平线角解析积分的 GTAO。它将二维半球积分 @eq:ch06-ao-def 沿屏幕方位角切分为若干个一维垂直平面切片；在每个切片内，沿着屏幕射线正反两个方向在深度缓冲中步进搜索最大仰角（地平线角 Horizon Angles）$theta_1, theta_2$，再将可见扇区 $[theta_1, theta_2]$ 与余弦核 $cos theta$ 的一维解析积分公式直接代入求和，使屏幕空间 AO 首次在能量上严格对齐离线路径追踪基准。

=== 屏幕空间反射（SSR）与世界空间辐射度探针（Irradiance Probes）

对于光滑表面（如潮湿积水路面、金属地板）的间接镜面反射，*屏幕空间反射*（Screen-Space Reflections, SSR）从着色点 $bold(x)$ 沿反射方向 $bold(r) = 2(bold(n) dot omega_o) bold(n) - omega_o$ 发射一条射线，并在第 4 章介绍的 *Hi-Z 层次深度金字塔*上执行自适应步进光线行进（Hierarchical-Z Ray Marching）：遇到空白子节点时直接大步跳过 $8 times 8$ 像素块，遇到潜在交点时下钻到细层级精确定位，命中的屏幕像素上一帧颜色即作为反射辐射度返回。

然而，所有纯屏幕空间技术都受困于一个结构性缺陷：*G-Buffer 只包含主相机当前看见的第一层表面*。一旦反射射线飞出屏幕边界、或者射向画面中某个物体的背面，屏幕空间便彻底丢失了几何与光照信息，导致视角转动时反射与遮蔽突然消失。为此，现代实时全局光照系统普遍将屏幕空间技术与*世界空间辐射度探针体积*（Irradiance Volume Probes，如基于硬件光线追踪实时更新的动态漫反射全局光照 DDGI）结合：在三维空间中按规则网格或自适应八叉树布置探针，每个探针用二阶球谐函数（SH9）或八面体映射（Octahedral Map）记录周围全向辐射亮度与径向深度矩（用类似 VSM 的切比雪夫不等式防止墙壁漏光），为屏幕空间缺失的视野外部与背面区域提供无缝的兜底间接光照。@tab:ch06-gi-compare 系统总结了本章涵盖的五大实时阴影与全局光照近似技术。

#figure(
  table(
    columns: (2.3cm, 2.1cm, 2.2cm, 2.3cm, 4.6cm),
    align: (left, center, center, center, left),
    [技术范式], [主导频率], [动态几何支持], [运行时开销], [核心机制与主要工程局限],
    [阴影贴图 (PCSS/VSM)], [高频直接光], [完全支持], [中～高], [从光源视角光栅深度@williams1978casting @fernando2005pcss @donnelly2006variance；仅限少数主光源，多光源显存与带宽受限],
    [预计算传输 (PRT)], [低频全局光], [仅限刚体/静态], [极低 ($O(N_"SH")$)], [离线烘焙可见性球谐传输向量@ramamoorthi2001efficient @sloan2002precomputed；网格发生任意形变时预计算失效],
    [屏幕空间 (GTAO/SSR)], [中～高频近场], [完全支持], [低～中], [基于 G-Buffer 深度金字塔步进；存在屏幕边界截断与物体背面信息缺失],
    [辐射度探针 (DDGI)], [低频漫反射], [支持], [中], [世界空间三维网格探针存储球谐/八面体辐射度与切比雪夫深度；缺乏高频镜面反射],
    [时空水塘重采样 (ReSTIR)], [全频谱 GI], [完全支持], [中～高 (需 RT)], [流式重采样重要性采样 + 空时水塘复用@bitterli2020restir @lin2022generalized；运动剧烈时存在时间滞后],
  ),
  caption: [现代实时渲染中五类主流阴影与全局光照近似技术的特性、动态能力与局限对比。],
) <tab:ch06-gi-compare>

== 现代演进：时空水塘重采样（ReSTIR）与混合实时全局光照 <sec:ch06-frontier>

在很长一段时间内，实时渲染被迫用数十种互不兼容的近似技巧（CSM + PCSS + PRT + GTAO + SSR + DDGI）拼凑全局光照，一旦场景中出现成千上万盏动态霓虹灯、火把与自发光几何体，传统阴影贴图与分簇管线便彻底束手无策。随着 2018 年起硬件光线追踪（RT Cores）普及，实时图形学的核心矛盾从「如何避免发射光线」转变为「*如何在每像素仅能发射 1～2 条阴影/路径射线的极端预算下，抑制蒙特卡洛积分的巨幅方差*」。

=== 流式重采样重要性采样（RIS）与时空水塘重采样（ReSTIR）

【已有成果】2020 年，Benedikt Bitterli 等人提出了改写实时光线追踪格局的*时空水塘重采样*（Spatiotemporal Reservoir Resampling, ReSTIR）算法@bitterli2020restir。其数学根基是两个经典统计算子的精妙结合：
1. *重采样重要性采样（Resampled Importance Sampling, RIS）*：当目标被积分布 $hat(p)(x) = f_r (x) L_e (x) G(x)$（不含昂贵的可见性 $V(x)$）难以直接采样时，先从廉价提议分布 $q(x)$（如均匀抽取光源）中独立抽取 $M$ 个候选样本 ${x_1, dots, x_M}$，计算重采样权重 $w(x_i) = hat(p)(x_i) \/ q(x_i)$，再以正比于 $w(x_i)$ 的概率从中选出 1 个最终样本 $y$，并用无偏估计权重 $W(y) = (1 \/ hat(p)(y)) (1 \/ M) sum_(i=1)^M w(x_i)$ 发射*唯一一条*阴影射线检测 $V(y)$。
2. *加权水塘采样（Weighted Reservoir Sampling, WRS）与空时合并*：每个屏幕像素只需在显存中维护一个固定大小（仅 16～24 字节）的*水塘结构*（Reservoir）$cal(R) = (y, w_"sum", M, W)$，即可在不保存历史列表的前提下以 $O(1)$ 内存流式接收任意数量的候选样本。更关键的是，*合并两个水塘等价于将两个水塘各自持有的样本集直接合并且无需重新评估完整集合*！

借助这一性质，ReSTIR 在每一帧执行三级级联复用@bitterli2020restir：
- *初始候选抽样*：每个像素先对 $M = 32$ 个随机光源做局部 RIS 装入当前帧水塘；
- *时间复用（Temporal Reuse）*：顺着运动向量找回上一帧对应像素的水塘，将其以 $O(1)$ 代价并入当前像素水塘；
- *空间复用（Spatial Reuse）*：在当前像素周围随机挑选 3～5 个法线与深度相近的邻域像素，再次合并它们的水塘。
短短几帧之内，每个像素的水塘实际上已经等效筛选了来自空时邻域的数万个候选光源样本，却在最终着色时每个像素仅发射 *1 条*硬件阴影射线！2022 年，Daqi Lin 等人进一步引入广义重采样理论（Generalized Resampled Importance Sampling, GRIS）与移位映射（Shift Mapping）雅可比行列式修正，将 ReSTIR 从直接光照推广到完整的多次弹射路径空间——即 *ReSTIR PT / ReSTIR GI*@lin2022generalized。

【本书推断】从 Williams 的 Shadow Mapping、Sloan 的 PRT 到如今的 ReSTIR 与混合管线（如 Unreal Engine 5 Lumen），实时全局光照正在经历一场深刻的范式统一：过去分离的阴影贴图、屏幕空间追踪与世界空间探针并未消亡，而是被整合为多尺度混合辐射场（屏幕空间负责微米级近场高频细节，硬件光线追踪 + ReSTIR 水塘负责中远场与百万动态光源的重要性抽样，世界空间辐射缓存负责多次漫反射尾迹）。这套「多尺度辐射缓存 + 空时重要性水塘复用」的架构不仅统治了当代实时渲染，也正在成为神经辐射场与可微逆渲染（第 11～13 章）实现高效率重打光（Relighting）的核心底座。

#keybox(title: [本章要点])[
  1. *实时阴影与软阴影过滤*：Shadow Mapping 通过光源视角深度缓冲判定可见性，利用斜率偏移 @eq:ch06-slope-bias 抑制自遮挡走样；PCSS 基于平行平面相似三角形公式 $w_"penumbra" = (d_"receiver" - d_"blocker") w_"light" \/ d_"blocker"$ 动态调整 PCF 核半径实现接触硬化，而 VSM 利用二阶矩线性预滤波与切比雪夫不等式 @eq:ch06-vsm-chebyshev 将软阴影查询降为 $O(1)$。
  2. *大场景阴影架构*：级联阴影贴图（CSM）通过对数—均匀混合切分 @eq:ch06-csm-split 与纹素取整对齐消除开放世界透视走样与边缘闪烁；虚拟阴影贴图则通过按需分配物理页实现了全场景自适应高分辨率阴影。
  3. *球谐函数与预计算辐射传输（PRT）*：漫反射余弦核在球谐频域极速衰减，仅需前 3 阶（9 个）实球谐系数即可捕获 $> 99%$ 的环境辐照度能量；PRT 将静态场景的自阴影与互反射预烘焙为传输向量 $bold(t)(bold(x))$，使实时全局光照简化为 $O(N_"SH")$ 向量内积。
  4. *屏幕空间技术与 ReSTIR 前沿*：GTAO 与 SSR 利用 G-Buffer 深度金字塔高效计算近场遮蔽与反射，并由世界空间辐射探针弥补视野外信息；时空水塘重采样（ReSTIR）则通过流式 RIS 与空时水塘合并，在每像素 1～2 条射线的预算下实现了百万动态光源与实时路径追踪。
]
