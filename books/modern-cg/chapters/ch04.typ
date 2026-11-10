#import "../template.typ": *
#import "@preview/cetz:0.3.4"

= 三角形光栅化、透视校正插值与可见性

在第 2 章与第 3 章中，三维场景的几何顶点经过模型变换、视图变换与透视投影变换，并完成视锥体齐次裁剪与透视除法，最终映射到屏幕像素坐标系。接下来的核心问题是：如何将这些离散的几何图元连续地铺展到二维像素网格上，并在每个像素处正确计算其可见性与表面属性？这一将连续几何图元离散化为屏幕片元（Fragment）的过程称为*光栅化*（Rasterization）。

本章沿着现代实时渲染管线的几何后端展开：首先剖析为什么三角形是光栅化硬件的唯一原子图元，并推导基于半平面边函数与顶左规则的并行光栅化算法（@sec:ch04-edge）；其次从射影几何出发，严格证明为什么屏幕空间线性插值在透视投影下会失效，进而导出透视校正重心插值公式（@sec:ch04-barycentric）；随后讨论画家算法、Z-Buffer 深度缓冲与 Early-Z 硬件加速机制，给出可运行的 Python 软光栅实现（@sec:ch04-zbuffer）；接着分析光栅化走样的频域成因，对比 SSAA、MSAA 与时间抗锯齿（TAA / DLSS）的工程折衷（@sec:ch04-aa）；最后在前沿视野中剖析微多边形虚拟几何系统 Nanite 与计算着色器软光栅的架构演进（@sec:ch04-frontier）。

== 为什么是三角形：屏幕空间包围盒、边函数与顶左规则 <sec:ch04-edge>

早期的图形工作站曾支持直接光栅化任意多边形或四边形（Quad），但现代 GPU 硬件光栅化器无一例外地将*三角形*作为唯一的基础面片图元。这一设计并非偶然，而是由三条不可替代的几何性质决定的：
1. *必然共面性*：三维空间中任意三个不共线的顶点 $bold(p)_0, bold(p)_1, bold(p)_2 in RR^3$ 唯一确定一个平面；相比之下，四边形的四个顶点在骨骼蒙皮或顶点形变后极易脱离同一平面，导致面片内部折痕二义性。
2. *严格凸性与投影保凸性*：任何非退化三角形都是严格凸集，且在任意非奇异仿射变换与视锥裁剪后的透视投影下，其二维屏幕投影依然保持为严格凸三角形，不会退化为凹多边形或自交多边形。
3. *重心插值的唯一性*：任意多边形均可三角化（Triangulation），而在三角形上，三个顶点的任意标量或向量属性唯一确定一个线性插值场，不存在双线性四边形插值时的旋转不对称性。

=== 半平面边函数（Edge Function）与并行包含测试

1988 年，Juan Pineda 提出了基于线性边函数（Edge Function）的并行光栅化算法@pineda1988parallel，奠定了现代 GPU 光栅化器的数学基础。别于早期按扫描线（Scanline）逐行推进的串行算法，Pineda 算法将「点是否在三角形内」转化为三个独立的半平面符号测试。

#definition(title: [有向边函数与半平面测试])[
  设二维屏幕空间中按逆时针（Counter-Clockwise, CCW）顺序排列的三角形顶点为 $bold(p)_0 = (x_0, y_0)^top$、$bold(p)_1 = (x_1, y_1)^top$、$bold(p)_2 = (x_2, y_2)^top$。从顶点 $bold(p)_i$ 指向 $bold(p)_j$ 的有向边函数 $E_(i j) : RR^2 -> RR$ 定义为二维向量 $(bold(p) - bold(p)_i)$ 与 $(bold(p)_j - bold(p)_i)$ 的行列式（即二维叉积的标量值）：
  $ E_(i j)(x, y) = det mat(x - x_i, x_j - x_i; y - y_i, y_j - y_i) = (x - x_i)(y_j - y_i) - (y - y_i)(x_j - x_i) = A_(i j) x + B_(i j) y + C_(i j), $ <eq:ch04-edge-func>
  其中一次项系数为 $A_(i j) = y_j - y_i$、$B_(i j) = x_i - x_j$，常数项为 $C_(i j) = x_j y_i - y_j x_i$。当点 $(x, y)$ 位于有向边 $bold(p)_i -> bold(p)_j$ 的内侧半平面时 $E_(i j)(x, y) > 0$；位于边上时 $E_(i j)(x, y) = 0$；位于外侧半平面时 $E_(i j)(x, y) < 0$。
]

根据上述定义，一个屏幕采样点 $bold(p) = (x, y)^top$ 落在逆时针三角形 $triangle bold(p)_0 bold(p)_1 bold(p)_2$ 内部（含边界）当且仅当三个有向边函数同时非负：
$ E_(01)(x, y) >= 0 quad "且" quad E_(12)(x, y) >= 0 quad "且" quad E_(20)(x, y) >= 0. $ <eq:ch04-inside-test>
此外，因为 @eq:ch04-edge-func 是关于 $(x, y)$ 的仿射线性函数，当采样点在像素网格上沿水平或垂直方向步进 1 个像素时，边函数值只需一次加法即可增量更新：
$ E_(i j)(x + 1, y) = E_(i j)(x, y) + A_(i j), quad E_(i j)(x, y + 1) = E_(i j)(x, y) + B_(i j). $ <eq:ch04-edge-step>
在实际光栅化中，硬件首先计算三角形的屏幕空间轴对齐包围盒（Bounding Box）：
$ x_"min" = floor(min(x_0, x_1, x_2)), quad x_"max" = ceil(max(x_0, x_1, x_2)), $
并与视口边界做交集裁剪，随后对包围盒内的像素块（Tile）及 $2 times 2$ 像素四元组（Quad）并行评估 @eq:ch04-inside-test @pineda1988parallel @akenine2018realtime。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 左侧：包围盒与有向边函数
    rect((0.3, 0.4), (6.3, 5.2), fill: softbg, stroke: 0.8pt + softline, radius: 0.08)
    content((3.3, 4.9), text(size: 8pt, weight: "bold")[屏幕空间包围盒与半平面边函数])
    // 像素网格
    for ix in range(1, 6) {
      let gx = 0.5 + ix * 0.9
      line((gx, 0.7), (gx, 4.5), stroke: 0.4pt + gray.lighten(30%))
    }
    for iy in range(1, 5) {
      let gy = 0.6 + iy * 0.9
      line((0.8, gy), (5.6, gy), stroke: 0.4pt + gray.lighten(30%))
    }
    // 三角形顶点
    let p0 = (1.3, 1.1)
    let p1 = (5.3, 1.6)
    let p2 = (2.8, 4.2)
    line(p0, p1, p2, close: true, fill: bluebg, stroke: 1.2pt + accent)
    // 边方向与法向示意
    line(p0, p1, mark: (end: ">"), stroke: 1.2pt + accent)
    line(p1, p2, mark: (end: ">"), stroke: 1.2pt + accent)
    line(p2, p0, mark: (end: ">"), stroke: 1.2pt + accent)
    content((1.05, 0.88), text(size: 7.5pt, weight: "bold")[$bold(p)_0$])
    content((5.58, 1.55), text(size: 7.5pt, weight: "bold")[$bold(p)_1$])
    content((2.8, 4.45), text(size: 7.5pt, weight: "bold")[$bold(p)_2$])
    content((3.5, 1.12), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt, fill: accent)[$E_(01) >= 0$])
    content((4.45, 3.05), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt, fill: accent)[$E_(12) >= 0$])
    content((1.65, 2.85), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt, fill: accent)[$E_(20) >= 0$])
    // 像素中心采样点
    for ix in range(0, 5) {
      for iy in range(0, 4) {
        let cx = 1.05 + ix * 0.9
        let cy = 1.05 + iy * 0.9
        let e01 = (cx - 1.3)*(1.6 - 1.1) - (cy - 1.1)*(5.3 - 1.3)
        let e12 = (cx - 5.3)*(4.2 - 1.6) - (cy - 1.6)*(2.8 - 5.3)
        let e20 = (cx - 2.8)*(1.1 - 4.2) - (cy - 4.2)*(1.3 - 2.8)
        if e01 <= 0 and e12 <= 0 and e20 <= 0 {
          circle((cx, cy), radius: 0.09, fill: accent2, stroke: none)
        } else {
          circle((cx, cy), radius: 0.06, fill: white, stroke: 0.6pt + gray)
        }
      }
    }

    // 中间连接箭头
    line((6.45, 2.8), (7.45, 2.8), mark: (end: ">"), stroke: 1pt + accent2)
    content((6.95, 3.2), text(size: 7.5pt, fill: accent2)[Quad 派发])

    // 右侧：2x2 Quad 与顶左规则
    rect((7.6, 0.4), (13.8, 5.2), fill: softbg, stroke: 0.8pt + softline, radius: 0.08)
    content((10.7, 4.9), text(size: 8pt, weight: "bold")[$2 times 2$ 像素四元组（Quad）与差分计算])
    rect((8.3, 1.4), (10.3, 3.4), fill: bluebg, stroke: 1pt + accent)
    line((9.3, 1.4), (9.3, 3.4), stroke: 0.7pt + accent)
    line((8.3, 2.4), (10.3, 2.4), stroke: 0.7pt + accent)
    circle((8.8, 2.9), radius: 0.09, fill: accent2, stroke: none)
    circle((9.8, 2.9), radius: 0.09, fill: accent2, stroke: none)
    circle((8.8, 1.9), radius: 0.09, fill: accent2, stroke: none)
    circle((9.8, 1.9), radius: 0.09, fill: gray.lighten(20%), stroke: 0.7pt + warn)
    content((8.8, 3.15), text(size: 7pt)[$(x, y)$])
    content((9.8, 3.15), text(size: 7pt)[$(x+1, y)$])
    content((8.8, 1.62), text(size: 7pt)[$(x, y+1)$])
    content((9.8, 1.62), text(size: 7pt, fill: warn)[辅助片元])
    // 右侧说明框
    rect((10.65, 1.2), (13.5, 4.2), fill: white, stroke: 0.7pt + accent2, radius: 0.08)
    content((12.08, 3.75), text(size: 7.5pt, weight: "bold")[硬件 Quad 机制])
    content((12.08, 3.1), text(size: 7.2pt)[• 最小调度粒度 $2 times 2$])
    content((12.08, 2.55), text(size: 7.2pt)[• 同步求偏导 $partial u \/ partial x$])
    content((12.08, 2.0), text(size: 7.2pt)[• 边界处激活辅助片元])
    content((12.08, 1.48), text(size: 7.2pt, fill: warn)[• 亚像素三角形效率下降])
  })),
  caption: [Pineda 半平面边函数光栅化与 GPU $2 times 2$ 像素四元组（Quad）调度机制。左图展示屏幕包围盒内利用三个有向边函数并行判定像素中心 $(x+0.5, y+0.5)$ 是否在三角形内；右图展示硬件以 $2 times 2$ Quad 为单位派发片元以计算纹理偏导数。],
) <fig:ch04-edge-raster>

=== 共享边消歧与顶左规则（Top-Left Rule）

如 @fig:ch04-edge-raster 所示，当网格中两个相邻三角形共享一条公共边，且某个像素中心恰好严格落在公共边上（即 $E_(i j)(x, y) = 0$）时，若简单采用 `>= 0` 判据，该像素会被两个三角形同时光栅化，在半透明混合（Alpha Blending）下产生亮线瑕疵；若简单采用 `> 0` 判据，该像素又会被两个三角形同时丢弃，产生一像素宽的漏光裂缝。

为了保证每个边界像素被且仅被一个三角形拥有，DirectX 与 OpenGL/Vulkan 硬件管线普遍采用*顶左规则*（Top-Left Rule）@akenine2018realtime：当 $E_(i j)(x, y) = 0$ 时，该像素属于当前三角形当且仅当有向边 $bold(p)_i -> bold(p)_j$ 是*顶边*（Top Edge）或*左边*（Left Edge）。在 $y$ 轴向上、逆时针环绕的屏幕坐标系下：
- *顶边*是指完全水平且位于三角形上方的边，满足 $A_(i j) = y_j - y_i = 0$ 且 $x_j - x_i < 0$（即 $B_(i j) > 0$）；
- *左边*是指严格向下延伸、位于三角形左侧的边，满足 $y_j - y_i < 0$（即 $A_(i j) > 0$）。
由于两个共享同一条几何边的相邻三角形在该边上的环绕方向必然相反 $(bold(p)_i -> bold(p)_j$ 与 $bold(p)_j -> bold(p)_i)$，其向量 $(A_(i j), B_(i j))$ 恰好互为相反数，因此一条共享边对于其中一个三角形是顶边或左边时，对于另一个三角形必然是底边或右边，从而在数学上严格实现了零重叠、零裂缝的完备平面剖分。

== 重心坐标与透视校正插值的严格推导 <sec:ch04-barycentric>

判定像素中心属于三角形后，下一步是将三角形三个顶点上的属性（如纹理坐标 $(u, v)$、法线 $bold(n)$、颜色 $bold(c)$）插值到像素中心。边函数不仅给出了内外判定，还直接提供了屏幕空间的重心坐标（Barycentric Coordinates）。

=== 屏幕空间重心坐标与三维空间重心坐标

观察边函数 @eq:ch04-edge-func 的几何意义：$E_(01)(x_2, y_2)$ 恰好等于三角形 $triangle bold(p)_0 bold(p)_1 bold(p)_2$ 有向面积的两倍（记为 $2 A_triangle$）。同理，对于三角形内任意一点 $bold(p) = (x, y)^top$，$E_(12)(x, y)$、$E_(20)(x, y)$ 与 $E_(01)(x, y)$ 分别等于三个子三角形 $triangle bold(p) bold(p)_1 bold(p)_2$、$triangle bold(p)_0 bold(p) bold(p)_2$ 与 $triangle bold(p)_0 bold(p)_1 bold(p)$ 有向面积的两倍。因此，点 $bold(p)$ 在二维屏幕空间中的重心坐标 $(alpha', beta', gamma')$ 可由边函数直接归一化得到：
$ alpha' = (E_(12)(x, y))/(2 A_triangle), quad beta' = (E_(20)(x, y))/(2 A_triangle), quad gamma' = (E_(01)(x, y))/(2 A_triangle) = 1 - alpha' - beta'. $ <eq:ch04-screen-bary>

然而，初学者最常犯的错误是直接用屏幕空间重心坐标 $(alpha', beta', gamma')$ 对三维顶点属性 $I_0, I_1, I_2$ 做线性加权 $I' = alpha' I_0 + beta' I_1 + gamma' I_2$。当三角形与相机光轴存在倾角时，这种直接插值会导致纹理在三角形对角线处发生明显的折断与拉伸失真（如经典的棋盘格地面扭曲）。其根本原因在于：*透视投影是分式线性变换（射影变换）而非仿射变换，它保持直线性，但不保持距离比与重心坐标*。

#figure(
  diagram(cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // 相机中心与坐标轴
    let cam = (1.0, 2.5)
    circle(cam, radius: 0.11, fill: accent, stroke: none)
    content((0.8, 2.05), text(size: 7.5pt, weight: "bold")[相机光心 $bold(o)$])
    // 光轴 z
    line((0.5, 2.5), (12.8, 2.5), mark: (end: ">"), stroke: (dash: "dashed", paint: gray, thickness: 0.7pt))
    content((12.4, 2.15), text(size: 7.5pt)[相机深度 $z_"view"$])
    // 成像平面 z = 1
    let x_img = 4.2
    line((x_img, 0.5), (x_img, 4.7), stroke: 1.3pt + accent)
    content((4.2, 4.95), text(size: 7.8pt, weight: "bold", fill: accent)[屏幕平面（均匀步长 $Delta alpha' = 0.25$）])

    // 三维空间倾斜线段 P0 - P1
    let p0 = (7.2, 4.3)
    let p1 = (11.8, 0.9)
    line(p0, p1, stroke: 1.6pt + accent2)
    content((9.8, 4.55), text(size: 7.8pt, weight: "bold", fill: accent2)[三维倾斜表面线段（非均匀步长 $Delta alpha$）])

    // 5 条均匀分布在屏幕平面上的视线
    for i in range(5) {
      let t_scr = i / 4.0
      // P0 在屏幕上的 y 与 P1 在屏幕上的 y
      let y0_scr = 2.5 + (4.3 - 2.5) * (x_img - 1.0) / (7.2 - 1.0)
      let y1_scr = 2.5 + (0.9 - 2.5) * (x_img - 1.0) / (11.8 - 1.0)
      let y_scr = (1.0 - t_scr) * y0_scr + t_scr * y1_scr
      // 求射线与三维线段 P0-P1 的交点
      // 射线: (1.0 + s*(x_img - 1.0), 2.5 + s*(y_scr - 2.5))
      // 线段: (7.2 + u*(11.8 - 7.2), 4.3 + u*(0.9 - 4.3))
      let dx_r = x_img - 1.0
      let dy_r = y_scr - 2.5
      let dx_l = 11.8 - 7.2
      let dy_l = 0.9 - 4.3
      let det_val = dx_r * (-dy_l) - dy_r * (-dx_l)
      let rhs_x = 7.2 - 1.0
      let rhs_y = 4.3 - 2.5
      let s_val = (rhs_x * (-dy_l) - rhs_y * (-dx_l)) / det_val
      let hit_x = 1.0 + s_val * dx_r
      let hit_y = 2.5 + s_val * dy_r

      line(cam, (hit_x, hit_y), stroke: 0.7pt + gray.darken(10%))
      circle((x_img, y_scr), radius: 0.08, fill: accent, stroke: none)
      circle((hit_x, hit_y), radius: 0.09, fill: accent2, stroke: none)
    }

    content((7.0, 4.65), text(size: 7.5pt, weight: "bold")[$bold(p)_0 (z_0)$])
    content((12.3, 0.8), text(size: 7.5pt, weight: "bold")[$bold(p)_1 (z_1)$])
    content((3.15, 3.65), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt, fill: accent)[$alpha' = 0.5$])
    content((9.1, 3.2), frame: "rect", fill: white, stroke: none, padding: 0.05, text(size: 7.2pt, fill: accent2)[近端密、远端疏])
  })),
  caption: [透视投影下屏幕空间重心坐标 $(alpha', beta', gamma')$ 与三维视图空间重心坐标 $(alpha, beta, gamma)$ 的非线性畸变。屏幕平面上的等距均匀采样点投射到倾斜三维表面时，近相机端采样密集而远端稀疏，导致直接线性插值违背射影几何。],
) <fig:ch04-persp-correct>

=== 透视校正插值定理与证明

为了从屏幕空间重心坐标 $(alpha', beta', gamma')$ 精确恢复三维空间中的真实重心坐标 $(alpha, beta, gamma)$，下面给出严格推导（几何直觉见 @fig:ch04-persp-correct）。

#theorem(title: [透视校正重心插值定理])[
  设三角形三个顶点在相机视图空间中的深度（沿光轴方向的正距离）分别为 $z_0, z_1, z_2 > 0$，顶点携带的仿射线性属性分别为 $I_0, I_1, I_2$。若某像素中心在屏幕空间的重心坐标为 $(alpha', beta', gamma')$，则该像素对应的三维表面点在相机空间中的真实重心坐标 $(alpha, beta, gamma)$、真实深度 $z_"view"$ 以及透视校正后的属性值 $I$ 满足：
  $ (1)/(z_"view") = alpha' (1)/(z_0) + beta' (1)/(z_1) + gamma' (1)/(z_2), $ <eq:ch04-inv-z>
  $ (alpha, beta, gamma) = (z_"view" (alpha')/(z_0), thick z_"view" (beta')/(z_1), thick z_"view" (gamma')/(z_2)), quad I = z_"view" (alpha' (I_0)/(z_0) + beta' (I_1)/(z_1) + gamma' (I_2)/(z_2)). $ <eq:ch04-persp-interp>
]

#proof[
  设三角形三个顶点在相机空间中的三维坐标为 $bold(p)_i = (X_i, Y_i, -z_i)^top$（$i in {0, 1, 2}$，按右手系相机看向 $-z$ 轴约定，$z_i > 0$ 为正深度）。经焦距为 $f$ 的针孔透视投影后，顶点在屏幕像平面上的二维投影坐标为 $bold(q)_i = (f X_i \/ z_i, f Y_i \/ z_i)^top$。

  考虑三维三角形平面上的任意一点 $bold(p) = alpha bold(p)_0 + beta bold(p)_1 + gamma bold(p)_2$，其中三维真实重心坐标满足 $alpha + beta + gamma = 1$。其相机正深度为：
  $ z_"view" = alpha z_0 + beta z_1 + gamma z_2, $
  其屏幕投影坐标 $bold(q)$ 为：
  $ bold(q) = (f)/(z_"view") (alpha vec(X_0, Y_0) + beta vec(X_1, Y_1) + gamma vec(X_2, Y_2)) = ((alpha z_0)/(z_"view")) bold(q)_0 + ((beta z_1)/(z_"view")) bold(q)_1 + ((gamma z_2)/(z_"view")) bold(q)_2. $
  另一方面，根据屏幕空间重心坐标 $(alpha', beta', gamma')$ 的定义，同一屏幕点 $bold(q)$ 唯一地表示为 $bold(q) = alpha' bold(q)_0 + beta' bold(q)_1 + gamma' bold(q)_2$ 且 $alpha' + beta' + gamma' = 1$。因为对于非退化投影三角形，重心坐标表示具有唯一性，逐项对比系数即得：
  $ alpha' = (alpha z_0)/(z_"view"), quad beta' = (beta z_1)/(z_"view"), quad gamma' = (gamma z_2)/(z_"view") quad ==> quad alpha = z_"view" (alpha')/(z_0), quad beta = z_"view" (beta')/(z_1), quad gamma = z_"view" (gamma')/(z_2). $
  再将上述关系代入三维重心坐标归一化约束 $alpha + beta + gamma = 1$，两边同除以 $z_"view"$，即证得倒数深度的屏幕线性插值公式 @eq:ch04-inv-z。最后将 $(alpha, beta, gamma)$ 代入三维线性属性插值式 $I = alpha I_0 + beta I_1 + gamma I_2$，立即得到 @eq:ch04-persp-interp。
]

#remark(title: [硬件管线的实现方式])[
  @eq:ch04-inv-z 与 @eq:ch04-persp-interp 揭示了一个关键不变量：虽然深度 $z_"view"$ 和属性 $I$ 在屏幕空间不是线性的，但*深度的倒数 $1 \/ z_"view"$（即齐次裁剪空间的 $1 \/ w_"clip"$）以及属性与深度之比 $I \/ z_"view"$ 在屏幕空间是严格线性的*！因此现代 GPU 在顶点着色器之后预先计算每个顶点的 $(1 \/ w_i, I_i \/ w_i)$，在光栅化阶段用屏幕重心坐标 $(alpha', beta', gamma')$ 对它们做普通线性插值，最后在每个片元处执行一次倒数运算恢复 $w_"view"$ 并乘回各属性通道@akenine2018realtime。
]

== 可见性问题：画家算法、Z-Buffer 深度缓冲与 Early-Z <sec:ch04-zbuffer>

当场景中包含多个相互遮挡的三角形时，渲染器必须决定每个像素最终显示哪个三角形的片元，这称为*可见性问题*（Visibility Problem）。

=== 画家算法的循环遮挡失效与 Catmull 深度缓冲

早期图形学曾采用*画家算法*（Painter's Algorithm）：先将场景中的所有多边形按深度从远到近（Back-to-Front）排序，然后依次绘制到帧缓冲中，使近处物体自然覆盖远处物体。然而画家算法存在两个致命缺陷：第一，每一帧对 $N$ 个三角形排序需要 $O(N log N)$ 开销；第二，当三个三角形在空间中形成「$T_1$ 遮挡 $T_2$、$T_2$ 遮挡 $T_3$、$T_3$ 又遮挡 $T_1$」的循环重叠（Cyclic Overlap）或相互穿插时，全局偏序关系根本不存在，除非动态切分几何体，否则无法正确绘制。

1974 年，Edwin Catmull 在其博士论文中提出了*Z-Buffer（深度缓冲）算法*@catmull1974subdivision，彻底将可见性判定从「图元级排序」下沉到「像素级比较」。系统在颜色缓冲（Color Buffer）之外维护一块同分辨率的深度缓冲 $Z[x, y]$，初始值设为无穷远。光栅化任意三角形时，若像素 $(x, y)$ 处的新片元深度 $z_"frag" < Z[x, y]$，则更新 $Z[x, y] <- z_"frag"$ 并写入新颜色；否则直接丢弃该片元。因为最小值运算 $min(z_1, z_2, dots, z_k)$ 满足交换律与结合律，不透明几何体的最终渲染结果与三角形提交顺序完全无关，且时间复杂度降为线性 $O(N)$。

=== 深度精度分布、Reverse-Z 与 Early-Z / Hi-Z 硬件剔除

在第 2 章推导的透视投影矩阵中，标准化设备坐标（NDC）的深度 $z_"ndc" in [0, 1]$ 与视图空间正深度 $z_"view" in [n, f]$ 满足双曲映射关系 $z_"ndc" = A + B \/ z_"view"$。由于 $1 \/ z_"view"$ 在屏幕空间是线性的（见 @eq:ch04-inv-z），硬件直接对 $z_"ndc"$ 做屏幕线性插值并存入 Z-Buffer，免去了逐像素除法。然而，双曲函数在近裁剪面 $n$ 附近斜率极大、在远裁剪面 $f$ 附近极其平缓。若使用标准映射（近平面映射到 $0$、远平面映射到 $1$），IEEE 754 浮点数在接近 $0$ 处的高指数精度与 $1 \/ z_"view"$ 的陡峭变化相互抵消，导致远处物体极易发生深度冲突（Z-Fighting）。现代引擎普遍采用 *Reverse-Z* 技术@akenine2018realtime：将近平面 $n$ 映射到 $1.0$、远平面 $f$ 映射到 $0.0$，并配合 32 位浮点深度缓冲，利用浮点数在 $0$ 附近极高的尾数分辨率完美补偿远处 $1 \/ z_"view"$ 的压缩，使整个视锥体内的深度精度提升数个数量级。

在硬件执行流水线上，经典的深度测试位于片元着色器（Fragment Shader）之后（称为 Late-Z）。但若一个片元最终被遮挡，此前昂贵的纹理采样与光照计算就完全浪费了（称为 Overdraw）。为此，现代 GPU 引入了两级硬件加速机制：
1. *Early-Z（提前深度测试）*：光栅化生成片元后、进入片元着色器之前，硬件先读取深度缓冲进行测试；若未通过则直接丢弃片元。注意：若片元着色器中调用了 `discard`（Alpha 测试）或显式修改了输出深度 `gl_FragDepth`，硬件将被迫关闭 Early-Z 回退到 Late-Z。
2. *Hierarchical-Z（Hi-Z，层次深度缓冲）*：GPU 在片上缓存中维护深度缓冲的多分辨率金字塔，每个粗糙块记录 $8 times 8$ 像素区域的最大深度 $z_"max"$。当一个新三角形块的最小深度大于该区域的 $z_"max"$ 时，整块像素在进入细粒度光栅化前即被整批剔除。

对于半透明物体（Alpha Blending，$C_"out" = alpha C_"src" + (1 - alpha) C_"dst"$），由于混合算子不满足交换律，Z-Buffer 无法自动解决可见性。工业界标准管线采取「两阶段渲染」：先开启深度写入与 Early-Z 绘制所有不透明物体；再关闭深度写入（保留深度测试），将半透明物体按由远及近排序后依次叠加绘制。

=== 算法实现：含透视校正与 Z-Buffer 的 Python 软光栅化器

下面给出一个自包含、可直接运行的 Python（NumPy）软光栅化器实现，完整串联包围盒裁剪、边函数求值、透视校正插值与 Z-Buffer 深度测试：

```python
import numpy as np

def rasterize_triangle(verts_scr, verts_z, verts_attr, color_buf, depth_buf):
    """
    透视校正三角形软光栅化器 (CCW 环绕, 像素中心采样 (x+0.5, y+0.5))
    verts_scr : (3, 2) 屏幕空间坐标 [(x0,y0), (x1,y1), (x2,y2)]
    verts_z   : (3,)   相机视图空间正深度 [z0, z1, z2] (z_i > 0)
    verts_attr: (3, C) 顶点属性 (如 RGB 颜色或 UV 坐标)
    color_buf : (H, W, C) 帧颜色缓冲, depth_buf : (H, W) 深度缓冲 (初始为 +inf)
    """
    H, W, _ = color_buf.shape
    (x0, y0), (x1, y1), (x2, y2) = verts_scr
    # 计算有向面积的两倍 2 * A_Delta (背面剔除: 若 <= 0 则直接返回)
    area2 = (x2 - x0) * (y1 - y0) - (y2 - y0) * (x1 - x0)
    if area2 <= 1e-8:
        return
    # 计算屏幕空间包围盒并与视口 [0, W) x [0, H) 裁剪
    xmin = max(0, int(np.floor(min(x0, x1, x2))))
    xmax = min(W - 1, int(np.ceil(max(x0, x1, x2))))
    ymin = max(0, int(np.floor(min(y0, y1, y2))))
    ymax = min(H - 1, int(np.ceil(max(y0, y1, y2))))
    if xmin > xmax or ymin > ymax:
        return

    # 构造包围盒内像素中心网格 (px, py)
    xs = np.arange(xmin, xmax + 1) + 0.5
    ys = np.arange(ymin, ymax + 1) + 0.5
    px, py = np.meshgrid(xs, ys)

    # 半平面边函数 E_12, E_20, E_01 (对应面积与顶点的同向符号定义)
    e12 = (px - x1) * (y2 - y1) - (py - y1) * (x2 - x1)
    e20 = (px - x2) * (y0 - y2) - (py - y2) * (x0 - x2)
    e01 = (px - x0) * (y1 - y0) - (py - y0) * (x1 - x0)
    mask = (e12 >= 0.0) & (e20 >= 0.0) & (e01 >= 0.0)
    if not np.any(mask):
        return

    # 屏幕空间重心坐标 (alpha', beta', gamma')
    alpha_p = e12[mask] / area2
    beta_p  = e20[mask] / area2
    gamma_p = e01[mask] / area2

    # 透视校正插值: 先插值 1/z_view, 恢复 z_view
    inv_z = alpha_p / verts_z[0] + beta_p / verts_z[1] + gamma_p / verts_z[2]
    z_view = 1.0 / inv_z

    # Z-Buffer 深度测试
    sub_depth = depth_buf[ymin:ymax + 1, xmin:xmax + 1]
    z_cur = sub_depth[mask]
    vis = z_view < z_cur
    if not np.any(vis):
        return

    # 更新通过深度测试的像素深度与透视校正属性
    alpha_v, beta_v, gamma_v, z_v = alpha_p[vis], beta_p[vis], gamma_p[vis], z_view[vis]
    attr_over_z = (alpha_v[:, None] * (verts_attr[0] / verts_z[0]) +
                   beta_v[:, None]  * (verts_attr[1] / verts_z[1]) +
                   gamma_v[:, None] * (verts_attr[2] / verts_z[2]))
    attr_interp = z_v[:, None] * attr_over_z

    # 写回缓冲区
    iy, ix = np.where(mask)
    sub_depth[iy[vis], ix[vis]] = z_v
    color_buf[ymin + iy[vis], xmin + ix[vis]] = attr_interp
```

== 空间与时间抗锯齿：SSAA、MSAA 与时间超分辨率（TAA / DLSS） <sec:ch04-aa>

从信号处理的视角审视，三角形光栅化本质上是用二维狄拉克梳状函数（像素中心网格）对连续的屏幕画面做点采样。由于三角形边界处的阶跃指示函数 $H(E_(i j)(x, y))$ 在空间上是不连续的，其二维傅里叶频谱在高频段按 $1 \/ omega$ 缓慢衰减，频谱带宽无穷大。根据奈奎斯特—香农采样定理，超出像素采样频率一半（Nyquist 极限）的高频分量会发生频谱混叠（Aliasing），在静态画面中表现为边缘阶梯状锯齿（Jaggies），在动态画面中则表现为亚像素细小几何体忽明忽暗的闪烁（ Temporal Shimmering）。

=== 空间域抗锯齿：从 SSAA 到 MSAA 的覆盖—着色解耦

最直观的抗锯齿方案是*超级采样抗锯齿*（Supersampling Anti-Aliasing, SSAA）：将帧缓冲与深度缓冲的分辨率扩大 $N$ 倍（例如 $4 times$ SSAA），对每个子样本完整执行一次光栅化、深度测试与片元着色，最后下采样平均到输出像素。SSAA 能同时消除几何边缘锯齿与着色器内部高频走样（如高光闪烁），但其片元着色开销与显存带宽均暴增 $N$ 倍，难以在实时高分辨率渲染中承受。

*多重采样抗锯齿*（Multisample Anti-Aliasing, MSAA）@akenine2018realtime 通过*解耦几何覆盖率采样与片元着色计算*解决了这一瓶颈。在 $4 times$ MSAA 中，每个像素内部设置 4 个亚像素采样点（常采用旋转网格 Rotated Grid 或 N-Rooks 排布以兼顾近水平与近垂直边缘）：
- *覆盖与深度按子样本评估*：边函数包含测试与 Z-Buffer 深度测试在全部 4 个子样本上独立执行，每个子样本维护各自的颜色与深度槽位；
- *片元着色按像素执行一次*：只要一个三角形覆盖了当前像素的至少一个子样本，硬件仅在像素中心（或被覆盖子样本的几何形心 Centroid，以防止纹理采样越界）运行*一次*片元着色器，并将算出的颜色广播写入所有通过深度测试的被覆盖子样本中。
当三角形完全覆盖像素内部时，MSAA 的着色开销与无抗锯齿完全一致；仅在三角形边界像素处，多个三角形的颜色才会在不同子样本槽位中混合，从而以极低的着色代价平滑几何边缘。然而，MSAA 存在两大局限：一是无法抑制三角形内部的*着色器走样*（如高频法线贴图引起的镜面高光闪烁）；二是在延迟着色（见第 5 章）中需要对庞大的 G-Buffer 进行多重采样，显存带宽开销急剧膨胀。

=== 时间域抗锯齿（TAA）与神经时间超分辨率（DLSS / FSR）

为了突破单帧空间采样率的物理上限，现代游戏引擎全面转向*时间抗锯齿*（Temporal Anti-Aliasing, TAA）@yang2020taa。TAA 的核心思想是将原本需要在单帧内完成的 $N$ 次超采样*分摊到连续的 $N$ 个时间帧上*：
1. *亚像素投影抖动（Sub-pixel Jittering）*：在第 $t$ 帧渲染前，利用低差异序列（如长度为 8 或 16 的 Halton$(2, 3)$ 序列）生成亚像素偏移 $(delta x_t, delta y_t) in [-0.5, 0.5]^2$，注入透视投影矩阵的平移项，使每一帧的采样网格观测到略微不同的亚像素位置。
2. *运动向量重投影（Motion Vector Reprojection）*：渲染器在 G-Buffer 中额外输出每个像素从上一帧到当前帧的二维屏幕空间运动向量 $bold(v)(bold(x))$（由第 $t$ 帧与第 $t-1$ 帧的模型—视图—投影矩阵之差算出）。当前帧像素 $bold(x)$ 通过回溯坐标 $bold(x)_(t-1) = bold(x) - bold(v)(bold(x))$ 在上一帧历史累积缓冲 $H_(t-1)$ 中双线性采样历史颜色。
3. *邻域钳制与鬼影抑制（Neighborhood Clamping）*：当物体运动导致背景原先被遮挡的区域在新一帧暴露（Disocclusion），或者表面高光随视角剧烈变化时，历史缓冲中的旧颜色已不再有效，直接做指数移动平均 $H_t = alpha C_t + (1 - alpha) H_(t-1)$ 会产生严重的拖影（Ghosting）。为此，TAA 在亮度与色度解耦的 YCoCg 色彩空间中，统计当前帧像素周围 $3 times 3$ 邻域的颜色均值 $bold(mu)$ 与标准差 $bold(sigma)$，构建轴对齐包围盒（Variance Clipping AABB）$[bold(mu) - gamma bold(sigma), bold(mu) + gamma bold(sigma)]$，将历史颜色 $H_(t-1)(bold(x)_(t-1))$ 强制钳制到该包围盒内后再与当前帧混合@yang2020taa。

在此基础上，以 NVIDIA DLSS、AMD FSR 与 Intel XeSS 为代表的*时间超分辨率*技术进一步将「抗锯齿」与「超分辨率重建」合二为一：管线以较低的原生分辨率（如 1080p）配合 Halton 抖动渲染当前帧，再将低分辨率颜色、深度、运动向量与高分辨率历史帧输入轻量化卷积/Transformer 神经网络或手工设计的空时核，直接重建出高分辨率（如 4K）抗锯齿画面。@tab:ch04-aa-compare 总结了五类主流抗锯齿与超分方案的技术特性。

#figure(
  table(
    columns: (2.0cm, 2.3cm, 2.3cm, 2.5cm, 4.4cm),
    align: (left, center, center, center, left),
    [抗锯齿技术], [片元着色倍率], [显存带宽开销], [抑制着色器走样], [核心机制与主要工程局限],
    [SSAA], [$N times$（极高）], [$N times$（极高）], [完全支持], [全管线超分辨率光栅与着色；算力成本过高，仅用于离线或基准对比],
    [MSAA], [$approx 1 times$], [中～高], [不支持], [解耦子样本覆盖/深度与单次像素着色@akenine2018realtime；与延迟渲染 G-Buffer 兼容性差],
    [FXAA / SMAA], [$1 times$（后处理）], [极低], [部分平滑], [基于屏幕空间亮度梯度检测边缘并做形态学模糊；缺乏亚像素信息，动态画面易闪烁],
    [TAA], [$1 times$], [低（历史帧）], [支持], [Halton 抖动 + 运动向量重投影 + YCoCg 邻域钳制@yang2020taa；易引入动态模糊与遮挡鬼影],
    [DLSS / FSR], [$< 1 times$（降采样）], [低], [支持], [低分辨率抖动渲染 + 空时/神经网络高分辨率重建；大幅提升帧率，是目前工业界标配],
  ),
  caption: [现代实时渲染管线中五类主流空间与时间抗锯齿/超分辨率技术的全方位对比。],
) <tab:ch04-aa-compare>

== 现代演进：微多边形虚拟几何（Nanite）与可编程软光栅 <sec:ch04-frontier>

在传统实时渲染管线中，硬件光栅化器假定单个三角形的面积通常覆盖数十至数百个像素。然而，随着影视级高精度扫描资产（单模型数千万三角形）进入实时引擎，当三角形在屏幕上的投影面积缩小到 $1$ 个像素甚至亚像素级别（Micropolygon）时，传统硬件光栅化管线遭遇了严峻的性能崩塌。

=== 亚像素三角形的 Quad 过绘制危机与 Nanite 混合光栅架构

【已有成果】如 @sec:ch04-edge 所述，GPU 硬件光栅化器以 $2 times 2$ 像素四元组（Quad）作为最小调度单元。当一个微多边形三角形仅覆盖 1 个像素时，硬件仍然必须分配一整个 $2 times 2$ Quad（其中 3 个像素是不写入帧缓冲的辅助片元 Helper Lanes），导致有效计算利用率跌至 $25%$；同时，硬件光栅化器每拍（Cycle）建立三角形边函数（Triangle Setup）的固定吞吐率也成为瓶颈。

2021 年，Brian Karis 等人在 Unreal Engine 5 中提出的 *Nanite 虚拟微多边形几何系统*@karis2021nanite 彻底重构了实时几何与光栅化管线。Nanite 的核心创新包含两个紧密咬合的层面：
1. *簇有向无环图（Cluster DAG）与无裂缝层次细节*：离线阶段将高模网格切分为每组最多 128 个三角形的几何簇（Cluster），通过两两分组简化构建具有共享边界锁定的有向无环图（DAG）。运行时在 GPU 计算着色器（Compute Shader）中结合上一帧的 Hi-Z 深度金字塔，一次性完成视锥剔除、遮挡剔除与屏幕投影误差选择，仅将屏幕误差恰好约等于 1 像素的叶节点簇留存下来。
2. *硬件/计算着色器混合光栅化与 64 位原子可见性缓冲*：对于屏幕包围盒较大的三角形簇，Nanite 仍走传统硬件光栅化管线；但对于占总数绝大多数的亚像素微小三角形，Nanite 绕过固定功能硬件光栅器，直接启动极简的计算着色器执行*可编程软光栅*（Software Rasterizer）@karis2021nanite。每个线程独立负责一个微三角形的边函数测试，摆脱了 $2 times 2$ Quad 的空转开销，并将「32 位深度值（高 32 位）+ 簇 ID 与三角形 ID（低 32 位）」打包为一个 64 位无符号整数，直接调用 `InterlockedMax`（64 位原子最大值算子）写入 `VisBuffer64`。由于高 32 位存放的是 Reverse-Z 深度，单条 64 位原子比较指令在硬件层面同时完成了 Z-Buffer 深度测试与几何标识写入，完全消除了片元着色阶段的 Overdraw。

【本书推断】从 Pineda 边函数到 Nanite 的演进揭示了现代图形硬件与软件栈的一条深层规律：当几何图元密度逼近像素奈奎斯特采样率时，「固定硬件光栅 + 重型片元着色」的耦合管线必然向「计算着色器软光栅 + 64 位可见性缓冲 + 延迟材质评估」的解耦架构收敛。随着下一代神经资产与三维高斯泼溅（见第 12 章）同传统网格管线深度融合，统一的 64 位原子可见性缓冲正在成为连接显式微多边形、隐式距离场与可微辐射基元的通用屏幕空间接口。

#keybox(title: [本章要点])[
  1. *边函数与顶左规则*：Pineda 边函数 $E_(i j)(x, y) = (x - x_i)(y_j - y_i) - (y - y_i)(x_j - x_i)$ 将三角形光栅化转化为三个可并行、可增量步进的半平面测试；顶左规则消除了共享边上的双重绘制与漏光裂缝。
  2. *透视校正重心插值*：透视投影下屏幕重心坐标 $(alpha', beta', gamma')$ 与三维空间重心坐标非线性相关；只有深度倒数 $1 \/ z_"view"$ 与属性深度比 $I \/ z_"view"$ 在屏幕空间保持严格线性，必须通过 @eq:ch04-inv-z 与 @eq:ch04-persp-interp 还原真实三维属性。
  3. *可见性与深度精度*：Catmull 的 Z-Buffer 以像素级深度比较替代了画家算法的图元级排序；Reverse-Z 结合 Early-Z / Hi-Z 硬件金字塔兼顾了远距离浮点深度精度与零无效着色。
  4. *抗锯齿与微多边形演进*：MSAA 在空间域解耦了覆盖采样与着色频率，TAA 与 DLSS 则利用 Halton 抖动、运动向量重投影与邻域钳制在时间域重建超分辨率画面；针对亚像素三角形的 $2 times 2$ Quad 效率危机，Nanite 通过 Cluster DAG 与计算着色器 64 位原子软光栅实现了影视级微多边形的实时渲染。
]
