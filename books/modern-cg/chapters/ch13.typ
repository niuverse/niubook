#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 3D Gaussian Splatting 与现代神经图形学前沿

第 12 章的神经辐射场（NeRF）借助隐式 MLP 实现了惊艳的新视角合成，但其基于逐光线步进（Ray Marching）的体渲染架构存在根本算力瓶颈：渲染一张 1080p 图像需要对数百万条射线各自采样数十至上百个空间点并逐点评估神经网络，难以在消费级显卡上达到高分辨率实时帧率（$> 60$ FPS）。2023 年，Kerbl 等人提出的 *3D Gaussian Splatting（3DGS）*@kerbl20233dgs 掀起了一场「从隐式场回归显式图元」的范式革命：它将场景显式表示为数百万个携带各向异性协方差与球谐外观系数的三维高斯椭球，并将经典的椭圆加权平均（EWA）抛雪球投影算法@zwicker2001ewa 与硬件友好的瓦片可微光栅器相结合，在保持照片级画质的同时实现了超 100 FPS 的实时渲染。本章首先推导 3D 高斯椭球的半正定协方差分解与局部仿射透视投影雅可比矩阵（@sec:ch13-gaussian-math）；随后剖析基于瓦片基数排序的可微光栅化与自适应克隆/分裂/剪枝控制（@sec:ch13-tile-raster）；接着介绍 Mip-Splatting 抗锯齿、2DGS 表面重建与逆向材质分解（@sec:ch13-2dgs-relight）；进而扩展至扩散蒸馏（SDS）生成式 3D、前馈式高斯重建与 4D 动态高斯场（@sec:ch13-generative-3d）；最后对全书十三章的理论体系做大一统总结并展望未来十年开放问题（@sec:ch13-outlook）。

== 从隐式场回归显式图元：3D 高斯椭球的协方差分解与 EWA 透视投影 <sec:ch13-gaussian-math>

3DGS 放弃了连续隐式神经场，转而用一组离散但空间连续可微的显式三维椭球基元集合 $cal(G) = {(bold(mu)_k, bold(Sigma)_k, alpha_k, bold(c)_k)}_(k=1)^K$ 表征场景。每个三维高斯基元由以下四组可优化参数定义：空间中心均值 $bold(mu) in RR^3$、三维对称正定协方差矩阵 $bold(Sigma) in RR^(3 times 3)$、基础不透明度标量 $alpha in (0, 1)$（经 Sigmoid 激活约束），以及编码视角相关颜色的 3 阶球谐函数（Spherical Harmonics, SH，见第 6 章）系数向量 $bold(c) in RR^(48)$。

=== 三维高斯分布与保半正定旋转—缩放参数化

第 $k$ 个三维高斯基元在世界空间点 $bold(x) in RR^3$ 处的未归一化高斯核函数定义为：

$ G(bold(x)) = exp(-1/2 (bold(x) - bold(mu))^top bold(Sigma)^(-1) (bold(x) - bold(mu))). $ <eq:ch13-3d-gauss>

在梯度下降优化中，若直接将对称矩阵 $bold(Sigma)$ 的 6 个独立元素作为自由参数更新，极易违反协方差矩阵必须具备的*半正定性（Positive Semi-Definiteness, PSD）*，导致出现负特征值与非物理发散。3DGS 巧妙地利用几何特征分解，将三维高斯椭球视为对单位球体依次施加各向异性缩放与三维刚体旋转的结果：

$ bold(Sigma) = bold(R) bold(S) bold(S)^top bold(R)^top, $ <eq:ch13-cov-decomp>

其中 $bold(S) = "diag"(s_x, s_y, s_z) in RR^(3 times 3)$ 为缩放对角矩阵（由对数尺度参数经指数映射得到以保证正值），$bold(R) in "SO"(3)$ 为由单位四元数 $bold(q) = (q_w, q_x, q_y, q_z)^top$（见第 2 章）导出的正交旋转矩阵。对任意非零向量 $bold(v) in RR^3$，二次型 $bold(v)^top bold(Sigma) bold(v) = norm(bold(S)^top bold(R)^top bold(v))_2^2 >= 0$ 恒成立，从而在无约束梯度更新下*严格保证协方差矩阵半正定*。

=== EWA 抛雪球局部仿射近似与透视投影雅可比推导

为将世界空间的三维高斯 $G(bold(x))$ 高效光栅化至二维图像平面，必须求取其沿相机视线积分后的二维投影分布。设世界到相机的刚体视图变换旋转矩阵为 $bold(W) in "SO"(3)$，相机空间坐标记为 $bold(t) = (t_x, t_y, t_z)^top = bold(W) bold(mu) + bold(t)_("cam")$。在相机坐标系下，高斯的局部三维协方差为 $bold(Sigma)_("cam") = bold(W) bold(Sigma) bold(W)^top$。

然而，第 2 章所述的针孔相机透视投影映射 $bold(u) = phi(bold(t)) = (f_x t_x / t_z + c_x, f_y t_y / t_z + c_y)^top$ 关于深度 $t_z$ 是*非线性的*，而高斯分布在非线性变换下不再严格闭合为高斯分布。Zwicker 等人在 *EWA Splatting*@zwicker2001ewa 中提出：在每个三维高斯中心 $bold(t)_k$ 附近对非线性透视映射 $phi(bold(t))$ 做一阶泰勒局部仿射展开 $phi(bold(t)) approx phi(bold(t)_k) + bold(J)_k (bold(t) - bold(t)_k)$，即可将三维椭球沿光线的投影解析闭式近似为二维屏幕高斯分布。

#proposition(title: [三维高斯透视投影的局部仿射雅可比与二维协方差公式])[
设针孔相机的水平与垂直焦距分别为 $f_x, f_y$，高斯中心在相机坐标系下的坐标为 $bold(t) = (t_x, t_y, t_z)^top$（按 COLMAP/3DGS 约定 $+z$ 指向相机前方，故 $t_z > 0$）。透视投影映射在 $bold(t)$ 处的 $2 times 3$ 雅可比矩阵为：

$ bold(J) = (partial bold(u))/(partial bold(t)) = mat(f_x / t_z, 0, -(f_x t_x) / t_z^2; 0, f_y / t_z, -(f_y t_y) / t_z^2), $ <eq:ch13-jacobian>

且三维高斯沿视线积分并投影到二维像素平面后的屏幕空间 $2 times 2$ 协方差矩阵 $bold(Sigma)'$ 由如下三明治矩阵乘积给出 @zwicker2001ewa @kerbl20233dgs：

$ bold(Sigma)' = bold(J) bold(W) bold(Sigma) bold(W)^top bold(J)^top + epsilon bold(I)_2, $ <eq:ch13-ewa>

其中正则化项 $epsilon bold(I)_2$（通常取 $epsilon = 0.3$ 像素平方）对应半像素宽度的二维低通抗锯齿高斯滤波核，确保投影椭圆至少覆盖一个像素并防止矩阵奇异。
]

#proof[
对屏幕像素坐标分量 $u_x (t_x, t_y, t_z) = f_x t_x / t_z + c_x$ 与 $u_y (t_x, t_y, t_z) = f_y t_y / t_z + c_y$ 分别关于 $(t_x, t_y, t_z)$ 求偏导：
$ (partial u_x)/(partial t_x) = f_x / t_z, quad (partial u_x)/(partial t_y) = 0, quad (partial u_x)/(partial t_z) = -(f_x t_x) / t_z^2, $
同理可得 $u_y$ 的偏导数行，组合即得 @eq:ch13-jacobian。根据多元正态分布的线性变换性质，若随机向量 $bold(X) tilde.op cal(N)(bold(mu), bold(Sigma))$，则仿射变换 $bold(Y) = bold(A) bold(X) + bold(b)$ 服从 $cal(N)(bold(A) bold(mu) + bold(b), bold(A) bold(Sigma) bold(A)^top)$。将复合线性算子 $bold(A) = bold(J) bold(W) in RR^(2 times 3)$ 作用于世界空间协方差 $bold(Sigma)$，并在屏幕空间与方差为 $epsilon bold(I)_2$ 的各向同性高斯滤波器卷积（多元高斯卷积等价于协方差矩阵直接相加），即证得 @eq:ch13-ewa。
]

求出二维协方差矩阵 $bold(Sigma)' in RR^(2 times 2)$ 后，将其逆矩阵（在着色器中称为*二次曲线矩阵 Conic* $bold(Omega) = (bold(Sigma)')^(-1)$）代入二维高斯公式，即可直接评估该高斯在任意像素坐标 $bold(p) in RR^2$ 处的衰减不透明度贡献：

$ alpha_k (bold(p)) = alpha_k exp(-1/2 (bold(p) - bold(mu)'_k)^top (bold(Sigma)'_k)^(-1) (bold(p) - bold(mu)'_k)). $ <eq:ch13-2d-eval>

@fig:ch13-ewa-splatting 图解了从三维各向异性高斯椭球经局部仿射切平面近似到二维图像平面椭圆的 EWA 投影几何过程。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 1. 世界空间 3D 高斯椭球
    rect((0.2, 0.4), (4.5, 4.9), fill: softbg, stroke: 0.8pt + softline, radius: 0.12)
    content((2.35, 4.5), text(size: 8pt, weight: "bold")[1. 世界空间 3D 高斯椭球])
    circle((2.35, 2.7), radius: (1.45, 0.78), fill: bluebg, stroke: 1.1pt + accent)
    circle((2.35, 2.7), radius: (1.45, 0.28), stroke: (paint: accent, thickness: 0.7pt, dash: "dashed"))
    line((2.35, 2.7), (3.8, 2.7), mark: (end: ">"), stroke: 0.9pt + accent2)
    line((2.35, 2.7), (2.35, 3.48), mark: (end: ">"), stroke: 0.9pt + accent2)
    circle((2.35, 2.7), radius: 0.07, fill: ink, stroke: none)
    content((2.1, 2.4), text(size: 7pt)[$bold(mu)$])
    content((2.35, 1.35), text(size: 7.5pt)[$bold(Sigma) = bold(R) bold(S) bold(S)^top bold(R)^top$])
    content((2.35, 0.8), text(size: 7pt)[四元数旋转 $bold(q)$ + 对数尺度 $bold(s)$])

    // 箭头 1 -> 2
    line((4.55, 2.65), (5.15, 2.65), mark: (end: ">"), stroke: 0.9pt + accent)
    content((4.85, 3.05), text(size: 7pt)[视图 $bold(W)$])

    // 2. 相机空间与射线切平面局部仿射近似
    rect((5.2, 0.4), (9.8, 4.9), fill: softbg, stroke: 0.8pt + accent2, radius: 0.12)
    content((7.5, 4.5), text(size: 8pt, weight: "bold", fill: accent2.darken(15%))[2. 局部仿射透视近似 $bold(J)$])
    // 相机原点与视锥射线
    circle((5.7, 1.5), radius: 0.08, fill: ink, stroke: none)
    content((5.85, 1.15), text(size: 7pt)[光心 $bold(o)$])
    line((5.7, 1.5), (9.4, 3.9), stroke: (paint: gray, thickness: 0.7pt, dash: "dashed"))
    line((5.7, 1.5), (9.5, 2.1), stroke: (paint: gray, thickness: 0.7pt, dash: "dashed"))
    // 相机空间高斯与局部切平面
    circle((8.1, 2.75), radius: (0.95, 0.52), fill: bluebg, stroke: 1.0pt + accent)
    line((7.55, 3.75), (8.65, 1.75), stroke: 1.1pt + warn)
    content((7.5, 1.35), text(size: 7.5pt)[在 $bold(t) = bold(W) bold(mu)$ 处一阶泰勒展开])
    content((7.5, 0.8), text(size: 7pt)[雅可比矩阵 $bold(J) = partial bold(u) / partial bold(t) in RR^(2 times 3)$])

    // 箭头 2 -> 3
    line((9.85, 2.65), (10.45, 2.65), mark: (end: ">"), stroke: 0.9pt + accent)
    content((10.15, 3.05), text(size: 7pt)[投影 $bold(J)$])

    // 3. 2D 屏幕像素网格与投影椭圆
    rect((10.5, 0.4), (14.4, 4.9), fill: bluebg, stroke: 0.8pt + accent, radius: 0.12)
    content((12.45, 4.5), text(size: 8pt, weight: "bold", fill: accent.darken(15%))[3. 2D 屏幕高斯 Splat])
    // 像素网格
    rect((11.1, 1.8), (13.8, 3.9), fill: white, stroke: 0.7pt + ink)
    line((12.0, 1.8), (12.0, 3.9), stroke: 0.4pt + softline)
    line((12.9, 1.8), (12.9, 3.9), stroke: 0.4pt + softline)
    line((11.1, 2.5), (13.8, 2.5), stroke: 0.4pt + softline)
    line((11.1, 3.2), (13.8, 3.2), stroke: 0.4pt + softline)
    // 2D 椭圆
    circle((12.45, 2.85), radius: (0.95, 0.62), fill: redbg, stroke: 1.1pt + warn)
    circle((12.45, 2.85), radius: 0.06, fill: warn, stroke: none)
    content((12.45, 1.35), text(size: 7.5pt)[$bold(Sigma)' = bold(J) bold(W) bold(Sigma) bold(W)^top bold(J)^top + epsilon bold(I)_2$])
    content((12.45, 0.8), text(size: 7pt)[由逆矩阵 $bold(Omega) = (bold(Sigma)')^(-1)$ 评估 $alpha_k$])
  })),
  caption: [3D Gaussian Splatting 的 EWA 透视投影几何流水线。（左）由旋转四元数与缩放对角阵参数化的三维各向异性高斯椭球；（中）变换至相机空间并在中心点 $bold(t)$ 处通过局部雅可比 $bold(J)$ 做一阶仿射近似；（右）光栅化为屏幕像素平面上的二维高斯椭圆并评估逐像素不透明度。],
) <fig:ch13-ewa-splatting>

== 基于瓦片（Tile-based）的可微光栅器与自适应密度控制 <sec:ch13-tile-raster>

若对每个像素独立地对覆盖它的所有三维高斯做深度排序，计算开销将高不可攀。3DGS 设计了高度优化的 *CUDA 瓦片可微光栅器（Tile-based Differentiable Rasterizer）*@kerbl20233dgs，充分利用了现代 GPU 的片上共享显存（Shared Memory）与硬件级基数排序。

=== $16 times 16$ 瓦片划分、64 位键值基数排序与 $O(1)$ 显存反向传播

3DGS 的前向与反向光栅化遵循以下四步确定性管线（见 @fig:ch13-tile-pipeline）：
1. *视锥剔除与 $3 sigma$ 包围盒求交*：剔除位于视锥体外的三维高斯，对其余高斯计算 @eq:ch13-ewa 的二维协方差 $bold(Sigma)'$ 的最大特征值 $lambda_("max")$，以 $r = ceil(3 sqrt(lambda_("max")))$ 为屏幕半径确定覆盖范围。
2. *瓦片实例化与全局单次基数排序*：将屏幕划分为 $16 times 16$ 像素的独立瓦片（Tiles）。若一个高斯椭圆与 $M$ 个瓦片相交，则生成 $M$ 个实例，每个实例组装一个 *64 位无符号整数排序键*：高 32 位存放瓦片索引 `tile_id`，低 32 位存放相机空间深度 `depth` 的 IEEE 754 浮点位表示。调用单次 GPU 全局快速基数排序（Radix Sort），即可在毫秒内完成所有瓦片内高斯的从前向后（Front-to-Back）严格深度排序。
3. *共享显存协作加载与前向 Alpha 混合*：每个 $16 times 16$ 瓦片启动一个包含 256 个线程的 CUDA 线程块（Thread Block）。线程块协作将当前瓦片的高斯列表分批加载进高速 Shared Memory，每个线程负责一个像素 $bold(p)$，按深度顺序累加颜色与透射率：
   $ hat(bold(C))(bold(p)) = sum_(i in cal(N)(bold(p))) bold(c)_i alpha_i (bold(p)) T_i (bold(p)), quad T_i = product_(j=1)^(i-1) (1 - alpha_j (bold(p))). $ <eq:ch13-tile-blend>
   一旦某像素的累积透射率衰减至饱和阈值 $T_i < 10^(-4)$，该线程即提前终止循环。
4. *$O(1)$ 显存开销的反向梯度恢复*：在反向传播阶段，若像常规自动微分那样存储每个像素对成百上千个高斯的中间透射率 $T_i$，显存将瞬间溢出。3DGS 仅保存每个像素最终的饱和透射率 $T_("final")$，在反向遍历瓦片高斯列表时，通过简单除法递推*动态精确还原每一步的中间透射率*：
   $ T_i = (T_(i+1)) / (1 - alpha_i), $ <eq:ch13-back-t>
   从而以常数级 $O(1)$ 额外显存完成对所有高斯位置、协方差、球谐系数与不透明度的精确梯度反传。

=== 自适应密度控制（克隆、分裂与剪枝）

3DGS 通常以运动恢复结构（SfM / COLMAP）输出的稀疏点云初始化高斯集合，并在优化损失函数 $cal(L) = (1 - lambda) cal(L)_1 + lambda cal(L)_("D-SSIM")$（其中 $lambda = 0.2$）的过程中，每隔 100 次迭代根据视图空间位置梯度的平均模长 $norm(nabla_(bold(mu)'_k) cal(L))_2 > tau_("pos")$（阈值 $tau_("pos") = 0.0002$）执行*自适应拓扑密度控制（Adaptive Density Control）*：
- *欠重建克隆（Cloning for Under-Reconstruction）*：当某局部区域缺失几何特征且对应的三维高斯尺寸较小时（$max(s_x, s_y, s_z) <= tau_s$），复制一份相同大小的高斯并沿位置梯度方向移动以填补空洞。
- *过重建分裂（Splitting for Over-Reconstruction）*：当一个尺寸巨大的高斯球粗略覆盖了高频细节区域时（$max(s_x, s_y, s_z) > tau_s$），将其替换为两个缩放尺度除以 $1.6$ 的子高斯，并以原三维高斯作为概率密度函数采样新中心。
- *透明与病态剪枝（Pruning）*：定期剔除不透明度低于阈值（$alpha_k < epsilon_alpha = 0.005$）的幽灵高斯以及在世界空间异常庞大的漂浮伪影（Floaters）。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let bstyle = (radius: 0.12, fill: softbg, stroke: 0.9pt + accent)
    // 1. 投影与 64-bit 排序
    rect((0.2, 2.3), (4.2, 4.5), ..bstyle)
    content((2.2, 4.05), text(size: 8pt, weight: "bold")[1. 瓦片投影与基数排序])
    content((2.2, 3.4), text(size: 7.5pt)[计算 2D 协方差 $bold(Sigma)'$ 与 $3 sigma$ 半径])
    content((2.2, 2.75), text(size: 7.2pt)[64 位键 `[tile_id | depth]` 排序])

    // 2. 16x16 Shared Memory 光栅化
    rect((4.9, 2.3), (9.3, 4.5), fill: bluebg, stroke: 0.9pt + accent2, radius: 0.12)
    content((7.1, 4.05), text(size: 8pt, weight: "bold", fill: accent2.darken(15%))[2. $16 times 16$ 瓦片前向与反向光栅化])
    content((7.1, 3.4), text(size: 7.5pt)[Shared Memory 顺序 $alpha$ 混合])
    content((7.1, 2.75), text(size: 7.5pt)[反向递推 $T_i = T_(i+1) / (1 - alpha_i)$])

    // 3. 光度损失
    rect((10.0, 2.3), (14.3, 4.5), ..bstyle)
    content((12.15, 4.05), text(size: 8pt, weight: "bold")[3. 混合光度损失评估])
    content((12.15, 3.4), text(size: 7.5pt)[$(1 - lambda) cal(L)_1 + lambda cal(L)_("D-SSIM")$])
    content((12.15, 2.75), text(size: 7.5pt)[反传视图位置梯度 $nabla_(bold(mu)') cal(L)$])

    // 4. 底部自适应密度控制盒
    rect((1.8, 0.2), (12.5, 1.5), fill: redbg, stroke: 0.9pt + warn, radius: 0.12)
    content((7.15, 1.15), text(size: 8pt, weight: "bold", fill: warn)[4. 自适应高斯密度控制（当 $norm(nabla_(bold(mu)') cal(L))_2 > tau_("pos")$ 时触发）])
    content((7.15, 0.55), text(size: 7.5pt)[小高斯欠重建 $->$ *克隆（Clone）* · 大高斯过重建 $->$ *分裂（Split $div 1.6$）* · $alpha < epsilon_alpha ->$ *剪枝（Prune）*])

    // 连接箭头
    line((4.25, 3.4), (4.85, 3.4), mark: (end: ">"), stroke: 0.9pt + accent)
    line((9.35, 3.4), (9.95, 3.4), mark: (end: ">"), stroke: 0.9pt + accent)
    line((12.15, 2.25), (12.15, 1.55), mark: (end: ">"), stroke: (paint: warn, thickness: 0.9pt, dash: "dashed"))
    line((1.8, 0.85), (0.9, 0.85), (0.9, 2.25), mark: (end: ">"), stroke: (paint: warn, thickness: 0.9pt, dash: "dashed"))
  })),
  caption: [3DGS 基于瓦片（Tile-based）的可微光栅化与自适应拓扑演化闭环。前向管线通过 64 位键值基数排序与片上共享显存实现超百帧合成；反向管线以 $O(1)$ 显存恢复透射率并由位置梯度驱动高斯集合的克隆、分裂与剪枝。],
) <fig:ch13-tile-pipeline>

=== 算法实现：基于 PyTorch 的 3D 高斯协方差构造与 EWA 2D 投影算子

以下 PyTorch 代码实现了从四元数与尺度向量构建三维协方差矩阵 @eq:ch13-cov-decomp，并经局部透视雅可比 @eq:ch13-jacobian 投影为二维屏幕二次曲线（Conic）的完整可微过程：

```python
import torch

def project_3d_gaussians_to_2d(means3d, quats, scales, R_cw, t_cw, fx, fy):
    """将 3D 高斯 (N, 3) 投影至 2D 屏幕空间, 返回 2D 均值与逆协方差矩阵 conic"""
    # 1. 单位化四元数 (w, x, y, z) 并构造正交旋转矩阵 R (N, 3, 3)
    q = quats / (torch.norm(quats, dim=-1, keepdim=True) + 1e-8)
    w, x, y, z = q[:, 0], q[:, 1], q[:, 2], q[:, 3]
    R = torch.stack([
        1 - 2*(y*y + z*z), 2*(x*y - w*z),     2*(x*z + w*y),
        2*(x*y + w*z),     1 - 2*(x*x + z*z), 2*(y*z - w*x),
        2*(x*z - w*y),     2*(y*z + w*x),     1 - 2*(x*x + y*y)
    ], dim=-1).reshape(-1, 3, 3)
    # 2. 构造对称半正定 3D 协方差 Sigma = R S S^T R^T
    RS = R * scales.unsqueeze(1)                           # 等价于 R @ diag(s)
    Sigma3d = RS @ RS.transpose(-1, -2)

    # 3. 变换至相机空间并计算 EWA 透视投影雅可比矩阵 J (N, 2, 3)
    t = (means3d @ R_cw.T) + t_cw                          # 相机坐标 (tx, ty, tz)
    tx, ty, tz = t[:, 0], t[:, 1], t[:, 2].clamp(min=0.2)
    zeros = torch.zeros_like(tz)
    J = torch.stack([
        fx / tz, zeros,   -fx * tx / (tz * tz),
        zeros,   fy / tz, -fy * ty / (tz * tz)
    ], dim=-1).reshape(-1, 2, 3)

    # 4. 计算 2D 协方差 Sigma' = J W Sigma W^T J^T + 0.3 * I_2 及其逆矩阵
    JW = J @ R_cw.unsqueeze(0)
    Sigma2d = JW @ Sigma3d @ JW.transpose(-1, -2)
    Sigma2d[:, 0, 0] += 0.3
    Sigma2d[:, 1, 1] += 0.3
    conic = torch.inverse(Sigma2d)                         # 2D 高斯二次型逆矩阵
    return torch.stack([fx * tx / tz, fy * ty / tz], dim=-1), conic
```

== 抗锯齿（Mip-Splatting）、2D 高斯表面重建（2DGS）与可重光照分解 <sec:ch13-2dgs-relight>

尽管原始 3DGS 在新视角合成上表现优异，但它在改变相机焦距或观察距离时会出现膨胀或高频闪烁伪影，且三维体积椭球缺乏精确定义的表面法线与材质属性。2024 年的代表性工作从以下三个维度完善了高斯表征：

=== 双重频率约束与无锯齿缩放（Mip-Splatting）

原始 3DGS 在 @eq:ch13-ewa 中固定加上屏幕空间膨胀项 $epsilon bold(I)_2$：当相机拉远（或降低渲染分辨率）时，训练好的细小高斯在屏幕上被过度放大导致模糊；当相机拉近（Zoom-in）时，原本依赖膨胀项填满像素的高斯突然收缩为细刺状伪影。Yu 等人提出的 *Mip-Splatting*@yu2024mipsplatting 从第 3 章奈奎斯特采样定理出发，引入双重滤波器：（1）在三维世界空间为每个高斯施加由训练相机最高采样频率决定的 *3D 平滑低通滤波器*，限制场景内在最高频率；（2）将屏幕空间固定膨胀替换为精确模拟像素盒滤波积分的 *2D Mip 滤波器*，同时对高斯的幅度系数做能量守恒缩放，实现了任意焦距与分辨率下的零伪影无锯齿渲染。

=== 2D 高斯面元（2DGS）与几何表面法线对齐

三维椭球体在沿不同视角射线积分时，其最大密度截面会随视角旋转，导致多视角深度不一致。Huang 等人提出的 *2D Gaussian Splatting（2DGS）*@huang20242dgs 将三维体积椭球直接压扁（将局部 $z$ 轴尺度设为 0），退化为嵌入三维空间的*二维椭圆面元（2D Oriented Planar Disks / Surfels）*。每个 2D 高斯面元由中心点 $bold(p)_k$、两个正交切向量 $bold(t)_u, bold(t)_v$ 及天然唯一的单位表面法线 $bold(n)_k = bold(t)_u times bold(t)_v$ 参数化。渲染时不再使用 EWA 仿射近似，而是通过两个正交平面的交线精确求解*光线—面元透视相交（Ray-Splat Intersection）*，并引入深度失真正则化与法线—深度梯度一致性损失，直接从高斯场中提取出媲美 NeuS 的高精度光滑三角网格。

=== 逆向物理材质分解（Inverse PBR Relighting）

原始 3DGS 使用球谐函数 $bold(c)$ 烘焙了静态环境光下的出射辐射亮度，无法在新光源下重新打光或投射动态阴影。现代可重光照高斯框架将第 10 章的 *Cook-Torrance 微表面 BRDF 参数*——漫反射反照率（Albedo $bold(rho)_d$）、金属度（Metallic $m$）、粗糙度（Roughness $r$）与表面法线 $bold(n)$——直接绑定到每个高斯图元上，结合可微环境光贴图（Split-Sum IBL）与光线追踪高斯阴影测试，实现了从多视角图像到可编辑 PBR 数字资产的端到端逆向拆解。

== 生成式 3D 与动态场景：扩散蒸馏（SDS）、前馈重建与 4D 高斯场 <sec:ch13-generative-3d>

当输入观测从数十张密集标定图像减少至单张图像甚至一句文本提示（Text-to-3D），或扩展至包含非刚性运动的动态视频时，神经图形学与生成式人工智能迎来了深度融合。

=== 分数蒸馏采样（Score Distillation Sampling, SDS）

在缺乏三维真值监督的情况下，Poole 等人在 *DreamFusion*@poole2023dreamfusion 中提出了里程碑式的*分数蒸馏采样（SDS）*定理，利用在大规模二维图像上预训练的文本条件扩散模型 $hat(epsilon)_phi (bold(x)_t; y, t)$ 作为先验指导三维场景参数 $theta$（NeRF 或 3DGS）的优化。设正向可微渲染图像为 $bold(x) = cal(R)(theta)$，向其注入时间步 $t$ 的高斯噪声 $epsilon tilde.op cal(N)(bold(0), bold(I))$ 得到加噪图像 $bold(x)_t = alpha_t bold(x) + sigma_t epsilon$。SDS 绕过了昂贵且不稳定的扩散模型 U-Net 雅可比矩阵求导，直接将预测噪声残差作为推动三维场景向高概率密度流形演化的梯度：

$ nabla_theta cal(L)_("SDS")(phi, bold(x) = cal(R)(theta)) = EE_(t, epsilon) [ w(t) (hat(epsilon)_phi (bold(x)_t; y, t) - epsilon) (partial bold(x))/(partial theta) ], $ <eq:ch13-sds>

其中 $w(t)$ 为时间步加权函数。由于 3DGS 的光栅化速度比 NeRF 快两个数量级，基于 3DGS 与 SDS（或多视角扩散先验）的生成管线已将 Text-to-3D 生成耗时从数小时压缩至分钟乃至秒级。

=== 泛化前馈式高斯预测（pixelSplat）与 4D 时空高斯场（4DGS）

- *前馈式毫秒级高斯重建（Feed-Forward 3DGS）*：为摆脱「每个场景单独迭代优化数千步」的开销，Charatan 等人提出的 *pixelSplat*@charatan2024pixelsplat 构建了基于对极几何注意力（Epipolar Transformer）的前馈式神经网络：直接输入两张稀疏视角图像，网络在单次前向推理（百毫秒级）中为每个像素预测深度概率分布与对应的 3D 高斯图元参数 $(bold(mu), bold(Sigma), alpha, bold(c))$，实现了无需逐场景优化的泛化三维重建【已有成果】。
- *动态场景与 4D 时空高斯场（4DGS）*：针对含运动物体的动态视频，Wu 等人提出的 *4D Gaussian Splatting（4DGS）*@wu20244dgs 将静态三维高斯中心与旋转缩放参数与多分辨率时空 HexPlane 特征网格及轻量级形变解码器耦合，学习连续的时空形变场 $(Delta bold(mu)(t), Delta bold(q)(t), Delta bold(s)(t))$，在保持拓扑连贯的同时实现了高分辨率自由视角视频（Free-Viewpoint Video）的实时渲染【已有成果】。

@tab:ch13-grand-synthesis 对全书涵盖的四大核心图形学渲染与重建范式做了系统性的横向对比。

#figure(
  table(
    columns: (2.5cm, 2.3cm, 2.3cm, 2.2cm, 2.2cm, 2.7cm),
    align: (left, left, left, center, center, left),
    [渲染与表征范式], [核心几何原语], [可见性与求交机制], [前向可微性], [场景构建耗时], [实时渲染帧率与优势],
    [传统光栅化 (Ch3–4)], [显式三角形网格], [Z-Buffer 硬件深度测试], [边界不连续 (需软光栅)], [人工建模 / 扫描], [$> 100$ FPS，硬件管线成熟],
    [蒙特卡洛路径追踪 (Ch9–10)], [三角形 / BVH 加速树], [射线—图元精确求交], [需剪影边显式采样], [人工建模 + PBR 材质], [离线或需 ReSTIR 降噪，全局光照最准],
    [神经辐射场 NeRF (Ch12)], [隐式 MLP / 哈希网格], [逐射线步进体积求积], [处处 $C^infinity$ 光滑可微], [数秒 (NGP) 至数小时], [$1–15$ FPS，擅长半透明与复杂拓扑],
    [3D/2D 高斯泼溅 @kerbl20233dgs], [显式 3D 椭球 / 2D 面元], [EWA 投影 + 瓦片基数排序], [解析可微 ($O(1)$ 反传)], [数分钟 (优化) / 毫秒 (前馈)], [$> 120$ FPS，兼顾照片级画质与显式编辑],
  ),
  caption: [全书四大图形学表征与渲染范式（光栅化、路径追踪、神经辐射场、3D Gaussian Splatting）综合对比],
) <tab:ch13-grand-synthesis>

== 全书总结与未来十年开放问题：正向物理精确性与逆向神经表征的大一统 <sec:ch13-outlook>

至此，我们完成了从经典正向渲染管线到现代可微与神经图形学的完整理论跋涉。回望全书十三章，可以清晰地看到计算机图形学底层的数学基石如何在半个世纪的演进中实现了跨越式的传承与统一：

- *第一定律：坐标变换与采样滤波的永恒回归*。第 2 章的齐次矩阵、四元数旋转 $"SO"(3)$ 与透视投影雅可比，直接成为第 11 章双四元数蒙皮（DQS）与第 13 章 3DGS 协方差分解 $bold(Sigma) = bold(R) bold(S) bold(S)^top bold(R)^top$ 的核心骨架；第 3 章的傅里叶频域混叠分析与奈奎斯特抗锯齿滤波，在二十年后化身为第 12 章 NeRF 的高频位置编码、Mip-NeRF 的圆锥台积分编码以及第 13 章 Mip-Splatting 的 3D/2D 双重低通滤波器；第 4 章的屏幕瓦片分块（Tile-based Rasterization）与提前深度终止（Early-Z），则在 3DGS 的 CUDA 瓦片光栅器中重获新生。
- *第二定律：曲面几何、辐射度量与光传输的深度融合*。第 6 章的球谐函数（SH）从经典环境光照压缩走向了 3DGS 的视角相关颜色表征；第 7–8 章的隐式符号距离场（SDF）与微分几何法线曲率，直接支撑了 NeuS 与 2DGS 的高精度几何表面重建；第 9–10 章的蒙特卡洛重要性采样与微表面 PBR 材质模型，则与第 12 章的分层体渲染求积及逆向重光照分解无缝汇合【已有成果】。

展望 2026–2035 年的下一个十年，现代计算机图形学正站在*「正向物理精确性」与「逆向神经表征」大一统*的历史交汇点上，以下三大开放问题值得深入探索：
1. *统一神经—物理混合图元（Unified Neuro-Physical Primitives）*：当前的 3DGS 擅长外观合成但难以直接参与精确光线追踪与有限元力学仿真，而三角网格擅长物理碰撞却难以从图像逆向生长。构建既能支持硬件 RT Core 级联多次弹射全局光照、又能直接作为 XPBD/MPM 物理仿真粒子承载应力张量的统一高斯基元，将是打通重建、渲染与交互仿真的关键突破【本书推断】。
2. *闭环具身世界模型（Embodied Sim-to-Real-to-Sim Loop）*：如第 11 章与本章所述，当机器人进入未知真实环境时，通过前馈式 3DGS 在毫秒内重建场景几何（Real-to-Sim），再结合可微物理引擎在虚拟空间推演交互轨迹与力反馈并反哺物理策略（Sim-to-Real），图形学渲染器与仿真器将正式演变为通用具身智能体的内在「空间想象引擎」【本书提出】。
3. *跨尺度万亿级神经资产的流式组织*：如同第 8 章的虚拟微多边形（Nanite）解决了百亿三角形的连续 LOD 渲染，如何在城市级乃至星球级尺度上建立三维高斯与神经场的分层多分辨率（Hierarchical Gaussian LOD）流式压缩标准，将成为下一代空间计算与开放世界引擎的核心基建【本书推断】。

#keybox(title: [本章要点])[
1. *3DGS 数学基石*：3DGS 通过 $bold(Sigma) = bold(R) bold(S) bold(S)^top bold(R)^top$ 参数化严格保证协方差矩阵半正定，并利用 EWA 透视投影局部仿射雅可比 $bold(J)$ 将三维椭球闭式投影为二维屏幕椭圆 $bold(Sigma)' = bold(J) bold(W) bold(Sigma) bold(W)^top bold(J)^top + epsilon bold(I)_2$。
2. *瓦片光栅化与自适应拓扑*：$16 times 16$ 瓦片划分结合 64 位键值全局基数排序与 $O(1)$ 显存反向透射率递推，赋予了 3DGS 超百帧实时渲染与高效端到端训练能力；基于位置梯度的克隆、分裂与剪枝实现了从稀疏点云到稠密场景的自适应生长。
3. *前沿演进与学科大一统*：Mip-Splatting 与 2DGS 分别攻克了多尺度抗锯齿与高精度表面重建难题，SDS 扩散蒸馏、pixelSplat 前馈预测与 4DGS 则开启了生成式与动态神经图形学时代；经典图形学的矩阵变换、采样滤波、光线传输与物理仿真在现代可微图形学中实现了深刻的大一统。
]
