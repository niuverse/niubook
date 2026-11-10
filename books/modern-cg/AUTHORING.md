# 作者规范 —《现代计算机图形学导论》（`modern-cg`）

本文件是 `books/modern-cg/` 的专用写作细则，在遵循仓库级 [`docs/AUTHORING.md`](../../docs/AUTHORING.md) 与 [`docs/FIGURES.md`](../../docs/FIGURES.md) 的基础上，针对**现代图形学基础教程**的教材定位做出明确约定。

## 1. 教材定位与系列规范适配

- **主干教材推演 + 章末前沿对齐**：本书是一部面向高年级本科生、低年级研究生与图形/视觉工程师的基础教程，而非纯论文综述。各章前 4 节以清晰、自包含的教材风格展开，遵循「物理/几何直觉 → 严格定义 → 核心数学推导 → 算法/代码示例」的闭环，对齐次变换、重心插值、微表面 BRDF、蒙特卡洛路径追踪、半边数据结构、基于位置的动力学（PBD）、神经辐射场（NeRF）与 3D Gaussian Splatting（3DGS）等核心基石做完整推导。
- **时效性与三档证据标签**：经典奠基工作（如 Kajiya 1986、Cook-Torrance 1982、Veach 1997、Lorensen-Cline 1987、Mildenhall 2020、Kerbl 2023 等）在正文作为核心理论详述；每章第 5 节固定为「现代演进与前沿视野」，集中讨论 2024–2026 年的工业界与学术界演进（如 Nanite 微多边形、ReSTIR、Mesh Shaders、2DGS、前馈式三维高斯重建与可微物理），并显式使用【已有成果】【本书推断】【本书提出】三档标签标注证据等级。

## 2. 文件与结构

- 每章一个文件 `chapters/ch01.typ` .. `chapters/ch13.typ`，首行必须为：
  ```typst
  #import "../template.typ": *
  #import "@preview/cetz:0.3.4"
  ```
- 每章必须且只能包含一个一级标题 `= 标题`，下辖 5 个二级标题 `== 标题 <sec:chNN-xxx>`。
- 严禁出现 `TODO`、`FIXME`、`TBD`、`XXX`、`待补`、`待编写`、`待填` 等占位词，严禁使用 `□`、`☐`、`◼` 等方块字符。

## 3. 全书统一数学符号与坐标系约定

- **坐标系与向量约定**：全书默认采用**右手坐标系（Right-Handed Coordinate System）**与**列向量左乘（$\mathbf{p}' = \mathbf{M}\mathbf{p}$）**约定；相机局部坐标系默认看向 $-z$ 轴（$+x$ 向右，$+y$ 向上），并在第 2 章与附录 A 中给出与 Vulkan/DirectX（$[0,1]$ 深度）及 COLMAP/3DGS（$+z$ 向前，$+y$ 向下）的精确换算矩阵。
- **几何与变换**：三维点/位置记为 $bold(p), bold(x) in RR^3$，方向或向量记为 $bold(v), bold(d) in RR^3$，单位表面法线记为 $bold(n) in SS^2$，半程向量记为 $bold(h) = ("normalize")(omega_i + omega_o)$，齐次变换矩阵记为 $bold(M) in RR^(4 times 4)$，重心坐标记为 $(alpha, beta, gamma)$。
- **辐射度量与渲染**：立体角记为 $omega in SS^2$（入射方向 $omega_i$ 与出射方向 $omega_o$ 均定义为**背离表面指向外侧**），天顶角余弦记为 $cos theta_i = max(0, bold(n) dot omega_i)$；辐射通量 $Phi$，辐照度 $E$，辐射出射度 $M$，辐射强度 $I$，辐射亮度（Radiance）$L(bold(x), omega)$；双向反射分布函数记为 $f_r (bold(x), omega_i, omega_o)$，可见性函数记为 $V(bold(x) <-> bold(y))$，几何耦合项记为 $G(bold(x) <-> bold(y))$。
- **概率、仿真与神经渲染**：期望记为 $EE$，概率记为 $PP$，概率密度函数记为 $p(x)$；体密度（消光系数）记为 $sigma(bold(x))$，透射率记为 $T(t)$，不透明度记为 $alpha_i$；3D 高斯中心记为 $bold(mu) in RR^3$，三维协方差矩阵记为 $bold(Sigma) = bold(R) bold(S) bold(S)^top bold(R)^top$，二维屏幕空间协方差记为 $bold(Sigma)' = bold(J) bold(W) bold(Sigma) bold(W)^top bold(J)^top$。

## 4. 图表、定理环境与代码规范

- **CeTZ 矢量图**：每章包含 2 幅精心排版的 CeTZ 矢量图，统一用 `#figure(diagram(cetz.canvas(length: 1cm, { ... })), caption: [...]) <fig:xxx>` 包裹，并在正文中以 `@fig:xxx` 引用。画布宽度不超过 15.0 cm，盒内文字显式控制行数（不超过 3 行，字号 7–8 pt），箭头留出清晰线杆，跨线标签必须加白底 `frame: "rect", fill: white, stroke: none`。
- **表格**：每章至少 1 张总结对比表，用 `#figure(table(...), caption: [...]) <tab:xxx>` 包裹并在正文 `@tab:xxx` 引用。
- **定理与要点框**：合理使用 `#definition`、`#theorem`、`#proposition`、`#lemma`、`#remark`、`#example`，章末必须以一段总结加 `#keybox(title: [本章要点])[...]` 收尾。
- **代码**：算子与数值算法使用可运行的 Python（NumPy / PyTorch / Taichi 风格）代码片段，实时渲染管线章节辅以精炼 GLSL 着色器代码。
