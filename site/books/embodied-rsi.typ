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

#html.elem("nav", attrs: (class: "toc"))[
  #outline(title: [目录], depth: 1)
]

#include "/books/embodied-rsi/chapters/preface.typ"
#include "/books/embodied-rsi/chapters/ch01.typ"
#include "/books/embodied-rsi/chapters/ch02.typ"
#include "/books/embodied-rsi/chapters/ch03.typ"
#include "/books/embodied-rsi/chapters/ch04.typ"
#include "/books/embodied-rsi/chapters/ch05.typ"
#include "/books/embodied-rsi/chapters/ch06.typ"
#include "/books/embodied-rsi/chapters/ch07.typ"
#include "/books/embodied-rsi/chapters/ch08.typ"
#include "/books/embodied-rsi/chapters/ch09.typ"
#include "/books/embodied-rsi/chapters/ch10.typ"
#include "/books/embodied-rsi/chapters/ch11.typ"
#include "/books/embodied-rsi/chapters/ch12.typ"
#include "/books/embodied-rsi/chapters/ch13.typ"
#include "/books/embodied-rsi/chapters/ch14.typ"
#include "/books/embodied-rsi/chapters/ch15.typ"
#include "/books/embodied-rsi/chapters/ch16.typ"
#include "/books/embodied-rsi/chapters/ch17.typ"
#counter(heading).update(0)
#include "/books/embodied-rsi/chapters/appendix.typ"

#bibliography("/books/embodied-rsi/references.bib", style: "ieee")
