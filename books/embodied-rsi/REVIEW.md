# 审校台账 —《具身递归自我改进》

> 状态：v1.0.0 已发布（内容冻结，引用待核）。
> 本台账记录所有已知未决项；`just check` 只保证结构、构建与元数据，不代替事实核验。

## 1. 发布门槛

v1.0.0 的发布判断：**正文内容由作者验证并冻结**；24 条文献仍带 `UNVERIFIED` 标注，
已在正文前言、书目与本台账中如实披露。`stable` 表示内容不再随版本漂移，不表示引用已全部核实。

发布前已确认：

- [x] 106 页构建基线稳定，文本指纹可复现
- [x] 0 编译警告、0 未解析引用
- [x] 24 条待核文献在书目中显式标注并在此登记
- [x] 许可证与 AI 生成声明（`LICENSE` / `NOTICE`）

## 2. 文献核验（24 条）

核验方法：按条目中的 arXiv ID / DOI 打开原文，核对标题、作者列表、年份与发表 venue；
无法确认的保留 `UNVERIFIED` 标注并在书目中说明。完成后勾选，并同步下调
`book.toml` 的 `stats.unverified` 与 `quality.max_unverified`。

- [ ] `agentrl2025` — 待核实作者
- [ ] `chen2026auditing` — 作者列表以 `and others` 省略，待补全
- [ ] `deepmind2026alphaevolveimpact` — 博客；URL 路径待核实
- [ ] `duan2026lastai` — 作者列表以 `and others` 省略，待补全
- [ ] `guo2026vlaw` — 作者全名待核实
- [ ] `harnessengineering2026` — 作者列表待核实（2026-04 首版，2026-07 修订）
- [ ] `hebbar2026sia` — 作者列表以 `and others` 省略，待补全
- [ ] `hierarchicalsi2026` — 待核实作者
- [ ] `lin2026agenticharness` — 作者列表以 `and others` 省略，待补全
- [ ] `liu2026mgm` — 作者列表以 `and others` 省略，待补全
- [ ] `meng2026rsibenchdata` — 作者顺序待核实
- [ ] `qin2026agenticrobots` — 作者列表待核实
- [ ] `rollart2025` — 待核实作者
- [ ] `srikanth2026aide2` — 作者列表以 `and others` 省略，待补全
- [ ] `sun2026reuse` — 作者列表以 `and others` 省略，待补全
- [ ] `terminalbench2026` — arXiv ID 待核实
- [ ] `wang2025hgm` — 作者拼写以 ICLR 2026 论文页为准
- [ ] `wang2026regenharness` — 作者全名待核实
- [ ] `wmrsurvey2026` — 待核实作者
- [ ] `xiao2025pld` — arXiv ID 待核实
- [ ] `yang2026rise` — 作者全名待核实
- [ ] `zhang2026ace` — arXiv ID 待核实
- [ ] `zhang2026hyperagents` — 作者列表以 `and others` 省略，待补全
- [ ] `zhao2026godelforest` — 作者列表以 `and others` 省略，待补全

### 2.1 自动核验结果（2026-10-22）

对 24 条逐条运行 `python3 scripts/audit_cites.py books/embodied-rsi --only-unverified`：

- **20 条**通过 arXiv 标题比对（相似度 ≥ 0.75），条目存在且标题一致；
- **4 条**无法自动核验：`deepmind2026alphaevolveimpact`（博客，无 arXiv）、
  `terminalbench2026`、`xiao2025pld`、`zhang2026ace`（缺可识别的 arXiv ID）。

结论：这些 flag 主要剩**作者列表、venue、个别 arXiv ID** 的元数据问题，
不是"文献是否存在"。因此保留 `UNVERIFIED` 标注，继续按人工流程核。

## 3. 已知问题

| 问题 | 影响 | 计划 |
| --- | --- | --- |
| PDF 内页没有独立的版权/AI 标识页 | 纸质打印件脱离站点后缺少 AI 声明 | 下一版加版权页（会增加 1–2 页，需同步更新 `stats.pages` 基线） |
| 65 条文献已分配但正文未引用 | 不影响渲染，但书目清单与实际引用不符 | 保留：作为后续版本与姊妹书的共享词库 |
| 第三方图表与长引文未逐项清权 | CC 许可不覆盖第三方材料 | 出版前做一次逐图/逐引核查 |
| 知识截点 2026-10 | 2026 年 10 月后的工作未覆盖 | 以 `edition` 标注；新版走 `PRODUCTION.md` 流程 |
| 拉丁字体依赖 Typst 内置 New Computer Modern | 大版本升级可能改变分页 | Typst 固定在 0.15.1；升级必须重跑文本指纹 |
| 中文依赖系统 Noto Serif/Sans CJK SC | 其他机器可能缺字 | `just doctor` 检查；CI 安装 `fonts-noto-cjk` |

## 4. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-22 | 建立台账；登记 24 条待核文献与 6 项已知问题 |
| 2026-10-22 | 修复 55 处方块字形（52 处清单方块 + 3 处 notdef 项目符号）；新增 `check.py` 方块门禁 |
| 2026-10-22 | v1.0.2：重排 8 幅图，修复文字出框、箭头断杆与标签重叠；新增 `docs/FIGURES.md` |
| 2026-10-22 | v1.0.3：工具链升级 Typst 0.15.1 / mdBook 0.5.4；106 页不变 |
