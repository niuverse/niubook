#let site-header(home) = html.elem("header", attrs: (class: "site-head"))[
  #html.elem("a", attrs: (class: "brand", href: home))[NIUBOOK]
  #html.elem("nav")[
    #html.elem("a", attrs: (href: home))[书目]
    #html.elem("a", attrs: (href: "https://github.com/niuverse/niubook"))[GitHub]
  ]
]

#let site-footer() = html.elem("footer", attrs: (class: "site-foot"))[
  #html.elem("p")[
    Niubook · 内容 CC BY-NC-SA 4.0 · 代码 MIT · AI 生成 · 人工统稿 ·
    #html.elem("a", attrs: (href: "https://github.com/niuverse/niubook/blob/main/NOTICE"))[权利声明]
  ]
]

#let book-head(book, pdf, cover) = {
  let num = if book.order < 10 { "0" + str(book.order) } else { str(book.order) }
  html.elem("header", attrs: (class: "book-head"))[
    #html.elem("div", attrs: (class: "book-head-text"))[
      #html.elem("p", attrs: (class: "eyebrow"))[Book #num · #book.edition]
      #html.elem("h1")[#book.title]
      #html.elem("p", attrs: (class: "subtitle"))[#book.subtitle]
      #html.elem("p", attrs: (class: "title-en"))[#book.title_en]
      #html.elem("p", attrs: (class: "book-meta"))[
        #book.author · #book.stats.pages 页 · #book.stats.references 文献 · #book.license.spdx
      ]
      #html.elem("p", attrs: (class: "actions"))[
        #html.elem("a", attrs: (class: "btn", href: pdf))[下载 PDF]
        #html.elem("a", attrs: (class: "btn ghost", href: "../index.html"))[返回书目]
      ]
    ]
    #html.elem("img", attrs: (
      class: "cover",
      src: cover,
      alt: "《" + book.title + "》封面",
      width: "240",
    ))
  ]
}
