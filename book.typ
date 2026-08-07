// ── COLOURS ──────────────────────────────────────────────────
#let h-colour = rgb("#2F5D8A")
#let dark-grey = rgb("#393D47")

// ── GENERAL TEXT SETTINGS ────────────────────────────────────
#set text(
  font: "Georgia",
  size: 10.5pt,
  lang: "tr",
  hyphenate: true
)

#set par(
  justify: true,
  leading: 0.65em
)

// ── EMPHASIS STYLES ──────────────────────────────────────────
// Markdown: **kalın**
#show strong: it => text(weight: "bold")[#it.body]

// Markdown: *italik*
#show emph: it => text(style: "italic")[#it.body]

// Markdown: ***kalın italik***
#show strong.where(body: emph): it => text(
  weight: "bold", style: "italic")[#it.body.body]

// ── CITATIONS ────────────────────────────────────────────────
#show cite: it => super[#it]

// ── CURRENT CHAPTER TITLE ────────────────────────────────────
#let current-chapter() = {
  let headings = query(heading.where(level: 1))
    .filter(h => h.location().page() <= here().page())

  if headings.len() > 0 {
    headings.last().body
  } else {
    []
  }
}

// ── PAGE LAYOUT ──────────────────────────────────────────────
#set columns(gutter: 0.8cm)

#set page(
  paper: "a4",
  margin: (
    top: 2cm,
    bottom: 1.5cm,
    left: 1.5cm,
    right: 1.5cm,
  ),
  columns: 2,

  header: context [
    #align(right)[
      #set text(font: "Trebuchet MS", size: 9pt, fill: dark-grey)
      #current-chapter()
    ]
  ],

  footer: context [
    #align(center)[
      #set text(size: 9pt, fill: dark-grey)
      #counter(page).display()
    ]
  ],
)

// ── BAŞLIK STİLLERİ ──────────────────────────────────────────

#set heading(numbering: none)

#show heading.where(level: 1): it => [
  #colbreak(weak: true)

  #block(
    above: 1em,
    below: 1.5em,
    breakable: false,
  )[
    #text(
      font: "Trebuchet MS",
      size: 22pt,
      weight: "bold",
      fill: h-colour,
    )[#it.body]
  ]
]

#show heading.where(level: 2): it => block(
  above: 1.5em,
  below: 0.8em,
  breakable: false,
)[
  #text(
    font: "Trebuchet MS",
    size: 16pt,
    weight: "bold",
    fill: h-colour,
  )[#it.body]
]

#show heading.where(level: 3): it => block(
  above: 1.5em,
  below: 0.8em,
  breakable: false,
)[
  #text(
    weight: "bold",
    fill: h-colour,
  )[#it.body]
]

// ── BOOK CONTENT ─────────────────────────────────────────────
$body$

// ── BIBLIOGRAPHY ─────────────────────────────────────────────
#show bibliography: set text(size: 9pt)
