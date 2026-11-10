#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 局部光照、纹理映射系统与现代可编程 GPU 管线

第 4 章解决了「三角形覆盖哪些屏幕像素、哪个片元在最前方以及如何透视校正插值顶点属性」的几何光栅化问题。然而，若仅对顶点颜色做插值，渲染出的三维物体只是一具缺乏材质质感与明暗层次的塑料几何壳。要让每个可见片元呈现出丰富的表面细节（如金属划痕、织物纹理、砖石凹凸）与逼真的光影响应，渲染管线必须在片元阶段引入*局部光照模型*（Local Illumination）与*纹理映射系统*（Texture Mapping），并通过高效的 GPU 渲染架构将数以百万计的几何图元与成百上千盏动态光源组织起来。

本章首先从经典的 Lambert 漫反射与 Blinn-Phong 半程向量模型出发，剖析经验局部光照的数学形式及其能量不守恒缺陷（@sec:ch05-blinn-phong）；随后深入探讨纹理走样的信号成因，推导 Mipmap 图像金字塔、屏幕空间偏导数 LOD 计算与椭圆加权各向异性过滤（@sec:ch05-mipmap）；接着推导切线空间正交基（$bold(T) bold(B) bold(N)$ 矩阵）的构造，对比法线贴图、视差遮挡贴图与位移贴图的凹凸细节增强机制（@sec:ch05-normal-map）；继而剖析现代可编程 GPU 管线中前向着色、延迟着色（Deferred Shading）与可见性缓冲（Visibility Buffer）三大架构范式的演进，并给出 GLSL 着色器实现（@sec:ch05-gpu-pipeline）；最后在前沿视野中探讨网格着色器（Mesh Shaders）与随机访问神经纹理压缩（NTC）对图形管线的重塑（@sec:ch05-frontier）。

== 经验局部光照：Lambert 漫反射与 Blinn-Phong 半程向量模型 <sec:ch05-blinn-phong>

在引入完整的辐射度量学与微表面渲染方程（第 7 章）之前，早期实时图形学普遍采用计算轻量、直观易调的*经验局部光照模型*。这里「局部」的含义是：着色点 $bold(x) in RR^3$ 的出射颜色仅取决于该点的表面法线 $bold(n) in SS^2$、指向相机的视线方向 $omega_o in SS^2$ 以及指向光源的入射方向 $omega_i in SS^2$（按全书统一约定，$omega_i, omega_o, bold(n)$ 均为背离表面指向外侧的单位向量），而不考虑其他表面反射过来的多次弹射间接光或阴影遮挡。

=== 环境光、Lambert 漫反射与 Phong 镜面反射

1975 年，Bui Tuong Phong 提出了由环境光（Ambient）、漫反射（Diffuse）与镜面高光（Specular）三项线性叠加构成的经典经验光照模型@phong1975illumination：
1. *环境光项（Ambient）*：为弥补局部光照缺失的全局多次散射间接光，假设场景中存在各向同性的恒定背景光强 $bold(I)_a$，表面环境反射率为 $bold(k)_a$，其贡献为常数项 $bold(L)_a = bold(k)_a dot.o bold(I)_a$（其中 $dot.o$ 表示 RGB 通道逐元素相乘）。
2. *Lambert 漫反射项（Diffuse）*：理想漫反射体将入射光向半球各个方向均匀散射，出射亮度与观察方向 $omega_o$ 无关。根据朗伯余弦定律（Lambert's Cosine Law），单位面积接收到的有效辐射通量正比于入射方向 $omega_i$ 与法线 $bold(n)$ 夹角的余弦：
   $ bold(L)_d = bold(k)_d dot.o bold(I)_l max(0, bold(n) dot omega_i), $ <eq:ch05-lambert>
   其中 $bold(k)_d$ 为漫反射反照率（Albedo），$bold(I)_l$ 为点光源到达表面处的强度（若考虑点光源距离平方反比衰减，则 $bold(I)_l = bold(I)_0 \/ norm(bold(p)_"light" - bold(x))^2$）。
3. *Phong 镜面高光项*：光滑表面会在理想镜面反射方向 $bold(r) = 2(bold(n) dot omega_i) bold(n) - omega_i$ 附近形成集中的高光瓣（Specular Lobe）。Phong 用视线 $omega_o$ 与反射向量 $bold(r)$ 夹角余弦的幂次 $max(0, bold(r) dot omega_o)^s$ 来模拟高光衰减@phong1975illumination。

=== Blinn-Phong 半程向量修正与能量守恒批判

1977 年，James F. Blinn 对 Phong 模型做出了关键改进@blinn1977models：引入入射方向 $omega_i$ 与出射视线方向 $omega_o$ 的角平分线单位向量——*半程向量*（Halfway Vector）：
$ bold(h) = (omega_i + omega_o)/(norm(omega_i + omega_o)) in SS^2. $ <eq:ch05-halfway>
当视线 $omega_o$ 恰好对准理想镜面反射方向 $bold(r)$ 时，半程向量 $bold(h)$ 与表面法线 $bold(n)$ 完全重合。因此，Blinn 用 $(bold(n) dot bold(h))$ 替代了 Phong 模型中的 $(bold(r) dot omega_o)$，得到完整的多光源 *Blinn-Phong 局部光照方程*：
$ bold(L)_o (bold(x), omega_o) = bold(k)_a dot.o bold(I)_a + sum_(m=1)^(N_"light") bold(I)_(l, m) dot.o (bold(k)_d max(0, bold(n) dot omega_(i, m)) + bold(k)_s max(0, bold(n) dot bold(h)_m)^s), $ <eq:ch05-blinn-phong>
其中 $bold(k)_s$ 为镜面反射系数，高光指数（Shininess）$s in [1, +infinity)$ 控制表面粗糙度：$s$ 越大，高光瓣越狭窄锐利。

Blinn-Phong 相较于原始 Phong 模型具有两大显著优势：第一，在远光源与正交相机（或局部近似）下，计算一次归一化加法的开销低于每次求反射向量 $bold(r)$；第二，当光源与视线均处于掠射角（Grazing Angle，即 $bold(n) dot omega_i -> 0$）时，Phong 模型中 $bold(r)$ 与 $omega_o$ 的夹角可能超过 $90 degree$ 导致 $max(0, bold(r) dot omega_o)$ 被硬截断出一条不自然的断裂带，而半程向量 $bold(h)$ 始终位于上半球，满足 $bold(n) dot bold(h) >= 0$，且在微表面物理意义上，$(bold(n) dot bold(h))$ 直接对应着刚好能将光线从 $omega_i$ 镜面反射到 $omega_o$ 的微平面（Microfacet）法线取向（详见第 7 章）。

#remark(title: [经验光照模型的物理缺陷：能量不守恒])[
  尽管 @eq:ch05-blinn-phong 在早期固定管线（OpenGL 1.x / DirectX 7）中统治了数十年，但它违背了热力学第一定律（能量守恒）。若将未归一化的高光核 $cos^s theta_h$ 在上半球 $Omega^+$ 上对出射立体角做积分，其总反射能量随高光指数 $s$ 的增大而按 $O(1 \/ (s + 2))$ 衰减。这意味着在原始 Blinn-Phong 中调高 $s$ 不仅使高光变窄，还会导致高光总能量凭空消失、中心峰值亮度保持不变。若要令高光瓣积分保持恒定，必须为高光项乘上归一化因子 $(s + 8) \/ (8 pi)$。即便如此，经验模型仍缺乏掠射角处的菲涅耳反射增强（Fresnel Effect）与微平面自遮挡掩蔽项（Shadowing-Masking），这正是第 7 章物理基础渲染（PBR）要彻底解决的问题。
]

== 纹理映射、双线性/三线性插值、Mipmap 与各向异性过滤 <sec:ch05-mipmap>

为了在不增加几何三角形数量的前提下赋予表面随空间变化的材质属性（如反照率 $bold(k)_d (bold(x))$、粗糙度 $s(bold(x))$），Edwin Catmull 于 1974 年首次引入了*纹理映射*（Texture Mapping）：为每个三维网格顶点绑定二维参数域坐标 $(u, v) in [0, 1]^2$，在光栅化时经透视校正插值（见第 4 章 @eq:ch04-persp-interp）得到当前片元的 $(u, v)$，再映射到分辨率为 $W times H$ 的离散二维数组——*纹素*（Texel，Texture Element）网格上读取材质属性。

=== 纹理放大与双线性插值（Bilinear Filtering）

当相机靠近物体表面，单个纹素覆盖多个屏幕像素时，发生*纹理放大*（Magnification）。设归一化纹理坐标 $(u, v)$ 映射到连续纹素索引坐标 $(x_t, y_t) = (u W - 0.5, v H - 0.5)$（减 $0.5$ 是因为纹素值定义在格点中心 $(i + 0.5, j + 0.5)$ 处）。
- *最近邻采样（Nearest-Neighbor）*：直接取距离 $(x_t, y_t)$ 最近的整数纹素 $T[round(x_t), round(y_t)]$，画面会呈现出明显的马赛克方块感。
- *双线性插值（Bilinear Interpolation）*：记左上邻近纹素整数索引为 $i = floor(x_t), j = floor(y_t)$，小数偏移量为 $s = x_t - i in [0, 1)$、$t = y_t - j in [0, 1)$。硬件一次性读取周围 $2 times 2$ 纹素 $T_(00) = T[i, j]$、$T_(10) = T[i+1, j]$、$T_(01) = T[i, j+1]$、$T_(11) = T[i+1, j+1]$，先沿水平方向线性插值，再沿垂直方向线性插值：
  $ T_"bilinear"(x_t, y_t) = (1 - t) ((1 - s) T_(00) + s T_(10)) + t ((1 - s) T_(01) + s T_(11)). $ <eq:ch05-bilinear>
  双线性过滤将阶跃不连续的方块过渡转化为分片双线性连续曲面，仅需极低的硬件代价即可消除纹理放大时的锯齿。

=== 纹理缩小走样、Williams 的 Mipmap 金字塔与屏幕偏导数 LOD

比纹理放大棘手得多的是*纹理缩小*（Minification）：当物体远离相机或表面与视线呈大倾角时，屏幕上的*单个像素*投射到纹理空间会覆盖数十乃至数百个纹素（这一投影区域称为*像素足迹* Pixel Footprint）。此时若仍只在该像素中心做一次点采样或双线性采样，纹理中的高频细节将严重违反奈奎斯特采样定理，产生剧烈的摩尔纹（Moiré Pattern）与画面闪烁。

若在运行时对像素足迹内的所有纹素实时求和平均，每个像素需要读取上百个纹素，显存带宽完全无法承受。1983 年，Lance Williams 提出了里程碑式的 *Mipmap（Multum in Parvo，「小空间内的多重细节」）图像金字塔*预过滤技术@williams1983pyramidal：在渲染前，对原始纹理（第 $0$ 层，分辨率 $W times H$）递归执行 $2 times 2$ 下采样低通滤波，生成一系列分辨率逐层减半的图像金字塔，直到顶层第 $log_2 max(W, H)$ 层退化为 $1 times 1$ 纹素。由几何级数求和公式：
$ 1 + (1)/(4) + (1)/(16) + (1)/(64) + dots.c = sum_(k=0)^infinity (1)/(4^k) = (4)/(3), $ <eq:ch05-mipmap-mem>
整座 Mipmap 金字塔仅比原始纹理多消耗 *33.3%* 的显存空间！

在运行时，GPU 如何知道当前像素应该查询 Mipmap 的哪一层？这正是第 4 章介绍的 $2 times 2$ 像素四元组（Quad）机制大显身手的地方。对于同一个 $2 times 2$ Quad 内的相邻像素，GPU 硬件通过有限差分计算连续纹素坐标 $(u_t, v_t) = (u W, v H)$ 相对于屏幕像素坐标 $(x, y)$ 的雅可比偏导数矩阵：
$ bold(J)_"uv" = mat((partial u_t)/(partial x), (partial u_t)/(partial y); (partial v_t)/(partial x), (partial v_t)/(partial y)), quad L = max(sqrt(((partial u_t)/(partial x))^2 + ((partial v_t)/(partial x))^2), thick sqrt(((partial u_t)/(partial y))^2 + ((partial v_t)/(partial y))^2)). $ <eq:ch05-mipmap-lod>
标量 $L$ 度量了屏幕像素在水平或垂直方向步进 1 像素时在纹理空间跨过的最大纹素边长。由此定义连续的细节层级（Level of Detail, LOD）参数：
$ d = max(0, log_2 L). $ <eq:ch05-lod-d>
为了避免不同整数层 $floor(d)$ 与 $ceil(d)$ 之间出现突兀的跳变边界（Mipmap Banding），硬件采用*三线性插值*（Trilinear Interpolation）：分别在第 $floor(d)$ 层与第 $ceil(d)$ 层各执行一次双线性插值（共 8 个纹素），再以小数部分 $f_d = d - floor(d)$ 对两层结果做第三次线性插值：
$ T_"trilinear"(u, v, d) = (1 - f_d) T_"bilinear"^(floor(d))(u, v) + f_d T_"bilinear"^(ceil(d))(u, v). $ <eq:ch05-trilinear>

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 左侧：屏幕空间 2x2 Quad
    rect((0.3, 0.5), (4.6, 4.8), fill: softbg, stroke: 0.8pt + softline, radius: 0.08)
    content((2.45, 4.45), text(size: 8pt, weight: "bold")[屏幕空间像素与偏导数])
    rect((1.2, 1.4), (3.6, 3.8), fill: white, stroke: 1pt + accent)
    line((2.4, 1.4), (2.4, 3.8), stroke: 0.6pt + gray)
    line((1.2, 2.6), (3.6, 2.6), stroke: 0.6pt + gray)
    circle((1.8, 3.2), radius: 0.28, fill: bluebg, stroke: 1pt + accent)
    line((1.8, 3.2), (3.0, 3.2), mark: (end: ">"), stroke: 0.9pt + accent2)
    line((1.8, 3.2), (1.8, 2.0), mark: (end: ">"), stroke: 0.9pt + accent2)
    content((2.6, 3.45), text(size: 7.2pt, fill: accent2)[$Delta x = 1$])
    content((1.25, 2.3), text(size: 7.2pt, fill: accent2)[$Delta y = 1$])
    content((2.45, 0.95), text(size: 7.2pt)[倾斜投射至纹理空间 $(u, v)$])

    // 投射箭头
    line((4.75, 2.65), (5.85, 2.65), mark: (end: ">"), stroke: 1pt + accent)
    content((5.3, 3.05), text(size: 7.2pt, fill: accent)[逆透视映射])

    // 右侧：纹理空间足迹对比
    rect((6.0, 0.5), (13.9, 4.8), fill: softbg, stroke: 0.8pt + softline, radius: 0.08)
    content((9.95, 4.45), text(size: 8pt, weight: "bold")[纹理空间 $(u, v)$：各向同性 Mipmap vs. 各向异性过滤])
    // 纹素背景网格
    for ix in range(0, 14) {
      let gx = 6.4 + ix * 0.5
      line((gx, 0.8), (gx, 4.1), stroke: 0.35pt + gray.lighten(35%))
    }
    for iy in range(0, 7) {
      let gy = 0.8 + iy * 0.5
      line((6.4, gy), (13.4, gy), stroke: 0.35pt + gray.lighten(35%))
    }
    // 各向同性 Mipmap 大正方形 (过度模糊)
    rect((7.4, 0.95), (10.9, 4.05), fill: redbg.transparentize(35%), stroke: (dash: "dashed", paint: warn, thickness: 1pt))
    content((11.95, 3.65), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt, fill: warn)[Mipmap 正方形足迹])
    content((11.95, 3.2), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt, fill: warn)[（短轴方向严重过模糊）])

    // 真实狭长椭圆足迹与各向异性多次采样
    line((7.5, 1.3), (10.8, 3.7), stroke: 1.2pt + accent)
    for k in range(5) {
      let tk = k / 4.0
      let cx = 7.7 + tk * 2.9
      let cy = 1.45 + tk * 2.1
      circle((cx, cy), radius: 0.32, fill: bluebg.transparentize(20%), stroke: 0.9pt + accent)
      circle((cx, cy), radius: 0.06, fill: accent, stroke: none)
    }
    content((11.85, 1.55), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt, fill: accent)[各向异性过滤（AF）])
    content((11.85, 1.1), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt, fill: accent)[沿椭圆长轴多点采样])
  })),
  caption: [纹理空间像素足迹与各向异性过滤原理。当视线与表面呈大倾角时，屏幕圆形像素投射到纹理空间形成狭长椭圆；各向同性 Mipmap 被迫按长轴 $L_"max"$ 选取高层级正方形区域导致严重模糊，而各向异性过滤按短轴 $L_"min"$ 选层并沿长轴多次采样。],
) <fig:ch05-mipmap-aniso>

=== 椭圆加权平均（EWA）与各向异性过滤（Anisotropic Filtering）

如 @fig:ch05-mipmap-aniso 所示，Mipmap 的核心假设是「屏幕像素在纹理空间的足迹近似为各向同性的正方形」。然而，当我们以掠射角观察远处的地面或公路时，屏幕像素沿视线纵深方向跨越了极多纹素（长轴 $L_"max"$ 很大），而在水平横向仅跨越了很少纹素（短轴 $L_"min"$ 很小），真实足迹是一个离心率极高的狭长椭圆。由于标准 Mipmap 方程 @eq:ch05-mipmap-lod 取了两个方向导数的最大值 $L = L_"max"$，硬件被迫去查询分辨率极低的粗糙层级，导致远处地面在横向也被严重过度模糊（Over-blurring）。

1989 年，Paul S. Heckbert 系统建立了纹理映射的信号重采样理论，提出*椭圆加权平均*（Elliptical Weighted Average, EWA）滤波器@heckbert1989fundamentals：将雅可比矩阵 $bold(J)_"uv"$ 定义的椭圆高斯核与纹理信号做精确二维卷积。现代 GPU 的*各向异性过滤*（Anisotropic Filtering, AF）正是 EWA 的硬件高效近似：
1. 分别计算足迹的长轴长度 $L_"max"$ 与短轴长度 $L_"min"$，根据*短轴长度*确定细节层级 $d_"aniso" = log_2 L_"min"$，从而保留短轴方向的高频清晰度；
2. 计算各向异性比率 $R = min(N_"max", ceil(L_"max" \/ L_"min"))$（其中 $N_"max" in {2, 4, 8, 16}$ 为用户设定的最大各向异性采样倍数），在层级 $d_"aniso"$ 上沿着椭圆长轴方向均匀布置 $R$ 个三线性采样点并取均值。这仅以 $R$ 倍纹理采样的代价，彻底解决了倾斜表面的远景模糊问题。

== 几何细节增强：切线空间法线贴图、视差贴图与位移贴图 <sec:ch05-normal-map>

真实的物理表面并非绝对光滑的平面，而是布满毫米至厘米尺度的微几何起伏（如皮肤毛孔、岩石裂隙）。1978 年，James F. Blinn 提出了*凹凸贴图*（Bump Mapping）的革命性思想@blinn1978simulation：不改变底层多边形的几何位置，仅在着色计算时利用一张高频纹理对逐像素表面法线 $bold(n)$ 施加微扰动，即可欺骗人眼感知到极其逼真的凹凸明暗细节。

=== 切线空间法线贴图与 $bold(T) bold(B) bold(N)$ 正交基推导

现代引擎普遍采用*法线贴图*（Normal Mapping）直接存储归一化法线向量 $(n_x, n_y, n_z) in [-1, 1]^3$（经仿射变换 $bold(c) = 0.5 bold(n) + 0.5$ 编码为 $[0, 1]^3$ 的 RGB 纹素）。但这些法线应当定义在哪个坐标系下？若直接存储世界空间或模型空间法线，不仅贴图无法在同一模型的不同朝向面片上复用，且当角色网格发生骨骼蒙皮形变时，贴图法线将完全失效。

为此，图形管线在每个三角形表面局部定义*切线空间*（Tangent Space）：以顶点插值法线 $bold(n)$ 为局部 $+z$ 轴，以纹理坐标 $u$ 增加的方向为*切线向量*（Tangent）$bold(t)$，以纹理坐标 $v$ 增加的方向为*副切线向量*（Bitangent）$bold(b)$。由于未受扰动的平坦表面法线在切线空间中恒为 $(0, 0, 1)^top$（编码为 RGB $(0.5, 0.5, 1.0)$），这正是为什么切线空间法线贴图在视觉上总是呈现标志性的浅蓝紫色。

#proposition(title: [由三角形 UV 梯度构造切线空间基向量])[
  设三角形三个顶点的三维空间坐标为 $bold(p)_0, bold(p)_1, bold(p)_2 in RR^3$，对应的纹理坐标为 $(u_0, v_0), (u_1, v_1), (u_2, v_2)$。记边向量 $Delta bold(p)_1 = bold(p)_1 - bold(p)_0$、$Delta bold(p)_2 = bold(p)_2 - bold(p)_0$，纹理坐标差分 $Delta u_1 = u_1 - u_0, Delta v_1 = v_1 - v_0$ 以及 $Delta u_2 = u_2 - u_0, Delta v_2 = v_2 - v_0$。若参数化非退化（即 $Delta u_1 Delta v_2 - Delta u_2 Delta v_1 != 0$），则切线向量 $bold(t)$ 与副切线向量 $bold(b)$ 唯一确定为：
  $ mat(bold(t)^top; bold(b)^top) = (1)/(Delta u_1 Delta v_2 - Delta u_2 Delta v_1) mat(Delta v_2, -Delta v_1; -Delta u_2, Delta u_1) mat(Delta bold(p)_1^top; Delta bold(p)_2^top). $ <eq:ch05-tbn-solve>
]

#proof[
  在三角形平面上，三维位置 $bold(p)$ 是纹理坐标 $(u, v)$ 的仿射线性函数，其偏导数即为切线 $bold(t) = partial bold(p) \/ partial u$ 与副切线 $bold(b) = partial bold(p) \/ partial v$。沿两条三角形边展开线性增量关系：
  $ Delta bold(p)_1 = Delta u_1 bold(t) + Delta v_1 bold(b), quad Delta bold(p)_2 = Delta u_2 bold(t) + Delta v_2 bold(b). $
  将其写成矩阵形式 $mat(Delta bold(p)_1^top; Delta bold(p)_2^top) = mat(Delta u_1, Delta v_1; Delta u_2, Delta v_2) mat(bold(t)^top; bold(b)^top)$，两边左乘 $2 times 2$ 纹理差分矩阵的逆矩阵，立即得到 @eq:ch05-tbn-solve。
]

在工程实现中，网格顶点处的法线 $bold(n)$ 是相邻三角形面法线的加权平均，因此由 @eq:ch05-tbn-solve 算出的 $bold(t)$ 与平滑法线 $bold(n)$ 未必严格正交。顶点或片元着色器需在运行期执行一步 *Gram-Schmidt 正交化*：
$ tilde(bold(t)) = ("normalize")(bold(t) - (bold(n) dot bold(t)) bold(n)), quad tilde(bold(b)) = tau (bold(n) times tilde(bold(t))), $ <eq:ch05-gram-schmidt>
其中手性符号 $tau in {-1, +1}$ 补偿镜像对称 UV 展开。构建出正交矩阵 $bold(M)_"TBN" = mat(tilde(bold(t)), tilde(bold(b)), bold(n)) in "SO"(3)$ 后，从法线贴图采样并解码出的切线空间法线 $bold(n)_"ts" = 2 bold(c)_"tex" - 1$ 只需左乘 $bold(M)_"TBN"$，即可转换到世界空间参与光照计算：$bold(n)_"world" = ("normalize")(bold(M)_"TBN" bold(n)_"ts")$。

=== 视差遮挡贴图（POM）与硬件位移贴图（Displacement Mapping）

法线贴图仅改变了法线方向，却存在三个固有的视觉破绽：(1) 物体边缘的几何剪影轮廓（Silhouette）依然是笔直的多边形直线；(2) 缺乏凹凸结构随视角移动产生的相互遮挡（Self-Occlusion）与运动视差；(3) 不产生局部自阴影。
- *视差遮挡贴图（Parallax Occlusion Mapping, POM）*：在法线贴图之外额外引入一张单通道高度场纹理 $h(u, v) in [0, 1]$。在片元着色器中，将视线向量转换到切线空间 $omega_o^"ts"$，沿着视线方向对高度场 $h(u, v)$ 执行步进光线行进（Ray Marching），搜索视线射线首次跌破高度场曲面的精确交点 $(u^*, v^*) = (u, v) + Delta bold(u)$，再用偏移后的纹理坐标 $(u^*, v^*)$ 去采样反照率与法线贴图。POM 在平坦多边形内部完美模拟了凹凸自遮挡与自阴影，但依然无法改变网格边缘剪影。
- *位移贴图（Displacement Mapping）*：在顶点着色器、曲面细分着色器（Tessellation Shader）或网格着色器（Mesh Shader）阶段，先将粗糙基础网格细分为高密度微三角形，再直接读取高度贴图 $h(u, v)$ 沿顶点法线方向真实移动顶点三维坐标：$bold(p)' = bold(p) + s_h h(u, v) bold(n)$。位移贴图真正改变了几何体表面与剪影轮廓，是现代影视渲染与 Nanite 置换管线的标准手段。

== 现代可编程 GPU 管线、延迟着色（Deferred Shading）与可见性缓冲 <sec:ch05-gpu-pipeline>

当场景中同时存在数万个带有复杂材质的网格物体与数百盏动态点光源/聚光灯时，如何组织渲染管线的几何与光照计算顺序，直接决定了引擎的帧率上限。

=== 前向着色、延迟着色（G-Buffer）与可见性缓冲（Visibility Buffer）

1. *前向着色（Forward Shading）与分簇前向（Forward+）*：传统前向管线在光栅化每个三角形片元时，直接在片元着色器内遍历所有光源计算 @eq:ch05-blinn-phong，复杂度高达 $O(N_"geom" times N_"light")$；且一旦发生深度遮挡（即使有 Early-Z 也无法完全消除），被覆盖片元的光照计算即告浪费。*分块/分簇前向着色*（Tiled / Clustered Forward+）将视锥体划分为三维像素簇（如 $16 times 16 times 24$ 个对数深度切片），先用计算着色器剔除每簇内的无关光源，将复杂度降低至仅遍历局部活跃光源，同时完整保留了硬件 MSAA 与透明物体混合能力。
2. *延迟着色（Deferred Shading）*：将「几何可见性光栅化」与「多光源着色计算」彻底拆分为两个独立阶段（Pass）：
   - *几何阶段（Geometry Pass）*：将所有不透明网格光栅化一次，不计算任何光照，而是把通过深度测试的最前端片元的材质几何属性（世界法线 $bold(n)$、基础反照率 $bold(k)_d$、粗糙度/金属度、运动向量）直接写入多张全屏渲染目标——统称为*几何缓冲（G-Buffer）*（世界坐标 $bold(x)$ 直接由深度缓冲 $z_"ndc"$ 与像素坐标逆投影重建，无需显式存储）。
   - *光照阶段（Lighting Pass）*：以全屏四边形或光源包围球驱动，每个屏幕像素从 G-Buffer 读取材质属性并累加光照。此时只有最终可见的 $N_"pixel"$ 个像素参与光照，时间复杂度降为解耦的 $O(N_"geom" + N_"pixel" times N_"light")$，彻底根除了光照阶段的 Overdraw！但其代价是庞大的 G-Buffer 读写带宽，且硬件 MSAA 与多材质着色模型（如毛发、次表面散射）难以兼容。
3. *可见性缓冲（Visibility Buffer）*@burns2013visibility：2013 年，Christopher A. Burns 与 Warren A. Hunt 指出，G-Buffer 之所以带宽高昂，是因为在光栅化阶段过早求值并存储了完整的材质纹理结果。在 *Visibility Buffer* 架构中，几何光栅化阶段仅输出每个像素的 `PrimitiveID`（图元与实例索引，甚至如第 4 章 Nanite 那样连重心坐标都不存，而是在着色阶段用屏幕坐标与三个变换后顶点实时反解重心坐标与偏导数 $bold(J)_"uv"$）！在随后的材质分类着色阶段，计算着色器根据 `PrimitiveID` 拉取三个顶点属性，手动执行透视校正插值、解析计算 UV 偏导数并采样纹理。这一设计将几何缓冲带宽压缩到了极限（仅 4～8 字节/像素），同时天然避开了亚像素三角形在硬件 Quad 中的辅助片元纹理采样浪费。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 1. Forward+ 管线
    rect((0.3, 3.8), (13.9, 5.2), fill: softbg, stroke: 0.8pt + softline, radius: 0.08)
    content((1.55, 4.5), text(size: 7.8pt, weight: "bold", fill: accent)[Forward+ 管线])
    rect((2.9, 4.05), (5.5, 4.95), fill: white, stroke: 0.8pt + accent, radius: 0.08)
    content((4.2, 4.5), text(size: 7.3pt)[视锥三维簇光源剔除])
    line((5.55, 4.5), (6.35, 4.5), mark: (end: ">"), stroke: 0.9pt + accent)
    rect((6.4, 4.05), (9.9, 4.95), fill: bluebg, stroke: 0.8pt + accent, radius: 0.08)
    content((8.15, 4.5), text(size: 7.3pt)[光栅化 + 纹理采样 + 簇内光照])
    line((9.95, 4.5), (10.75, 4.5), mark: (end: ">"), stroke: 0.9pt + accent)
    rect((10.8, 4.05), (13.6, 4.95), fill: white, stroke: 0.8pt + accent, radius: 0.08)
    content((12.2, 4.5), text(size: 7.3pt)[HDR 颜色缓冲 (支持 MSAA)])

    // 2. Deferred G-Buffer 管线
    rect((0.3, 2.0), (13.9, 3.4), fill: softbg, stroke: 0.8pt + softline, radius: 0.08)
    content((1.55, 2.7), text(size: 7.8pt, weight: "bold", fill: accent2)[延迟着色管线])
    rect((2.9, 2.25), (5.5, 3.15), fill: white, stroke: 0.8pt + accent2, radius: 0.08)
    content((4.2, 2.7), text(size: 7.3pt)[几何光栅 + 纹理采样])
    line((5.55, 2.7), (6.35, 2.7), mark: (end: ">"), stroke: 0.9pt + accent2)
    rect((6.4, 2.25), (9.9, 3.15), fill: redbg, stroke: 0.8pt + warn, radius: 0.08)
    content((8.15, 2.88), text(size: 7.3pt, weight: "bold", fill: warn)[庞大 G-Buffer (16~32 B/px)])
    content((8.15, 2.45), text(size: 7.0pt)[Albedo · 法线 $bold(n)$ · 粗糙度 · 深度])
    line((9.95, 2.7), (10.75, 2.7), mark: (end: ">"), stroke: 0.9pt + accent2)
    rect((10.8, 2.25), (13.6, 3.15), fill: white, stroke: 0.8pt + accent2, radius: 0.08)
    content((12.2, 2.7), text(size: 7.3pt)[全屏/光源体延迟光照 Pass])

    // 3. Visibility Buffer 管线
    rect((0.3, 0.2), (13.9, 1.6), fill: softbg, stroke: 0.8pt + softline, radius: 0.08)
    content((1.55, 0.9), text(size: 7.8pt, weight: "bold", fill: accent.darken(15%))[可见性缓冲管线])
    rect((2.9, 0.45), (5.5, 1.35), fill: white, stroke: 0.8pt + accent, radius: 0.08)
    content((4.2, 0.9), text(size: 7.3pt)[纯几何光栅 (零纹理采样)])
    line((5.55, 0.9), (6.35, 0.9), mark: (end: ">"), stroke: 0.9pt + accent)
    rect((6.4, 0.45), (9.9, 1.35), fill: bluebg, stroke: 0.8pt + accent, radius: 0.08)
    content((8.15, 1.08), text(size: 7.3pt, weight: "bold", fill: accent)[极简 VisBuffer (4~8 B/px)])
    content((8.15, 0.65), text(size: 7.0pt)[InstanceID · TriangleID · Depth])
    line((9.95, 0.9), (10.75, 0.9), mark: (end: ">"), stroke: 0.9pt + accent)
    rect((10.8, 0.45), (13.6, 1.35), fill: white, stroke: 0.8pt + accent, radius: 0.08)
    content((12.2, 0.9), text(size: 7.3pt)[反解重心与偏导 + 材质光照])
  })),
  caption: [现代实时渲染三大架构范式（Forward+、Deferred G-Buffer 与 Visibility Buffer）的数据流与带宽对比。Visibility Buffer 将纹理采样与材质评估彻底推迟到可见性判定之后，兼具低显存带宽与零着色 Overdraw。],
) <fig:ch05-deferred-visbuf>

@fig:ch05-deferred-visbuf 与 @tab:ch05-pipeline-compare 对比了这四种管线的核心架构特征。下面给出一段精炼的现代 GLSL（OpenGL 4.6 / Vulkan 风格）延迟渲染几何阶段着色器代码，展示如何在顶点着色器中执行 Gram-Schmidt 正交化构造 $bold(T) bold(B) bold(N)$ 矩阵，并在片元着色器中完成切线空间法线贴图解码与 G-Buffer 打包输出：

```glsl
// --- Vertex Shader (GLSL 460) ---
#version 460 core
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aNormal;
layout(location = 2) in vec4 aTangent; // xyz: 切线方向, w: 手性符号 (+1 或 -1)
layout(location = 3) in vec2 aUV;

uniform mat4 uModel, uViewProj;
uniform mat3 uNormalMat; // transpose(inverse(mat3(uModel)))

out vec2 vUV;
out mat3 vTBN;

void main() {
    vec3 N = normalize(uNormalMat * aNormal);
    vec3 T = normalize(uNormalMat * aTangent.xyz);
    T = normalize(T - dot(N, T) * N); // Gram-Schmidt 正交化
    vec3 B = cross(N, T) * aTangent.w;
    vTBN = mat3(T, B, N);
    vUV  = aUV;
    gl_Position = uViewProj * (uModel * vec4(aPos, 1.0));
}

// --- Fragment Shader (G-Buffer Geometry Pass) ---
#version 460 core
in vec2 vUV;
in mat3 vTBN;

layout(binding = 0) uniform sampler2D uAlbedoRoughnessMap; // rgb: Albedo, a: Roughness
layout(binding = 1) uniform sampler2D uNormalMap;          // rgb: 切线空间法线

layout(location = 0) out vec4 gAlbedoRoughness; // RT0: 反照率与粗糙度
layout(location = 1) out vec3 gWorldNormal;     // RT1: 世界空间单位法线

void main() {
    vec4 albedoRough = texture(uAlbedoRoughnessMap, vUV);
    vec3 n_ts = texture(uNormalMap, vUV).rgb * 2.0 - 1.0;
    vec3 n_world = normalize(vTBN * n_ts);

    gAlbedoRoughness = albedoRough;
    gWorldNormal     = n_world * 0.5 + 0.5; // 编码至 [0, 1] 写入 UNORM 缓冲
}
```

#figure(
  table(
    columns: (2.3cm, 2.2cm, 2.1cm, 2.5cm, 4.4cm),
    align: (left, center, center, center, left),
    [管线架构], [光照复杂度], [帧缓冲带宽], [硬件 MSAA], [材质多样性与适用场景],
    [传统前向 (Forward)], [$O(N_"geom" times N_"light")$], [低], [原生支持], [材质着色器完全自由；多光源或高 Overdraw 下性能急剧下降],
    [分簇前向 (Forward+)], [$O(N_"geom" times K_"cluster")$], [低～中], [原生支持], [支持复杂异构材质（玻璃/车漆/毛发）与透明混合；VR 与高帧率游戏常用],
    [延迟着色 (Deferred)], [$O(N_"geom" + N_"pixel" N_"light")$], [高 (G-Buffer)], [代价高昂], [彻底消除光照 Overdraw，适合成百上千动态光源；材质参数受 G-Buffer 通道限制],
    [可见性缓冲 (VisBuffer)], [$O(N_"geom" + N_"pixel" N_"light")$], [极低 (4~8B)], [支持子样本 ID], [仅存图元 ID@burns2013visibility，着色时解析求偏导；完美契合微多边形软光栅与神经材质],
  ),
  caption: [前向着色、分簇前向（Forward+）、延迟着色（Deferred G-Buffer）与可见性缓冲（Visibility Buffer）四大 GPU 渲染架构对比。],
) <tab:ch05-pipeline-compare>

== 现代演进：网格着色器（Mesh Shaders）与随机访问神经纹理压缩 <sec:ch05-frontier>

在过去二十年中，可编程 GPU 管线虽然陆续演化出顶点、曲面细分、几何与片元着色器，但在硬件前端（顶点装配 Input Assembler）与材质存储（块压缩纹理 BC1–BC7 / ASTC）两个关键环节上，依然长期受限于固定硬件逻辑与显存容量墙。2020–2026 年间，两项根本性变革正在彻底打破这一局面。

=== 任务/网格着色器（Task & Mesh Shaders）重构几何前端

【已有成果】在传统几何管线中，顶点必须先通过串行的固定功能输入装配器（Input Assembler），且几何着色器（Geometry Shader）因单线程输出缓冲受限而性能低下。现代 DirectX 12 Ultimate 与 Vulkan 引入的*网格着色器管线*（Mesh Shading Pipeline）彻底废除了输入装配器、顶点着色器、曲面细分与几何着色器，将其统一替换为两级具备共享显存（Shared Memory）的协作线程组（Threadgroup，类似 Compute Shader）：
1. *任务着色器（Task / Amplification Shader）*：将大型网格切分为包含 64 个顶点、126 个三角形的微小网格簇——*Meshlet*。每个线程负责评估一个 Meshlet 的包围球与法线锥（Normal Cone），一次性完成视锥剔除、背面簇剔除与遮挡剔除，并动态决定下游需要派发多少个网格着色器线程组。
2. *网格着色器（Mesh Shader）*：整个线程组（如 32 或 64 个线程）协作读取一个可见 Meshlet 的顶点与索引缓冲，在片上高速共享内存中完成顶点变换、程序化几何生成或实时等值面提取，最后直接将三角形图元数组移交给光栅化器。

=== 随机访问神经纹理压缩（Neural Texture Compression, NTC）

【已有成果】在纹理系统一侧，当代 3A 游戏与数字孪生场景中，一个表面点往往需要同时采样反照率、法线、粗糙度、金属度、环境光遮蔽、高度、次表面散射等 8 至 12 个通道的 4K/8K 贴图。传统的硬件块压缩格式（如 BC7 或 ASTC）只能对每张 $4 times 4$ 纹素块独立压缩，无法利用跨通道（如法线变化处往往伴随粗糙度与高度变化）与跨 Mipmap 层级的强相关性，压缩比封顶于 $4:1$ 至 $8:1$。

2023 年，Karthik Vaidyanathan 等人提出了*随机访问神经纹理压缩*（Neural Texture Compression, NTC）@vaidyanathan2023ntc。NTC 的核心突破在于：将同一材质的所有通道贴图及其完整 Mipmap 金字塔联合表示为「多分辨率量化特征网格（Feature Grids）+ 极小型多层感知机（MLP）解码器」。与必须整张解压才能使用的传统深度学习图像压缩（如 JPEG-AI）完全不同，NTC 允许在片元着色器或光线追踪着色器内部，针对任意纹素坐标 $(u, v)$ 与细节层级 $d$ 执行*局部随机访问按需解码*（On-the-fly Random-Access Decoding）：硬件仅读取包含该点的 $2 times 2$ 量化特征潜向量，并在寄存器内利用矩阵乘加指令（Cooperative Vectors / Tensor Cores）运行一个仅有两层、每层 16 个神经元的微型 MLP，单次前向推理即可同时还原出全部材质通道与指定 Mipmap 层级的值，实现了高达 $16:1$ 以上的惊人压缩比与超越 BC7 的视觉保真度@vaidyanathan2023ntc。

【本书推断】当把 Visibility Buffer（@sec:ch05-gpu-pipeline）与神经纹理压缩（NTC）结合审视时，现代材质管线的演进方向豁然开朗：传统延迟渲染之所以无法直接运行高开销的神经材质解码，是因为几何阶段存在大量被覆盖的无效片元（Overdraw）以及 G-Buffer 无法容纳高维神经特征；而在 Visibility Buffer 架构下，只有最终可见的那个像素才会在着色阶段触发一次 NTC 神经网络推理。由此，「Meshlet 网格着色器 + Visibility Buffer + 随机访问神经材质解码」正在构成下一代实时神经图形管线的黄金三角。

#keybox(title: [本章要点])[
  1. *经验局部光照与半程向量*：Blinn-Phong 模型引入半程向量 $bold(h) = ("normalize")(omega_i + omega_o)$ 替代反射向量，消除了掠射角高光截断并契合微表面法线物理意义，但缺乏归一化因子与菲涅耳/几何遮蔽项，违背能量守恒。
  2. *纹理重采样与各向异性过滤*：Mipmap 仅以 $33.3%$ 的额外显存代价预计算多尺度低通金字塔，并通过 $2 times 2$ Quad 的屏幕偏导数雅可比矩阵 $bold(J)_"uv"$ 决定三线性插值层级 $d = log_2 L$；各向异性过滤（AF）则通过短轴定层、长轴多点采样克服了倾斜表面的各向同性过度模糊。
  3. *切线空间与几何凹凸*：通过三角形边向量与 UV 差分方程 @eq:ch05-tbn-solve 配合 Gram-Schmidt 正交化构造 $bold(T) bold(B) bold(N)$ 矩阵，使切线空间法线贴图可随任意网格形变复用；视差遮挡贴图（POM）通过切线空间光线行进补充了自遮挡视差。
  4. *现代 GPU 渲染架构*：延迟着色利用 G-Buffer 将复杂度从 $O(N_"geom" times N_"light")$ 降至 $O(N_"geom" + N_"pixel" times N_"light")$，而可见性缓冲（Visibility Buffer）进一步将纹理采样与神经纹理压缩（NTC）解码推迟到可见性判定之后，实现了极致的带宽与算力效率。
]
