// ============================================================
// template.typ — 本书主题入口
// 版式与组件全部来自系列工具链，保持全系列统一的学术视觉令牌。
// ============================================================

#import "../../toolchain/typst/base.typ": *

// HTML 导出时把 CeTZ 画布转成内联 SVG；PDF 路径原样返回。
#let diagram(body) = context {
  if target() == "html" { html.frame(body) } else { body }
}
