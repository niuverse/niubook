#set text(font: ("New Computer Modern", "Noto Serif CJK SC"), size: 10.5pt, lang: "zh", region: "cn")
#set heading(numbering: "1.1")
#set math.equation(numbering: n => {
  let ch = counter(heading).get().first()
  if ch == 0 { numbering("(1)", n) } else { "(" + str(ch) + "." + str(n) + ")" }
})
#set figure(numbering: n => {
  let ch = counter(heading).get().first()
  if ch == 0 { str(n) } else { str(ch) + "-" + str(n) }
})

// 行间公式用 Typst 自己的排版（SVG）；行内公式保留 MathML。
#show math.equation: it => {
  if target() == "html" and it.block {
    html.elem("div", attrs: (class: "equation"))[#html.frame(it)]
  } else {
    it
  }
}

#include "/books/modern-cg/chapters/preface.typ"
#counter(heading).update(0)
#include "/books/modern-cg/chapters/ch01.typ"
#include "/books/modern-cg/chapters/ch02.typ"
#include "/books/modern-cg/chapters/ch03.typ"
#include "/books/modern-cg/chapters/ch04.typ"
#include "/books/modern-cg/chapters/ch05.typ"
#include "/books/modern-cg/chapters/ch06.typ"
#include "/books/modern-cg/chapters/ch07.typ"
#include "/books/modern-cg/chapters/ch08.typ"
#include "/books/modern-cg/chapters/ch09.typ"
#include "/books/modern-cg/chapters/ch10.typ"
#include "/books/modern-cg/chapters/ch11.typ"
#include "/books/modern-cg/chapters/ch12.typ"
#include "/books/modern-cg/chapters/ch13.typ"
#counter(heading).update(0)
#include "/books/modern-cg/chapters/appendix.typ"

#bibliography("/books/modern-cg/references.bib", style: "ieee")
