#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 微表面材质模型与蒙特卡洛路径追踪

第 9 章建立了光线几何求交机制与 Kajiya 渲染方程的算子理论，但要在工程中真正合成出照片级真实感图像，还必须回答两个核心问题：第一，真实世界中从抛光金属、拉丝合金到粗糙塑料、磨砂玻璃的千变万化材质，其双向反射分布函数 $f_r (bold(x), omega_i, omega_o)$ 应当如何从微观几何与电磁光学第一性原理构造？第二，渲染方程在无限步弹射下对应无穷维路径空间积分，如何构造无偏、低方差且在高光与复杂光源配置下均稳健收敛的数值积分器？

本章系统解答这两个问题。我们先从统计光学微表面理论出发，完整推导包含半程向量雅可比变换、GGX 法线分布函数、Smith 高度相关遮蔽—阴影函数与 Fresnel 方程的 Cook-Torrance 镜面 BRDF（@sec:ch10-microfacet）；接着剖析工业界标准的 Disney / glTF 金属度—粗糙度（Metallic-Roughness）PBR 工作流与 Kulla-Conty 多散射能量补偿方案（@sec:ch10-disney-pbr）；随后严格建立蒙特卡洛积分理论，推导余弦加权半球与 GGX 微法线的逆变换采样公式（@sec:ch10-monte-carlo）；进而构建融合光源直接采样（NEE）、俄罗斯轮盘赌（Russian Roulette）与多重重要性采样（MIS）的现代路径追踪算法（@sec:ch10-pathtracing）；最后拓展至参与介质辐射传输方程（RTE）与实时时空降噪前沿（@sec:ch10-frontier）。

== 微表面理论（Microfacet BRDF）：GGX 法线分布、Smith 遮蔽与菲涅尔项 <sec:ch10-microfacet>

微表面理论（Microfacet Theory）由 Torrance、Sparrow 与 Cook 等人引入计算机图形学 @cook1982reflectance，并由 Walter 等人拓展至粗糙折射与广义散射分布 @walter2007microfacet。其基本物理图景如 @fig:ch10-microfacet 所示：宏观上看似平坦的粗糙表面微元 $dif A$（宏观外法线为 $bold(n) in SS^2$），在微米尺度下是由无数朝向各异的理想镜面微平面（Microfacets，微法线为 $bold(m) in SS^2$）组成的随机高度场。对于给定入射方向 $omega_i$ 与出射方向 $omega_o$，根据镜面反射定律，唯有微法线恰好对齐*半程向量*（Half-Vector）
$ bold(h) = ("normalize")(omega_i + omega_o) = (omega_i + omega_o) / (norm(omega_i + omega_o)) $ <eq:ch10-half-vector>
的活性微面元（$bold(m) = bold(h)$），才能将来自 $omega_i$ 的入射光反射至 $omega_o$。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 左侧：微表面几何遮蔽(Shadowing)与掩蔽(Masking)
    rect((0.2, 0.3), (7.5, 4.9), fill: softbg, stroke: 0.9pt + accent, radius: 0.1)
    content((3.85, 4.58), text(size: 8pt, weight: "bold", fill: accent.darken(20%))[微表面高度场：法线分布 $D(bold(h))$ 与几何遮蔽 $G(omega_i, omega_o)$])
    // 宏观平面虚线
    line((0.5, 1.0), (7.2, 1.0), stroke: (dash: "dashed", paint: gray.darken(20%), thickness: 0.8pt))
    content((6.3, 0.7), text(size: 7pt, fill: gray.darken(30%))[宏观表面 $dif A$ ($bold(n)$)])
    // 微表面折线轮廓
    line((0.5, 1.4), (1.4, 2.3), (2.2, 1.2), (3.3, 2.5), (4.3, 1.3), (5.4, 2.4), (6.4, 1.4), (7.1, 2.0), stroke: 1.4pt + ink)
    // 宏观法线 n 与微法线 h
    line((3.8, 1.9), (3.8, 3.7), mark: (end: ">"), stroke: 0.85pt + gray.darken(30%))
    content((3.55, 3.65), text(size: 7.2pt)[$bold(n)$])
    line((3.8, 1.9), (4.45, 3.55), mark: (end: ">"), stroke: 1.0pt + accent)
    content((4.75, 3.5), text(size: 7.5pt, weight: "bold", fill: accent)[$bold(m) = bold(h)$])
    // 有效单次反射光线
    line((2.5, 3.6), (3.8, 1.9), mark: (end: ">"), stroke: 0.95pt + accent2)
    content((2.3, 3.8), text(size: 7.2pt, fill: accent2)[$omega_i$])
    line((3.8, 1.9), (5.5, 3.1), mark: (end: ">"), stroke: 0.95pt + accent)
    content((5.7, 3.25), text(size: 7.2pt, fill: accent)[$omega_o$])
    // 阴影遮挡 Shadowing 与 视线掩蔽 Masking 标注
    line((0.9, 3.3), (1.85, 1.68), mark: (end: ">"), stroke: (dash: "dotted", paint: warn, thickness: 0.9pt))
    content((1.4, 3.55), text(size: 7pt, fill: warn)[阴影遮挡 (Shadowing)])
    line((4.05, 1.58), (5.05, 2.15), mark: (end: ">"), stroke: (dash: "dotted", paint: warn, thickness: 0.9pt))
    content((5.35, 1.08), text(size: 7pt, fill: warn)[视线掩蔽 (Masking)])

    // 右侧：多次散射与 Kulla-Conty 能量补偿
    rect((7.9, 0.3), (14.2, 4.9), fill: softbg, stroke: 0.9pt + accent2, radius: 0.1)
    content((11.05, 4.58), text(size: 8pt, weight: "bold", fill: accent2.darken(20%))[高粗糙度 V 型微腔多次弹射与能量补偿])
    line((8.4, 3.0), (10.2, 1.1), (12.0, 3.1), (13.6, 1.5), stroke: 1.4pt + ink)
    // 入射光在微腔内两次反射后出射
    line((8.8, 4.0), (9.6, 1.75), mark: (end: ">"), stroke: 1.0pt + accent2)
    line((9.6, 1.75), (11.3, 2.32), mark: (end: ">"), stroke: 1.0pt + warn)
    line((11.3, 2.32), (12.3, 4.05), mark: (end: ">"), stroke: 1.0pt + accent)
    content((9.1, 4.15), text(size: 7.2pt, fill: accent2)[入射 $omega_i$])
    content((10.55, 2.38), frame: "rect", fill: white, stroke: none, padding: 0.04, text(size: 6.8pt, fill: warn)[二次微面弹射])
    content((12.6, 4.15), text(size: 7.2pt, fill: accent)[补偿出射 $f_"ms"$])
    content((11.05, 0.72), text(size: 7.2pt)[单散射 $G_2$ 丢弃二次弹射能量 $=> 1 - E(omega_o)$ 暗化])
  })),
  caption: [微表面高度场几何光学原理示意图。左图展示仅有微法线 $bold(m) = bold(h)$ 的微面元对反射有贡献，邻近微凸起会产生入射阴影遮挡（Shadowing）与出射视线掩蔽（Masking）；右图展示粗糙表面微腔内的多次散射路径，解释了单散射模型在高粗糙度下能量损失的成因。],
) <fig:ch10-microfacet>

=== Cook-Torrance 微表面 BRDF 与半程向量雅可比项推导

#definition(title: [Cook-Torrance 单散射微表面镜面 BRDF @cook1982reflectance @walter2007microfacet])[
各向同性或各向异性粗糙表面的单散射微表面镜面反射 BRDF 由下式给出：
$ f_"spec" (omega_i, omega_o) = (D(bold(h)) F(omega_o, bold(h)) G_2 (omega_i, omega_o)) / (4 (bold(n) dot omega_i) (bold(n) dot omega_o)), $ <eq:ch10-cook-torrance>
其中 $D(bold(h))$ 为微法线分布函数（Normal Distribution Function, NDF，$["sr"^(-1)]$），$F(omega_o, bold(h))$ 为微面元 Fresnel 反射率，$G_2 (omega_i, omega_o)$ 为双向几何遮蔽—掩蔽函数（无量纲，取值 $[0, 1]$）。
]

式 @eq:ch10-cook-torrance 分母中因子 $4 (bold(n) dot omega_i)(bold(n) dot omega_o)$ 的严格起源是微表面散射推导的核心。设宏观表面积为 $dif A$，法线处于立体角微元 $dif omega_h$ 内的微平面总面积为 $D(bold(h)) dif omega_h dif A$。这些微平面沿入射方向 $omega_i$ 的有效投影面积为 $(omega_i dot bold(h)) D(bold(h)) dif omega_h dif A$，故截获的入射辐射通量为 $dif Phi_i = L_i (omega_i) (omega_i dot bold(h)) D(bold(h)) dif omega_h dif omega_i dif A$。经 Fresnel 反射率 $F(omega_o, bold(h))$ 衰减与几何可见比例 $G_2 (omega_i, omega_o)$ 调制后，反射进入出射立体角 $dif omega_o$ 的辐射亮度为：
$ dif L_o (omega_o) = (dif Phi_o) / ((bold(n) dot omega_o) dif omega_o dif A) = (L_i (omega_i) (omega_i dot bold(h)) F(omega_o, bold(h)) G_2 (omega_i, omega_o) D(bold(h))) / ((bold(n) dot omega_o)) (dif omega_h) / (dif omega_o) dif omega_i. $ <eq:ch10-micro-flux>
固定入射方向 $omega_i$，出射方向 $omega_o = 2(omega_i dot bold(h)) bold(h) - omega_i$ 是关于微法线 $bold(h)$ 的镜面反射映射。设 $omega_i$ 与 $bold(h)$ 的夹角为 $theta_h$，则 $omega_i$ 与 $omega_o$ 的夹角为 $theta_o' = 2 theta_h$。在以 $omega_i$ 为极轴的球坐标系下，$dif theta_o' = 2 dif theta_h$ 且 $sin theta_o' = sin(2 theta_h) = 2 sin theta_h cos theta_h$，因此微法线立体角微元与出射立体角微元的*镜面反射雅可比行列式*（Half-Vector Jacobian）为：
$ J_h = (dif omega_h) / (dif omega_o) = (sin theta_h dif theta_h dif phi) / (sin(2 theta_h) dif(2 theta_h) dif phi) = (1) / (4 cos theta_h) = (1) / (4 (omega_o dot bold(h))) = (1) / (4 (omega_i dot bold(h))). $ <eq:ch10-half-jacobian>
将雅可比关系 @eq:ch10-half-jacobian 代入 @eq:ch10-micro-flux，分子分母中的 $(omega_i dot bold(h))$ 精确约去，再除以微分入射辐照度 $dif E_i = L_i (omega_i)(bold(n) dot omega_i) dif omega_i$，即严格导出式 @eq:ch10-cook-torrance。

=== Trowbridge-Reitz (GGX) 法线分布、Smith 遮蔽与 Schlick 菲涅尔

微表面三要素的标准现代参数化如下：
1. *Trowbridge-Reitz / GGX 法线分布函数* @walter2007microfacet：相比早期高斯型 Beckmann 分布，GGX 具有显著的「长尾（Long-Tailed）」衰减特性——高光核心集中锐利，同时向周围延伸出柔和的高光光晕，极度契合真实金属与电介质测量数据。记粗糙度参数为 $alpha in (0, 1]$，各向同性 GGX 分布定义为：
   $ D_"GGX" (bold(h)) = (alpha^2) / (pi ((bold(n) dot bold(h))^2 (alpha^2 - 1) + 1)^2), $ <eq:ch10-ggx-ndf>
   满足投影面积归一化守恒条件 $integral_(Omega^+) D(bold(h)) (bold(n) dot bold(h)) dif omega_h = 1$。
2. *Smith 高度相关几何遮蔽—掩蔽函数* @heitz2014understanding：早期模型假设入射遮挡 $G_1 (omega_i)$ 与出射掩蔽 $G_1 (omega_o)$ 统计独立（即 $G_2 = G_1 (omega_i) G_1 (omega_o)$），忽略了当 $omega_i approx omega_o$ 时微面高度之间的强正相关性，导致过度暗化。Heitz @heitz2014understanding 严格证明了匹配 GGX 微表面斜率分布的 Smith 高度相关遮蔽函数为：
   $ G_2 (omega_i, omega_o) = (1) / (1 + Lambda(omega_i) + Lambda(omega_o)), quad Lambda(omega) = (-1 + sqrt(1 + alpha^2 tan^2 theta_omega)) / (2), $ <eq:ch10-smith-g2>
   其中 $tan^2 theta_omega = (1 - (bold(n) dot omega)^2) \/ (bold(n) dot omega)^2$。将其与式 @eq:ch10-cook-torrance 的分母合并，可消去公因子从而避免掠射角除零不稳定。
3. *Schlick 菲涅尔近似*：精确求解 Maxwell 边界条件下的 Fresnel 反射率涉及复折射率运算；Schlick 提出用五次多项式高精度逼近任意角度反射率：
   $ F(omega_o, bold(h)) = F_0 + (1 - F_0)(1 - max(0, omega_o dot bold(h)))^5, $ <eq:ch10-schlick>
   其中 $F_0 = ((eta_t - eta_i) \/ (eta_t + eta_i))^2$ 为垂直入射（$theta_h = 0$）时的基础反射率。

== 金属度—粗糙度（Disney / glTF PBR）工作流与多散射能量补偿 <sec:ch10-disney-pbr>

在物理光学上，材料根据能带结构分为两大类：*电介质*（Dielectrics，如水、塑料、陶瓷、皮肤）折射率接近实数，垂直入射菲涅尔反射率很低且基本无色（通常 $F_0 approx 0.02 ~ 0.05$，工业界统一取均值 $0.04$），穿透界面的折射光经次表面多次散射后重新穿出形成有色漫反射；*导体/金属*（Conductors/Metals，如金、铜、铝）具有自由电子，穿透光在极浅趋肤深度内即被完全吸收，故*金属不存在漫反射分量*，且其垂直反射率 $F_0 in [0.5, 1.0]$ 在可见光谱上呈现强烈波长选择性（即有色镜面反射）。

Burley @burley2012physically 在迪士尼动画（Disney Principled BRDF）中提出将电介质与金属统一到单套艺术家友好的参数空间，后被 Unreal Engine、Unity 与 Khronos glTF 2.0 采纳为标准「金属度—粗糙度（Metallic-Roughness）」工作流：
- *感知粗糙度重映射*：艺术家调节线性感知粗糙度 $r in [0, 1]$，着色器通过平方映射 $alpha = r^2$ 转换为 GGX 光学粗糙度，使滑块在低粗糙度区间具有均匀的视觉高光变化率。
- *基础色与金属度插值*：给定基础颜色纹理 $bold(c)_"base" in [0, 1]^3$ 与金属度 $m in [0, 1]$，基础菲涅尔反射率与有效漫反射反照率分别由线性插值确定：
  $ bold(F)_0 = (1 - m) bold(0.04) + m bold(c)_"base", quad bold(rho)_"partial" = (1 - m) bold(c)_"base". $ <eq:ch10-metallic-workflow>
  合成 BRDF 为漫反射项（Lambertian 或含掠射逆反射的 Disney 漫反射）与微表面镜面项 @eq:ch10-cook-torrance 的能量守恒加权和：$f_r = (1 - F(omega_o, bold(h))) (bold(rho)_"partial" \/ pi) + f_"spec" (omega_i, omega_o)$。

=== Kulla-Conty 多散射能量补偿

如 @fig:ch10-microfacet 右图所示，式 @eq:ch10-cook-torrance 仅统计了在微表面上发生*单次反射*即逃逸的光线；被 $G_2$ 判定为遮挡的光线实际上会在微腔内发生二次、三次散射并最终重新逃逸。当粗糙度 $alpha -> 1$ 时，单散射模型的方向—半球反射率 $E(omega_o) = integral_(Omega^+) f_"spec" (omega_i, omega_o) cos theta_i dif omega_i$ 可跌落至 $0.4$ 以下，导致粗糙金属呈现严重的非物理变暗。Kulla 与 Conty @kulla2017revisiting 提出添加可分离的互易多散射补偿项 $f_"ms" (omega_i, omega_o)$：
$ f_"ms" (omega_i, omega_o) = ((1 - E(omega_i))(1 - E(omega_o))) / (pi (1 - E_"avg")) dot (bold(F)_"avg" E_"avg") / (1 - bold(F)_"avg" (1 - E_"avg")), $ <eq:ch10-kulla-conty>
其中 $E_"avg" = 2 integral_0^1 E(mu) mu dif mu$ 为半球平均单散射反射率，$bold(F)_"avg"$ 为半球平均菲涅尔项。可以严格验证：当理想白金属（$bold(F)_"avg" = bold(1)$）叠加上 $f_"ms"$ 后，对任意粗糙度均有总半球反射率 $E(omega_o) + integral_(Omega^+) f_"ms" cos theta_i dif omega_i = 1$，而 $E(mu)$ 与 $E_"avg"$ 仅依赖 $(cos theta, alpha)$，可预计算为一张 $32 times 32$ 的轻量级查找表（LUT）。

== 蒙特卡洛积分、方差分析、逆变换采样与重要性采样 <sec:ch10-monte-carlo>

给定复杂的微表面 BRDF 与场景几何，渲染方程 @eq:ch09-rendering-eq-hemi 无法求得解析原函数，而传统确定性黎曼求积（Quadrature）在 $d$ 维空间（对应 $d \/ 2$ 次弹射）下的收敛阶为 $O(N^(-1/d))$，遭遇致命的「维数灾难」。蒙特卡洛积分（Monte Carlo Integration）通过随机采样将收敛速率从空间维数 $d$ 中彻底解耦 @pharr2023pbrt。

#definition(title: [蒙特卡洛重要性采样估计量（Monte Carlo Estimator）])[
设欲计算积分域 $Omega subset.eq RR^d$ 上的定积分 $I = integral_Omega f(x) dif x$。选取定义在 $Omega$ 上的概率密度函数（PDF）$p(x)$，满足归一化条件 $integral_Omega p(x) dif x = 1$ 以及支撑集覆盖条件（对一切 $f(x) != 0$ 的点有 $p(x) > 0$）。从 $p(x)$ 中独立同分布（i.i.d.）地抽取 $N$ 个随机样本 $X_1, X_2, dots, X_N tilde p(x)$，定义 $N$ 样本蒙特卡洛重要性采样估计量为：
$ hat(I)_N = (1) / (N) sum_(i=1)^N (f(X_i)) / (p(X_i)). $ <eq:ch10-mc-estimator>
]

#theorem(title: [蒙特卡洛估计量的无偏性与方差收敛率 @pharr2023pbrt])[
式 @eq:ch10-mc-estimator 定义的估计量 $hat(I)_N$ 是积分真值 $I$ 的无偏估计量（即 $EE[hat(I)_N] = I$），其方差与标准差收敛率分别为：
$ "Var"[hat(I)_N] = (1) / (N) "Var"[(f(X)) / (p(X))] = (1) / (N) integral_Omega ((f(x)) / (p(x)) - I)^2 p(x) dif x, quad sigma[hat(I)_N] = O(N^(-1/2)). $ <eq:ch10-mc-variance>
]

由 @eq:ch10-mc-variance 可见：(1) 蒙特卡洛误差以 $O(N^(-1/2))$ 衰减，与积分维数无关（样本数增加 4 倍，噪点减半）；(2) 若采样分布 $p(x)$ 的形状与被积函数 $|f(x)|$ 越成正比，商 $f(x) \/ p(x)$ 越平坦，方差就越小（理想情况下若 $p(x) = f(x) \/ I$，则方差恒为零）。

=== 逆变换采样：余弦加权半球与 GGX 微法线采样

设给定两个独立的均匀随机数 $xi_1, xi_2 tilde cal(U)[0, 1)$，通过累积分布函数（CDF）求逆 $X = F^(-1)(xi)$ 可将均匀分布精确映射为目标分布 $p(x)$：
1. *余弦加权半球采样（Cosine-Weighted Hemisphere Sampling）*：针对漫反射积分中的 $cos theta_i$ 因子，构造立体角概率密度 $p(omega) = (cos theta) \/ pi$。变换至球坐标 $(theta, phi)$，由概率守恒 $p(theta, phi) dif theta dif phi = p(omega) sin theta dif theta dif phi$ 得联合密度 $p(theta, phi) = (cos theta sin theta) \/ pi$。对 $phi$ 积分得边缘密度 $p(theta) = 2 sin theta cos theta$，其累积分布函数为 $F(theta) = sin^2 theta = 1 - cos^2 theta$。令 $F(theta) = xi_1$、$F(phi) = phi \/ (2 pi) = xi_2$，即得解析采样公式（等价于单位圆盘均匀采样后向半球垂直投影的 Malley 方法）：
   $ cos theta = sqrt(1 - xi_1), quad sin theta = sqrt(xi_1), quad phi = 2 pi xi_2. $ <eq:ch10-cosine-sample>
2. *GGX 微法线重要性采样* @walter2007microfacet：微表面镜面项受 $D_"GGX" (bold(h)) (bold(n) dot bold(h))$ 主导。对球坐标积分求逆可得半程向量天顶角与方位角采样公式：
   $ tan^2 theta_h = (alpha^2 xi_1) / (1 - xi_1) quad <=> quad cos theta_h = sqrt((1 - xi_1) / (1 + (alpha^2 - 1) xi_1)), quad phi_h = 2 pi xi_2. $ <eq:ch10-ggx-sample>
   采样出微法线 $bold(h)$ 后，通过镜面反射 $omega_i = 2(omega_o dot bold(h)) bold(h) - omega_o$ 得到入射方向；由雅可比换算 @eq:ch10-half-jacobian，该入射方向关于立体角 $dif omega_i$ 的概率密度为 $p(omega_i) = D_"GGX" (bold(h)) (bold(n) dot bold(h)) \/ (4 (omega_o dot bold(h)))$（现代生产渲染器进一步采用 Heitz 的可见法线分布采样 VNDF @heitz2014understanding，消除掠射角背向微面导致的无效反射光线）。

== 路径追踪算法：光源直接采样（NEE）、俄罗斯轮盘赌与多重重要性采样（MIS） <sec:ch10-pathtracing>

朴素路径追踪（Naive Path Tracing）在每次命中表面时仅按 BSDF 分布采样下一跳方向，唯有光线偶然撞上光源（$L_e > 0$）才获得非零贡献。当场景光源体积很小时，随机射线击中光源的概率趋近于零，产生极端方差（高亮噪点 Fireflies）。现代路径追踪通过三项核心机制解决这一难题：

1. *光源直接采样（Next-Event Estimation, NEE）*：如第 9 章 Neumann 级数所示，将反射积分拆分为「直接光照（来自发光表面 $cal(M)_"light"$）」与「间接光照（来自非发光表面反射）」两部分。在路径每个顶点 $bold(x)$ 处，显式在面光源表面按面积密度 $p_A (bold(y)) = 1 \/ A_"light"$ 采样一点 $bold(y) in cal(M)_"light"$，将其通过雅可比关系 @eq:ch09-jacobian 换算为立体角概率密度：
   $ p_"light" (omega_i) = p_A (bold(y)) (norm(bold(x) - bold(y))^2) / (cos theta_y), $ <eq:ch10-light-pdf>
   并发射阴影光线测试可见性 $V(bold(x) <-> bold(y))$。同时，若下一跳 BSDF 采样光线直接命中光源，在纯 NEE 下需将其自发光置零以免双重计数（Double Counting）。
2. *俄罗斯轮盘赌（Russian Roulette）无偏路径终止*：为避免无限长路径且不引入截断偏差（Bias），在路径第 $k$ 跳设定存活概率 $q in (0, 1]$（通常取当前路径吞吐量最大通道值 $q = min(0.95, max(bold(beta)_k))$）：以概率 $1 - q$ 立即终止路径并返回 $0$；以概率 $q$ 继续追踪并将路径权重除以 $q$。其期望满足 $EE[hat(L)_"RR"] = q dot (L \/ q) + (1 - q) dot 0 = L$，严格保持无偏性。

=== 多重重要性采样（MIS）与平衡/幂启发式

单纯依赖光源采样或 BSDF 采样均存在盲区（见 @fig:ch10-mis-nee 左图）：对粗糙表面配小光源，光源采样极佳而 BSDF 采样几乎无法命中光源；反之，对近乎镜面的光滑表面配大型面光源（或环境贴图），光源采样绝大部分落在镜面高光瓣之外（权重接近零），而 BSDF 采样却能精准沿镜面方向拾取辐射。Veach 在其博士论文中提出了奠基性的多重重要性采样（Multiple Importance Sampling, MIS）理论 @veach1997robust：

#theorem(title: [多重重要性采样（MIS）与平衡/幂启发式 @veach1997robust])[
设有 $S$ 种不同的采样策略，第 $s$ 种策略以概率密度 $p_s (x)$ 抽取 $n_s$ 个样本 $X_(s, 1), dots, X_(s, n_s)$。若各策略的加权函数 $w_s (x)$ 在一切 $f(x) != 0$ 处满足单位分解条件 $sum_(s=1)^S w_s (x) = 1$（且当 $p_s (x) = 0$ 时 $w_s (x) = 0$），则联合 MIS 估计量
$ hat(I)_"MIS" = sum_(s=1)^S (1) / (n_s) sum_(i=1)^(n_s) w_s (X_(s, i)) (f(X_(s, i))) / (p_s (X_(s, i))) $ <eq:ch10-mis-estimator>
是无偏的。其中，*平衡启发式（Balance Heuristic）* 与指数为 $beta$（通常取 $beta = 2$）的 *幂启发式（Power Heuristic）* 权重定义为：
$ w_s^"bal" (x) = (n_s p_s (x)) / (sum_(k=1)^S n_k p_k (x)), quad w_s^"pow" (x) = ((n_s p_s (x))^beta) / (sum_(k=1)^S (n_k p_k (x))^beta). $ <eq:ch10-mis-weights>
]

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 左侧：BSDF 采样与光源采样的互补性及 MIS 融合
    rect((0.2, 0.3), (7.6, 5.1), fill: softbg, stroke: 0.9pt + accent, radius: 0.1)
    content((3.9, 4.78), text(size: 8pt, weight: "bold", fill: accent.darken(20%))[Veach 双采样分布互补与 MIS 自适应加权])
    // 小光源 + 粗糙表面
    line((0.6, 2.8), (3.5, 2.8), stroke: 1.3pt + ink)
    rect((2.5, 4.2), (3.1, 4.38), fill: warn, stroke: 0.7pt + warn)
    content((2.1, 4.3), text(size: 6.8pt, fill: warn)[小光源])
    arc((2.7, 2.8), start: 0deg, stop: 180deg, radius: 0.65, fill: bluebg, stroke: 0.8pt + accent)
    line((2.05, 2.8), (2.8, 4.2), mark: (end: ">"), stroke: 0.9pt + warn)
    content((2.05, 2.48), text(size: 7pt)[粗糙表面 ($p_"light" >> p_"bsdf" => w_"light" approx 1$)])
    // 大光源 + 光滑镜面
    line((4.1, 1.0), (7.3, 1.0), stroke: 1.3pt + ink)
    rect((4.3, 4.1), (7.1, 4.28), fill: accent2, stroke: 0.7pt + accent2)
    content((5.7, 4.46), text(size: 6.8pt, fill: accent2.darken(20%))[大型面光源 / 环境贴图])
    // 尖锐高光瓣
    line((5.5, 1.0), (6.35, 2.65), (6.65, 2.45), close: true, fill: bluebg, stroke: 0.85pt + accent)
    line((5.5, 1.0), (6.88, 4.1), mark: (end: ">"), stroke: 0.95pt + accent)
    line((5.5, 1.0), (4.7, 4.1), mark: (end: ">"), stroke: (dash: "dashed", paint: gray.darken(20%), thickness: 0.75pt))
    content((5.7, 0.65), text(size: 7pt)[光滑镜面 ($p_"bsdf" >> p_"light" => w_"bsdf" approx 1$)])

    // 右侧：统一 NEE + MIS + RR 路径追踪管线
    rect((8.0, 0.3), (14.2, 5.1), fill: softbg, stroke: 0.9pt + accent2, radius: 0.1)
    content((11.1, 4.78), text(size: 8pt, weight: "bold", fill: accent2.darken(20%))[单条路径追踪循环（NEE + MIS + RR）])

    rect((8.35, 3.65), (13.85, 4.35), fill: bluebg, stroke: 0.8pt + accent, radius: 0.08)
    content((11.1, 4.0), text(size: 7.3pt)[1. BVH 求交命中顶点 $bold(x)_k$（跳数 $k=0$ 累加 $bold(L)_e$）])

    rect((8.35, 2.65), (13.85, 3.35), fill: rgb("#f2efe6"), stroke: 0.8pt + accent2, radius: 0.08)
    content((11.1, 3.0), text(size: 7.3pt)[2. NEE 光源采样 $omega_l tilde p_"light"$，乘权重 $w_"light" (omega_l)$])

    rect((8.35, 1.65), (13.85, 2.35), fill: bluebg, stroke: 0.8pt + accent, radius: 0.08)
    content((11.1, 2.0), text(size: 7.3pt)[3. BSDF 采样下一跳 $omega_b tilde p_"bsdf"$；若命中光源乘 $w_"bsdf"$])

    rect((8.35, 0.65), (13.85, 1.35), fill: rgb("#f2efe6"), stroke: 0.8pt + warn, radius: 0.08)
    content((11.1, 1.0), text(size: 7.3pt)[4. 俄罗斯轮盘赌（概率 $q$）：更新吞吐量 $bold(beta) arrow.l bold(beta) \/ q$])

    line((11.1, 3.65), (11.1, 3.35), mark: (end: ">"), stroke: 0.8pt + accent)
    line((11.1, 2.65), (11.1, 2.35), mark: (end: ">"), stroke: 0.8pt + accent2)
    line((11.1, 1.65), (11.1, 1.35), mark: (end: ">"), stroke: 0.8pt + warn)
  })),
  caption: [多重重要性采样（MIS）互补机理（左）与现代路径追踪主循环（右）。左图展示光源采样在粗糙表面/小光源下占优，而 BSDF 采样在光滑镜面/大光源下占优；右图展示在每一跳同时执行 NEE 与 BSDF 采样并通过 MIS 权重无缝融合的完整流程。],
) <fig:ch10-mis-nee>

当每次弹射各取 1 个样本（$n_1 = n_2 = 1$）时，平衡启发式将联合估计量转化为等价于合成分布 $(p_1 + p_2) \/ 2$ 的采样，Veach 证明其方差与理论最优权重组合的差距不超过常数上界；幂启发式（$beta = 2$）则进一步压制低概率密度策略的尾部方差。@tab:ch10-sampling-strategies 总结了五种核心采样策略的数学表达与适用场景。

#figure(
  table(
    columns: (2.6cm, 3.6cm, 2.7cm, 2.7cm, 2.6cm),
    align: (left, center, left, left, left),
    [*采样策略*], [*立体角概率密度 $p(omega_i)$*], [*主导匹配项*], [*优势场景*], [*失效/高方差场景*],
    [均匀半球采样], [$1 \/ (2 pi)$], [无（常数密度）], [基线验证], [掠射角与高光严重噪点],
    [余弦加权半球], [$(bold(n) dot omega_i) \/ pi$], [Lambertian $cos theta_i$], [粗糙漫反射表面], [光滑镜面与小光源],
    [GGX 微法线采样], [$D(bold(h))(bold(n) dot bold(h)) \/ (4(omega_o dot bold(h)))$], [微表面 $D_"GGX" (bold(h))$], [光滑/中等粗糙金属], [极小面积点/面光源],
    [光源直接采样 (NEE)], [$norm(bold(x) - bold(y))^2 \/ (A_"light" cos theta_y)$], [光源分布 $L_e$], [小光源照射粗糙表面], [光滑镜面反射大光源],
    [多重重要性采样], [混合 $p_"light"$ 与 $p_"bsdf"$ ($beta=2$)], [$f_r cos theta_i times L_e$], [*全粗糙度与全光源尺寸*], [被遮挡复杂焦散路径],
  ),
  caption: [蒙特卡洛路径追踪中五类典型采样策略的概率密度函数与方差特性对比],
) <tab:ch10-sampling-strategies>

下面给出包含 Disney/glTF GGX 微表面 BRDF 评估、重要性采样 PDF 计算以及幂启发式 MIS 权重的 Python（NumPy）实现：

```python
import numpy as np

def eval_ggx_pbr_and_pdf(n: np.ndarray, wi: np.ndarray, wo: np.ndarray,
                         base_color: np.ndarray, metallic: float, roughness: float):
    """计算金属度-粗糙度 PBR BRDF 值 f_r 与 GGX 半程向量采样立体角 PDF"""
    ndoti, ndoto = np.clip(np.dot(n, wi), 0.0, 1.0), np.clip(np.dot(n, wo), 0.0, 1.0)
    if ndoti <= 1e-6 or ndoto <= 1e-6:
        return np.zeros(3), 0.0
    h = wi + wo
    h /= np.linalg.norm(h)
    ndoth, odoth = np.clip(np.dot(n, h), 0.0, 1.0), np.clip(np.dot(wo, h), 1e-6, 1.0)
    alpha = max(roughness ** 2, 1e-3)
    a2 = alpha * alpha

    # 1. GGX NDF D(h), 2. Smith height-correlated G2, 3. Schlick Fresnel F
    denom_d = (ndoth * ndoth * (a2 - 1.0) + 1.0)
    D = a2 / (np.pi * denom_d * denom_d)
    lam_i = 0.5 * (-1.0 + np.sqrt(1.0 + a2 * (1.0 - ndoti * ndoti) / (ndoti * ndoti)))
    lam_o = 0.5 * (-1.0 + np.sqrt(1.0 + a2 * (1.0 - ndoto * ndoto) / (ndoto * ndoto)))
    G2 = 1.0 / (1.0 + lam_i + lam_o)
    f0 = (1.0 - metallic) * np.full(3, 0.04) + metallic * base_color
    F = f0 + (1.0 - f0) * ((1.0 - odoth) ** 5)

    f_spec = (D * G2 / (4.0 * ndoti * ndoto)) * F
    f_diff = (1.0 - F) * (1.0 - metallic) * (base_color / np.pi)
    pdf_ggx = (D * ndoth) / (4.0 * odoth)
    return f_diff + f_spec, float(pdf_ggx)

def mis_power_weight(pdf_a: float, pdf_b: float, n_a: int = 1, n_b: int = 1) -> float:
    """Veach 幂启发式 (beta = 2) 多重重要性采样权重"""
    wa2, wb2 = (n_a * pdf_a) ** 2, (n_b * pdf_b) ** 2
    return wa2 / max(wa2 + wb2, 1e-30)
```

== 参与介质体渲染方程与现代实时路径追踪降噪 <sec:ch10-frontier>

当光线穿过云雾、烟火、浑浊液体或玉石等参与介质（Participating Media）时，真空无衰减假设失效，渲染方程推广为体渲染所遵循的辐射传输方程（Radiative Transfer Equation, RTE），并与后续第 12 章神经辐射场（NeRF）的体绘制公式一脉相承：

1. *参与介质与辐射传输方程（RTE）*：【已有成果】设介质在点 $bold(x)$ 处的吸收系数为 $sigma_a (bold(x))$，散射系数为 $sigma_s (bold(x))$，消光系数为 $sigma_t (bold(x)) = sigma_a (bold(x)) + sigma_s (bold(x))$。光线沿方向 $omega$ 传播微元距离 $dif t$ 的辐射亮度方向导数满足微分—积分形式 RTE @pharr2023pbrt：
   $ (omega dot nabla) L(bold(x), omega) = -sigma_t (bold(x)) L(bold(x), omega) + sigma_a (bold(x)) L_e (bold(x), omega) + sigma_s (bold(x)) integral_(SS^2) p_"phase" (bold(x), omega', omega) L(bold(x), omega') dif omega', $ <eq:ch10-rte>
   其中相函数（Phase Function）$p_"phase" (omega', omega)$ 满足球面归一化 $integral_(SS^2) p_"phase" dif omega' = 1$，最常用的各向异性参数化为 Henyey-Greenstein 相函数 $p_"HG" (cos theta) = (1 - g^2) \/ (4 pi (1 + g^2 - 2 g cos theta)^(3/2))$（$g in (-1, 1)$ 控制前向或后向散射）。对于空间非均匀介质（如 VDB 云团），现代体积路径追踪通过引入虚拟空碰撞粒子（Null-Collision / Woodcock Delta Tracking）将非均匀消光系数填充为均匀上界 $bar(sigma)_t$，从而无需数值求积分即可实现无偏自由程采样。
2. *时空重采样（ReSTIR）与实时路径追踪降噪*：【已有成果】在实时全景路径追踪（如《赛博朋克 2077》Overdrive 模式与 Unreal Engine 5 Lumen）中，面对数百万个动态发光三角形，每像素仅 1 SPP 的预算令传统 NEE 彻底崩溃。以时空蓄水池重要性采样（ReSTIR DI / ReSTIR GI）为代表的采样架构通过流式加权蓄水池采样（Weighted Reservoir Sampling）在相邻像素与历史帧之间复用高质量路径样本，使 1 SPP 达到传统数千次光源采样的信噪比；随后配合时空方差引导滤波（SVGF）或神经辐射重构建降噪器（如 NVIDIA DLSS Ray Reconstruction），利用反照率、世界法线与运动矢量 G-Buffer 解调光照，将残余蒙特卡洛噪点实时重建为时空一致的清晰图像。

【本书推断】从经典微表面 BRDF、Veach 多重重要性采样到体渲染 RTE，基于物理的渲染（PBR）建立了一套严密的「正向辐射传输算子」；这不仅为离线与实时渲染提供了统一内核，更直接构成了模块六中可微渲染器、NeRF 密度体积积分以及 3D Gaussian Splatting 辐射外观建模的物理真值底座。

#keybox(title: [本章要点])[
1. *微表面镜面 BRDF*：Cook-Torrance 公式 $f_"spec" = (D F G_2) \/ (4 (bold(n) dot omega_i)(bold(n) dot omega_o))$ 的分母源自微法线向出射方向映射的镜面雅可比项 $dif omega_h \/ dif omega_o = 1 \/ (4(omega_o dot bold(h)))$；GGX 长尾分布与 Smith 高度相关遮蔽是现代实时与离线材质的核心。
2. *Disney/glTF 工作流与多散射补偿*：通过感知粗糙度平方映射 $alpha = r^2$ 与金属度 $m$ 统一电介质与导体，并由 Kulla-Conty 能量补偿项消除高粗糙度下的单散射暗化。
3. *蒙特卡洛积分与重要性采样*：重要性采样估计量 $hat(I)_N = (1 \/ N) sum f(X_i) \/ p(X_i)$ 具有与积分维数无关的 $O(N^(-1/2))$ 收敛率；采样密度 $p(x)$ 越贴近被积函数，方差越低。
4. *路径追踪与 MIS*：结合光源直接采样（NEE）、俄罗斯轮盘赌无偏终止与 Veach 幂启发式多重重要性采样（MIS），可在任意表面粗糙度与光源尺寸下实现全场景稳健收敛。
]
