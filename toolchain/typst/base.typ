// ============================================================
// base.typ — Niubook 系列统一版式
// 用法：main.typ 中 `#show: book-style.with(meta: meta)`
// meta 由 scripts/gen_meta.py 从 book.toml 生成到 _meta.typ。
// ============================================================

#import "tokens.typ": *
#import "components.typ": *

#let book-style(meta: (:), body) = {
  let title = meta.at("title", default: "未命名")
  let subtitle = meta.at("subtitle", default: none)
  let short-title = meta.at("short-title", default: title)
  let author = meta.at("author", default: "Niubook")
  let doc-title = if subtitle == none or subtitle == "" { title } else { title + "：" + subtitle }

  set document(title: doc-title, author: author)

  set page(
    paper: "a4",
    margin: (top: 2.4cm, bottom: 2.4cm, inside: 2.6cm, outside: 2.2cm),
    header: context {
      let hs = query(heading.where(level: 1).before(here()))
      if hs.len() > 0 {
        let h = hs.last()
        if h.numbering != none {
          set text(size: 8.5pt, fill: gray.darken(20%))
          grid(
            columns: (1fr, auto),
            align: (left, right),
            [#short-title],
            emph(h.body),
          )
          line(length: 100%, stroke: 0.4pt + softline)
        }
      }
    },
    footer: context {
      set text(size: 9pt, fill: gray.darken(20%))
      align(center, counter(page).display())
    },
  )

  set text(
    font: font-serif,
    size: 10.5pt,
    lang: "zh",
    region: "cn",
    fill: ink,
  )
  set par(justify: true, first-line-indent: (amount: 2em, all: false), leading: 0.8em, spacing: 1.4em)

  // 代码字体
  show raw: set text(font: font-mono, size: 8.5pt)
  show raw.where(block: true): it => block(
    fill: softbg, inset: 9pt, radius: 3pt, width: 100%,
    stroke: (left: 2.5pt + accent.lighten(30%)),
    it,
  )

  // 数学：按章编号 (章.式)
  set math.equation(numbering: n => {
    let ch = counter(heading).get().first()
    if ch == 0 { numbering("(1)", n) } else { "(" + str(ch) + "." + str(n) + ")" }
  })

  // 标题体系
  set heading(numbering: "1.1")
  show heading.where(level: 1): it => {
    // 每章重置各类计数器：定理类、图、表、公式均按章编号
    pagebreak(weak: true)
    if it.numbering != none {
      _thm-counter.update(0)
      counter(figure.where(kind: image)).update(0)
      counter(figure.where(kind: table)).update(0)
      counter(math.equation).update(0)
    }
    v(6pt)
    if it.numbering != none {
      block(below: 1.4em)[
        #set text(font: font-sans)
        #text(size: 13pt, weight: "bold", fill: accent)[第 #counter(heading).display("1") 章]
        #h(10pt)
        #text(size: 17pt, weight: "bold", fill: ink)[#it.body]
        #v(4pt)
        #line(length: 100%, stroke: 1.6pt + accent)
      ]
    } else {
      block(below: 1.4em)[
        #set text(font: font-sans)
        #text(size: 17pt, weight: "bold", fill: ink)[#it.body]
        #v(4pt)
        #line(length: 100%, stroke: 1.6pt + accent)
      ]
    }
  }
  show heading.where(level: 2): it => block(above: 1.3em, below: 0.75em, sticky: true)[
    #set text(font: font-sans, size: 13pt)
    #text(weight: "bold", fill: accent.darken(10%))[#counter(heading).display("1.1") #h(6pt) #it.body]
  ]
  show heading.where(level: 3): it => block(above: 1.1em, below: 0.6em)[
    #set text(font: font-sans, size: 11.5pt)
    #text(weight: "bold", fill: ink)[#counter(heading).display("1.1.1") #h(5pt) #it.body]
  ]

  // 图表标题
  set figure.caption(separator: [：])
  show figure.caption: set text(size: 9pt)
  show figure.caption: it => {
    text(fill: accent, weight: "semibold")[#it.supplement #context it.counter.display(it.numbering)]
    text(fill: ink)[#it.separator]
    it.body
  }
  // 图编号按章
  set figure(numbering: n => {
    let ch = counter(heading).get().first()
    if ch == 0 { str(n) } else { str(ch) + "-" + str(n) }
  })

  // 表格样式：单元格内禁止两端对齐（窄列两端对齐会撑开字距），
  // 统一左对齐、略小字号、加大单元格内边距与行距
  set table(stroke: (x, y) => (
    top: if y == 0 { 1pt + ink } else { 0pt },
    bottom: 0.4pt + softline,
  ))
  show table.cell: set par(justify: false, leading: 0.55em, first-line-indent: (amount: 0em, all: true))
  show table.cell: set text(size: 9pt)
  set table(inset: (x: 7pt, y: 5.5pt))
  show table.cell.where(y: 0): set text(weight: "bold", fill: accent.darken(15%))

  // 链接与引用
  show link: set text(fill: accent)
  set cite(style: "ieee")

  set outline(title: [目 录], indent: 1.6em, depth: 3)
  show outline.entry.where(level: 1): set text(weight: "bold", fill: accent.darken(10%), size: 11pt)

  body
}
