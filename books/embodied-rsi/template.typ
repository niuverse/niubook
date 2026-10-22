// ============================================================
// template.typ — 本书主题入口
// 版式与组件全部来自系列工具链，本书暂不覆盖任何视觉令牌。
// 如需个性化：在本文件里 `#let accent = rgb("#...")` 覆盖即可。
// ============================================================

#import "../../toolchain/typst/base.typ": *

// HTML 导出时把 CeTZ 画布转成内联 SVG；PDF 路径原样返回。
#let diagram(body) = context {
  if target() == "html" { html.frame(body) } else { body }
}
