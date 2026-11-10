#import "../template.typ": *

#heading(numbering: none)[附录 A　全书统一数学符号与坐标系约定]
#counter(figure.where(kind: table)).update(0)
#set figure(numbering: n => "A-" + str(n))

本附录汇总全书统一使用的核心数学记号与跨框架坐标系约定。全书默认采用*右手三维笛卡尔坐标系（Right-Handed Coordinate System）*与*列向量左乘（$bold(p)' = bold(M) bold(p)$）*约定；期望与概率算子记为 $EE$ 与 $PP$，实数空间记为 $RR^n$，二维单位球面记为 $SS^2$。

*A.1　空间几何、线性变换与相机投影记号（第 1–2、7–8 章）*

#figure(
  table(
    columns: (2.8cm, 1fr, 2.2cm),
    align: (left, left, center),
    [符号], [数学与物理含义], [首次出现],
    [$bold(p), bold(x) in RR^3$], [三维空间中的点（位置向量）；齐次坐标记为 $tilde(bold(p)) = (x, y, z, 1)^top in RR^4$], [第 1、2 章],
    [$bold(v), bold(d) in RR^3$], [三维方向或位移向量；齐次坐标记为 $tilde(bold(v)) = (v_x, v_y, v_z, 0)^top in RR^4$], [第 2 章],
    [$bold(n), bold(t), bold(b) in SS^2$], [表面单位外法线、切向量（Tangent）与副切向量（Bitangent），构成正交标架 $bold(T)bold(B)bold(N)$], [第 2、5 章],
    [$bold(M)_"model", bold(M)_"view", bold(M)_"proj"$], [模型矩阵、视图（相机）矩阵与投影矩阵，均属于 $RR^(4 times 4)$；法线变换矩阵为 $(bold(M)_"model"^(-1))^top$], [第 2 章],
    [$bold(q) = (w, bold(u))$], [单位四元数 $bold(q) in HH_1$，满足 $w^2 + norm(bold(u))^2 = 1$，用于无万向节死锁的三维旋转插值], [第 2、11 章],
    [$(alpha, beta, gamma)$], [三维空间真实重心坐标（满足 $alpha + beta + gamma = 1$）；屏幕空间重心坐标记为 $(alpha', beta', gamma')$], [第 4 章],
    [$f(bold(x)), "SDF"(bold(x))$], [隐式曲面水平集函数与有向距离场（满足程函方程 $norm(nabla f(bold(x))) = 1$）], [第 7 章],
    [$Delta_M, K, H$], [流形上的余切拉普拉斯—贝尔特拉米算子、高斯曲率 $K = kappa_1 kappa_2$ 与平均曲率 $H = (kappa_1 + kappa_2) / 2$], [第 7、8 章],
    [$bold(Q)_v in RR^(4 times 4)$], [网格简化中顶点 $v$ 关联的对称二次误差度量矩阵（Quadric Error Metric）], [第 8 章],
  ),
  caption: [几何表示、空间变换与网格处理核心符号表],
) <tab:app-geom-symbols>

*A.2　辐射度量学、材质反射与全局光照记号（第 3、6、9–10 章）*

#figure(
  table(
    columns: (2.8cm, 1fr, 2.2cm),
    align: (left, left, center),
    [符号], [数学与物理含义（含国际单位制 SI）], [首次出现],
    [$Phi, I, E, M$], [辐射通量（$"W"$）、辐射强度（$"W" dot "sr"^(-1)$）、辐照度（$"W" dot "m"^(-2)$）与辐射出射度], [第 3 章],
    [$L(bold(x), omega)$], [点 $bold(x)$ 沿方向 $omega$ 的辐射亮度（Radiance，单位 $"W" dot "m"^(-2) dot "sr"^(-1)$）；入射与出射分别记为 $L_i, L_o$], [第 3、9 章],
    [$omega_i, omega_o in SS^2$], [入射光方向与出射（视线）方向，*统一约定两者均背离表面指向外侧*，故 $cos theta_i = bold(n) dot omega_i$], [第 3、9 章],
    [$bold(h) in SS^2$], [微表面半程向量（Halfway Vector），定义为 $bold(h) = (omega_i + omega_o) / norm(omega_i + omega_o)$], [第 5、10 章],
    [$f_r (bold(x), omega_i, omega_o)$], [双向反射分布函数（BRDF，单位 $"sr"^(-1)$），定义为 $d L_o (bold(x), omega_o) / (L_i (bold(x), omega_i) cos theta_i d omega_i)$], [第 9、10 章],
    [$D(bold(h)), G(omega_i, omega_o), F(omega_o, bold(h))$], [Cook-Torrance 微表面模型的法线分布函数（GGX）、Smith 几何遮蔽阴影函数与菲涅尔反射率], [第 10 章],
    [$V(bold(x) <-> bold(y)), G(bold(x) <-> bold(y))$], [两点间二值互见函数 $V in {0, 1}$ 与几何耦合核 $G(bold(x) <-> bold(y)) = (cos theta_x cos theta_y) / norm(bold(x) - bold(y))^2$], [第 9 章],
    [$Y_l^m (theta, phi)$], [$l$ 阶 $m$ 次实球谐正交基函数（Spherical Harmonics，$-l <= m <= l$）], [第 6、13 章],
  ),
  caption: [辐射度量学、微表面 BRDF 与光线传输符号表],
) <tab:app-radiometry-symbols>

*A.3　物理仿真、可微渲染与神经/高斯图形学记号（第 11–13 章）*

#figure(
  table(
    columns: (2.8cm, 1fr, 2.2cm),
    align: (left, left, center),
    [符号], [数学与物理含义], [首次出现],
    [$bold(M), bold(x)(t), bold(v)(t), bold(f)$], [动力学系统质量矩阵、广义位置向量、广义速度向量与内/外力合向量], [第 11 章],
    [$C(bold(x)), tilde(bold(alpha))$], [基于位置的动力学（PBD/XPBD）约束函数与时间步缩放柔度矩阵 $tilde(bold(alpha)) = bold(alpha) / Delta t^2$], [第 11 章],
    [$sigma(bold(x)), T(t), alpha_i$], [体渲染消光密度系数、沿光线累积透射率 $T(t) = exp(-integral sigma d s)$ 与离散区间不透明度], [第 12 章],
    [$gamma(p)$], [NeRF 多频傅里叶位置编码映射 $RR -> RR^(2 L)$], [第 12 章],
    [$bold(mu) in RR^3, bold(Sigma) in RR^(3 times 3)$], [3D 高斯图元均值中心与三维协方差矩阵，参数化分解为 $bold(Sigma) = bold(R) bold(S) bold(S)^top bold(R)^top$], [第 13 章],
    [$bold(J) in RR^(2 times 3), bold(Sigma)' in RR^(2 times 2)$], [透视投影在相机空间均值处的局部仿射雅可比矩阵与二维屏幕空间椭球协方差矩阵], [第 13 章],
  ),
  caption: [物理仿真、可微体渲染与 3D Gaussian Splatting 符号表],
) <tab:app-neural-symbols>

*A.4　主流图形学 API 与三维视觉框架坐标系对照*

在工程实践中，不同渲染引擎与三维重建工具链在相机坐标系朝向、NDC 深度范围与屏幕原点上的差异见 @tab:app-coord-conventions（数学转换细节见第 2 章）。

#figure(
  table(
    columns: (2.8cm, 2.0cm, 3.3cm, 2.4cm, 3.2cm),
    align: (left, center, left, center, left),
    [框架 / 标准], [世界手性], [相机局部坐标轴约定], [NDC 深度范围], [图像像素原点 $(0,0)$],
    [本书基准 / OpenGL], [右手系], [$+x$ 右，$+y$ 上，视线沿 $-z$], [$[-1, 1]$], [左下角（$+y$ 向上）],
    [Vulkan], [右手系], [$+x$ 右，$+y$ 下，视线沿 $+z$], [$[0, 1]$], [左上角（$+y$ 向下）],
    [DirectX / Metal / WebGPU], [左手/右手], [$+x$ 右，$+y$ 上，视线沿 $+z$ 或 $-z$], [$[0, 1]$], [左上角（$+y$ 向下）],
    [COLMAP / OpenCV / 3DGS], [右手系], [$+x$ 右，$+y$ 下，视线沿 $+z$], [$[0, 1]$（或正深度 $t_z$）], [左上角（$+y$ 向下）],
    [PyTorch3D], [右手系], [$+x$ 左，$+y$ 上，视线沿 $+z$], [$[0, 1]$], [左上角或中心归一化],
  ),
  caption: [主流图形 API 与三维视觉框架的坐标系与 NDC 约定速查表],
) <tab:app-coord-conventions>

#heading(numbering: none)[附录 B　核心图形学算法与渲染管线速查表]
#counter(figure.where(kind: table)).update(0)
#set figure(numbering: n => "B-" + str(n))

本附录将全书 13 章涉及的核心计算算子按时间/空间复杂度、输入输出签名与工程适用场景整理为案头速查表（见 @tab:app-algo-cheatsheet）。

#figure(
  table(
    columns: (3.1cm, 2.2cm, 3.8cm, 4.6cm),
    align: (left, center, left, left),
    [算法 / 算子名称], [对应章节], [渐近复杂度（构建 / 查询）], [核心数学判据与工程要点],
    [半空间边函数光栅化], [第 4 章], [$O(1)$ 准备 / $O(B_x B_y)$ 像素], [利用增量线性边函数 $E_(i j)(x, y) >= 0$ 与顶左规则并行判定像素覆盖],
    [透视校正重心插值], [第 4 章], [$O(1)$ / 每片元], [在屏幕空间线性插值 $1 / z_"view"$ 与 $I / z_"view"$，再相除恢复真实三维属性],
    [Mipmap 与 EWA 过滤], [第 5 章], [$O(N_"tex")$ 预滤波（$+1/3$ 显存） / $O(1)$–$O(K)$], [按屏幕偏导雅可比近似像素纹理足迹，消除高频缩小摩尔纹],
    [PCSS 百分比渐近软阴影], [第 6 章], [$O(N_"shadow")$ / 每像素 $O(K_b + K_f)$], [利用相似三角形 $w_"penumbra" = (d_r - d_b) w_"light" / d_b$ 动态调整 PCF 核半径],
    [球谐预计算辐射传输 PRT], [第 6 章], [离线 $O(N_v N_s)$ / 实时 $O(N_"SH")$], [将低频环境光与传输算子投影至 $l <= 2$（9 维）球谐正交基求内积],
    [SDF 球体追踪（Sphere Tracing）], [第 7 章], [$O(1)$ / 每光线 $O(K_"step")$], [利用 $|f(bold(p))|$ 给出的最大安全无交半径自适应推进光线步长],
    [QEM 二次误差网格简化], [第 8 章], [$O(E log E)$ 优先队列维护], [累加顶点关联平面二次型矩阵 $bold(Q) = sum bold(p) bold(p)^top$，求解最优坍缩点],
    [SAH-BVH 层次包围盒], [第 9 章], [$O(N log N)$ 分桶构建 / 平均 $O(log N)$], [最小化表面积启发式期望求交代价 $C_"trav" + sum (S_i / S_P) N_i C_"isect"$],
    [蒙特卡洛路径追踪 + MIS], [第 10 章], [方差按 $O(N^(-1/2))$ 收敛], [以平衡/幂启发式权重 $w_s = (n_s p_s^beta) / sum_k n_k p_k^beta$ 融合 BSDF 与光源采样],
    [XPBD 扩展基于位置动力学], [第 11 章], [每时间步 $O(K_"iter" dot M_"cons")$], [引入时间步柔度 $tilde(alpha) = alpha / Delta t^2$ 直接将预测位置投影至约束流形],
    [NeRF 分层可微体渲染], [第 12 章], [每像素 $O(N_c + N_f)$ 次 MLP 评估], [沿光线分段常数积分 $hat(C) = sum T_i (1 - exp(-sigma_i delta_i)) bold(c)_i$，处处可微],
    [3DGS 瓦片高斯光栅化], [第 13 章], [$O(M log M)$ 排序 / 每像素 $O(K_"splat")$], [利用局部仿射雅可比 $bold(J)$ 将 3D 协方差投影为 2D 椭圆并按 $16 times 16$ 瓦片混合],
  ),
  caption: [全书核心图形学算法复杂度与工程要点速查表],
) <tab:app-algo-cheatsheet>

#heading(numbering: none)[附录 C　迷你编程实验路线图与验收清单]
#counter(figure.where(kind: table)).update(0)
#set figure(numbering: n => "C-" + str(n))

为了帮助读者将书中的数学推导转化为扎实的代码能力，我们设计了四个递进式「迷你编程实验」（Mini-Labs）。每个实验均仅依赖 Python 标准科学计算栈（NumPy / PyTorch / Taichi @hu2019taichi），核心代码量控制在 150–300 行以内，汇总见 @tab:app-labs-roadmap。

#figure(
  table(
    columns: (1.8cm, 3.6cm, 2.2cm, 6.1cm),
    align: (center, left, center, left),
    [实验编号], [实验名称], [对应章节], [核心实现内容与数值验收标准],
    [Lab 1], [TinySoftRaster：CPU/NumPy 软光栅渲染器], [第 2、4、5 章], [实现 MVP + 视口变换、包围盒边函数遍历、Reversed-Z 深度缓冲、透视校正重心插值与切线空间法线贴图；验证旋转立方体棋盘格纹理不发生仿射扭曲],
    [Lab 2], [MiniMesh & SDF：几何处理与球体追踪器], [第 7、8 章], [实现 CSG 有向距离场球体追踪渲染器，并基于半边网格实现余切拉普拉斯算子组装与 QEM 边坍缩简化；验证闭合流形欧拉示性数守恒与曲率平滑收敛],
    [Lab 3], [MicroPathTracer：GGX 微表面与 MIS 路径追踪器], [第 3、9、10 章], [在 Cornell Box 场景中实现 Möller-Trumbore 求交、SAH-BVH 加速、GGX 重要性采样、Next-Event Estimation 与多重重要性采样（MIS）；验证不同粗糙度球体与不同面积光源下的低方差高光收敛],
    [Lab 4], [MiniGaussianSplat：可微 3D 高斯泼溅重建器], [第 12、13 章], [使用 PyTorch 实现四元数—缩放协方差矩阵构造、EWA 雅可比二维投影与前向/反向可微 $alpha$-混合，从多视角合成图像优化恢复三维高斯点云位置、形状与颜色],
  ),
  caption: [配套迷你编程实验路线图与验收判据],
) <tab:app-labs-roadmap>

*实验自检七条铁律（动手调参前必查）：*

+ *矩阵乘法与转置一致性*：确认你的线性代数库（NumPy/PyTorch）中向量是按列向量（右乘点坐标 `M @ p`）还是按行向量批量组织（`P @ M.T`），切勿混用。
+ *透视除法与符号检查*：在右手相机系（视线沿 $-z$）中，视空间顶点满足 $z_"view" < 0$，因此裁剪空间齐次分量 $w_"clip" = -z_"view" > 0$，切勿遗漏负号导致前后翻转。
+ *线性色彩空间铁律*：所有光照积分、纹理均值滤波（Mipmap）与 $alpha$-混合必须在*线性亮度空间*完成；仅在最终写入 8-bit 图像文件前执行一次 $C_"sRGB" = C_"linear"^(1/2.2)$ 伽马编码。
+ *方向向量归一化与背离表面约定*：在计算点积 $bold(n) dot omega_i$、半程向量 $bold(h)$ 与折射方向前，务必显式调用 `normalize()`，并确保 $omega_i, omega_o$ 均指向表面外侧。
+ *蒙特卡洛 PDF 测度匹配*：在路径追踪中混合光源面积采样与 BSDF 立体角采样时，所有概率密度函数必须先通过雅可比因子 $d omega_i / d A = cos theta_y / r^2$ 统一转换到*同一积分测度*（全立体角测度或全面积测度）下再代入 MIS 权重公式。
+ *物理仿真时间步与柔度解耦*：调试弹簧或布料仿真若出现爆炸，先将显式欧拉切换为半隐式（辛）欧拉或 XPBD，并检查约束梯度分母是否加上了数值防除零项 $epsilon = 10^{-8}$。
+ *可微渲染梯度有限差分校验*：在编写自定义前向/反向光栅化内核（如 3DGS 协方差投影雅可比 $bold(J)$）后，先在单高斯、单像素玩具算例上用中心有限差分 $(cal(L)(theta + epsilon) - cal(L)(theta - epsilon)) / (2 epsilon)$ 对齐解析梯度，确认相对误差小于 $10^{-5}$ 后再启动大规模优化。
