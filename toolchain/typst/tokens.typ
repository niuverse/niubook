// ============================================================
// tokens.typ — Niubook 系列视觉令牌（颜色与字体）
// 改这里会同时影响全系列；单本书请在自己的 theme.typ 里覆盖。
// ============================================================

// ---------- 配色（低饱和、暖调学术风） ----------
#let ink = rgb("#2b2b2b")        // 正文墨色
#let accent = rgb("#0f5c5c")     // 主色：深青
#let accent2 = rgb("#8c5a2b")    // 辅色：赭棕
#let softbg = rgb("#f6f4ef")     // 浅暖底
#let softline = rgb("#d9d4c8")   // 浅分隔线
#let redbg = rgb("#f9eeea")      // 警示底
#let bluebg = rgb("#eef3f5")     // 定理底
#let warn = rgb("#a04a3a")       // 警示强调

// ---------- 字体 ----------
// 拉丁与数学使用 Typst 内置的 New Computer Modern；中文回落系统 Noto CJK。
#let font-serif = ("New Computer Modern", "Noto Serif CJK SC")
#let font-sans = ("New Computer Modern", "Noto Sans CJK SC")
#let font-mono = ("DejaVu Sans Mono", "Noto Sans Mono CJK SC")
