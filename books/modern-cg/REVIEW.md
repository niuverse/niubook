# 审校台账 —《现代计算机图形学导论》

> 状态：v1.0.0 已发布（内容冻结，全部引用均已核验）。
> 本台账记录本书的质量门禁状态、文献核验结果与已知维护项。

## 1. 发布门槛

v1.0.0 的发布判断：**全书 13 章正文、前言、附录 A/B/C 与 26 幅 CeTZ 矢量图均已完成编写与版式审计**；书目库共 78 条文献，全部为真实可核查的经典图形学专著与同行评审论文，`UNVERIFIED` 计数为 **0**。

发布前已确认：

- [x] 分页基线稳定，文本指纹（`pdftotext -layout`）可复现
- [x] 0 编译警告、0 未解析引用、0 重复标签
- [x] 78 条文献全部被正文引用（0 uncited，0 unverified）
- [x] 许可证与 AI 生成声明（`LICENSE` / `NOTICE` / `PROVENANCE.md`）完整同步

## 2. 文献核验（0 条待核）

本书采用的 78 条 BibTeX 文献涵盖图形学奠基文献（Sutherland 1963、Phong 1975、Blinn 1977/1978、Catmull-Clark 1978、Whitted 1980、Cook-Torrance 1982、Williams 1978/1983、Kajiya 1986、Lorensen-Cline 1987、Pineda 1988、Mitchell-Netravali 1988、Hart 1996、Garland-Heckbert 1997、Möller-Trumbore 1997、Veach 1997、Baraff-Witkin 1998）与现代图形学代表作（Ramamoorthi-Hanrahan 2001、Zwicker 2001、Sloan 2002、Ju 2002、Meyer 2003、Fernando 2005、Müller 2007、Walter 2007、Kavan 2008、Burley 2012、Burns-Hunt 2013、Heitz 2014、Macklin 2016、Li 2018、Hu 2019/2020、Liu 2019、Laine 2020、Bitterli 2020、Mildenhall 2020、Karis 2021、Barron 2021、Wang 2021、Müller 2021/2022、Kerbl 2023、Vaidyanathan 2023、Yu 2024、Huang 2024、Siddiqui 2024、Wu 2024、Charatan 2024 等），全部具备精确的作者、标题、年份与 DOI / ISBN / URL，无 `UNVERIFIED` 条目。

## 3. 已知问题与维护计划

| 问题 | 影响 | 计划 |
| --- | --- | --- |
| 知识截点为 2026-10 | 2026 年 11 月之后的神经图形学与硬件光追演进未纳入 | 随年度版次更新各章第 5 节「现代演进与前沿视野」 |
| CeTZ 矢量图代替位图渲染图 | 保持纯源码 100% 可复现构建与小体积矢量输出，但不含照片级位图对比 | 配合附录 C 的四个 Python 迷你编程实验由读者本地生成渲染图像 |
| 拉丁字体依赖 Typst 内置 New Computer Modern，中文依赖 Noto CJK | 跨版本 Typst 可能引起微小的断行漂移 | 工具链固定 Typst 0.15.1；升级时重跑 `just check-all` 与文本指纹 |

## 4. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-11-10 | v1.0.0：完成全书 13 章、前言、附录 A/B/C、26 幅 CeTZ 矢量图与 78 条文献入库，通过 G0–G6 全部质量门禁 |
