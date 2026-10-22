// ============================================================
// components.typ — 全系列共用的定理环境、要点框与数学简写
// ============================================================

#import "tokens.typ": *

// ---------- 定理类计数器（须先于 book-style 定义，供章首重置） ----------
#let _thm-counter = counter("theorem")

// ---------- 定理类环境（定义/定理/引理/命题/推论/假设/注记/示例） ----------
#let theorem-env(kind, kind-cn, bgcolor, linecolor) = (title: none, body) => {
  _thm-counter.step()
  block(
    fill: bgcolor, inset: (x: 10pt, y: 8pt), radius: 2.5pt, width: 100%,
    stroke: (left: 2.5pt + linecolor), breakable: true,
  )[
    #context {
      let ch = counter(heading).get().first()
      let num = if ch == 0 { str(_thm-counter.get().first()) } else { str(ch) + "." + str(_thm-counter.get().first()) }
      text(weight: "bold", fill: linecolor.darken(20%), font: font-sans)[
        #kind-cn #num#if title != none [（#title）]
      ]
    }
    #v(2pt)
    #set par(first-line-indent: (amount: 0em, all: true))
    #body
  ]
}

#let definition(title: none, body) = theorem-env("def", "定义", bluebg, accent)(title: title, body)
#let theorem(title: none, body) = theorem-env("thm", "定理", rgb("#f2efe6"), accent2)(title: title, body)
#let lemma(title: none, body) = theorem-env("lem", "引理", rgb("#f2efe6"), accent2)(title: title, body)
#let proposition(title: none, body) = theorem-env("prop", "命题", rgb("#f2efe6"), accent2)(title: title, body)
#let corollary(title: none, body) = theorem-env("cor", "推论", rgb("#f2efe6"), accent2)(title: title, body)
#let assumption(title: none, body) = theorem-env("asm", "假设", softbg, gray.darken(30%))(title: title, body)
#let remark(title: none, body) = theorem-env("rmk", "注记", softbg, gray.darken(30%))(title: title, body)
#let example(title: none, body) = theorem-env("ex", "示例", softbg, gray.darken(30%))(title: title, body)

#let proof(body) = block[
  #set par(first-line-indent: (amount: 0em, all: true))
  #text(weight: "bold", fill: accent2.darken(10%))[证明.]
  #body
  #h(1fr) $square.stroked$
]

// ---------- 警示/要点框 ----------
#let keybox(title: [要点], body) = block(
  fill: redbg, inset: (x: 10pt, y: 8pt), radius: 2.5pt, width: 100%,
  stroke: (left: 2.5pt + warn), breakable: true,
)[
  #text(weight: "bold", fill: warn, font: font-sans)[#title]
  #v(2pt)
  #set par(first-line-indent: (amount: 0em, all: true))
  #body
]

// ---------- 常用数学简写 ----------
#let EE = math.op("𝔼")
#let PP = math.op("ℙ")
#let RR = math.cal("R")
#let argmax = math.op("arg max", limits: true)
#let argmin = math.op("arg min", limits: true)
