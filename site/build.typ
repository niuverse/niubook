#import "lib.typ": *

#let catalog = json("/catalog/books.json")
#let book = catalog.books.at(0)

#document("index.html", title: "Niubook — 书目")[
  #html.elem("link", attrs: (rel: "stylesheet", href: "style.css"))
  #site-header("./index.html")
  #html.elem("main", attrs: (class: "page"))[
    #html.elem("h1")[书目]
    #html.elem("ul", attrs: (class: "book-list"))[
      #for b in catalog.books [
        #let idx = if b.order < 10 { "0" + str(b.order) } else { str(b.order) }
        #html.elem("li")[
          #html.elem("a", attrs: (class: "book-row", href: "books/" + b.slug + ".html"))[
            #html.elem("span", attrs: (class: "book-index"))[#idx]
            #html.elem("span", attrs: (class: "book-main"))[
              #html.elem("span", attrs: (class: "book-title"))[#b.title]
              #html.elem("span", attrs: (class: "book-sub"))[#b.subtitle]
            ]
            #html.elem("span", attrs: (class: "book-meta"))[#b.edition · #b.stats.pages 页 · #b.stats.references 文献]
          ]
        ]
      ]
    ]
  ]
  #site-footer()
]

#document("books/" + book.slug + ".html", title: book.title + " — Niubook")[
  #html.elem("link", attrs: (rel: "stylesheet", href: "../style.css"))
  #site-header("../index.html")
  #html.elem("div", attrs: (class: "book-layout"))[
    #html.elem("aside", attrs: (class: "sidebar"))[
      #html.elem("p", attrs: (class: "sidebar-label"))[目录]
      #outline(title: none, depth: 1)
    ]
    #html.elem("div", attrs: (class: "book-main"))[
      #html.elem("details", attrs: (class: "toc-mobile"))[
        #html.elem("summary")[目录]
        #outline(title: none, depth: 1)
      ]
      #book-head(book, book.slug + ".pdf", book.slug + ".jpg")
      #html.elem("main", attrs: (class: "page"))[
        #include "/site/books/embodied-rsi.typ"
      ]
    ]
  ]
  #site-footer()
]

#document("404.html", title: "页面不存在 — Niubook")[
  #html.elem("link", attrs: (rel: "stylesheet", href: "style.css"))
  #site-header("/niubook/index.html")
  #html.elem("main", attrs: (class: "page"))[
    #html.elem("h1")[404]
    #html.elem("p")[这一页不在书里。 #html.elem("a", attrs: (href: "/niubook/index.html"))[返回书目]]
  ]
]

#asset("style.css", read("style.css"))
