#import "_meta.typ": meta
#import "template.typ": *

#show: book-style.with(meta: meta)

// ---------- 封面 ----------
#page(header: none, footer: none)[
  #v(4cm)
  #align(center)[
    #text(size: 24pt, weight: "bold", fill: accent, font: font-sans)[#meta.title]
    #v(10pt)
    #text(size: 15pt, weight: "bold", font: font-sans)[#meta.subtitle]
    #v(18pt)
    #text(size: 11pt, fill: gray.darken(20%))[#meta.title_en]
    #v(3cm)
    #text(size: 11pt)[#meta.cover_note]
    #v(6pt)
    #text(size: 10pt, fill: gray.darken(30%))[#meta.audience]
  ]
]
#pagebreak()

// ---------- 目录 ----------
#outline()
#pagebreak()

// ---------- 前言 ----------
#include "chapters/preface.typ"
#counter(heading).update(0)

// ---------- 正文各章 ----------
#include "chapters/ch01.typ"
#include "chapters/ch02.typ"
#include "chapters/ch03.typ"
#include "chapters/ch04.typ"
#include "chapters/ch05.typ"
#include "chapters/ch06.typ"
#include "chapters/ch07.typ"
#include "chapters/ch08.typ"
#include "chapters/ch09.typ"
#include "chapters/ch10.typ"
#include "chapters/ch11.typ"
#include "chapters/ch12.typ"
#include "chapters/ch13.typ"
#include "chapters/ch14.typ"
#include "chapters/ch15.typ"
#include "chapters/ch16.typ"
#include "chapters/ch17.typ"
#counter(heading).update(0)
#include "chapters/appendix.typ"

// ---------- 参考文献 ----------
#heading(numbering: none)[参考文献]
#bibliography("references.bib", style: "ieee", title: none)
