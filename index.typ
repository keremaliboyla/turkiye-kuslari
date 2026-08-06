// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}




#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "a4",
  margin: (bottom: 2.5cm,left: 3cm,right: 3cm,top: 2.5cm,),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [Türkiye Kuşlarının Doğa Tarihi],
  subtitle: [Türlerin Coğrafi Yayılışı, Üreme Biyolojisi ve Taksonomik Durumu],
  author: "Kerem Ali Boyla, Editör",
  date: "18/01/2026",
  lang: "tr",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
)


// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

#heading(level: 1, numbering: none)[Kitap Hakkında]
<kitap-hakkında>
Bu kitap, Türkiye'de gözlenen tüm yabani kuş türlerinin mevcut durumu, coğrafi yayılışı, üreme biyolojisi ve taksonomik konumuna dair kapsamlı bir değerlendirme sunmaktadır. Hedef kitlesi kuş gözlemcileri, doğa korumacıları ve bilim insanlarıdır. Bu çalışma, aynı yazarlar tarafından 2008 yılında yayımlanan #emph[The Birds of Turkey] kitabının kapsamı genişletilmiş ve içeriği güncellenmiş ve Türkçe'ye uyarlanmış halidir.

#strong[Yazarlar:] Kerem Ali Boyla, Guy M. Kirwan, Peter Castell, Barbaros Demirci, Metehan Özen, Hilary Welch, Tim Marlow

#strong[Katkı Sağlayanlar:] Güneşin Aydemir, Sancar Barış, Bahtiyar Kurt, Gernant Magnin, Richard F. Porter, Geoff Welch

#strong[Çevirmenler:] Özge Keşaplı Can, Özgür Keşaplı, Önder Cırık, Ömer Döndüren, Utku Perktaş, Kuzey Cem Kulaçoğlu, Bahtiyar Kurt (Türkiye Ornitoloji Tarihi) ve Sancar Barış (Bilgi Boşlukları)

#strong[Kapak İllüstrasyonu:] Tora Benzeyen

#strong[Telif Hakkı:] Kitap, Creative Commons Attribution 4.0 International License kapsamında lisanslanmıştır. Tüm hakları yazarlara aittir. Bu lisans, eserin kopyalanmasına, paylaşılmasına, sergilenmesine ve türetilmiş çalışmaların oluşturulmasına izin verir; ancak orijinal yazarların açıkça belirtilmesi zorunludur.

#strong[Kaynak Gösterimi:] Boyla, K.A., Kirwan, G.M., Demirci, B., Welch, H., Özen, M., Castell, P. & Marlow, T. (2025). #emph[Türkiye Kuşlarının Doğa Tarihi.] #link("https://keremaliboyla.github.io/turkiye-kuslari/")

#strong[Düzeltme ve Geri Bildirim:] Metindeki yazım hataları, eksik bilgiler veya düzeltme önerilerinizi lütfen yazarın e-posta adresine gönderin: kerem.boyla \[at\] gmail.com. Ayrıca, uzmanlar ve akademisyenler GitHub üzerinden içeriğe erişebilir ve düzeltme önerilerini doğrudan iletebilirler.

Bu kitap #emph[Quarto] yayınlama sistemi kullanılarak hazırlanmıştır.

= Ördekgiller
<ördekgiller>
== Boz Kaz
<boz-kaz>
#emph[Anser anser], Greylag Goose

#strong[#emph[Lokal olarak az sayıda ürer. Kışın göç alır ve daha geniş bir alanda yayılış gösterir.]]

Üreme döneminde az sayıda birey Göller Bölgesi, İç Anadolu ve Doğu Anadolu'daki bataklık sulakalanlarda görülür. Sultansazlığı gibi birkaç alanda eskiden yüksek sayılarda ürerken, son 50 yılda popülasyon çok ciddi oranda azalmıştır @ost1969@ost1972@ost1975@ost1978@beaman1986@kirwan2003@kirwan2006apress@kirwan2014@kirwanmartins1994@kirwanmartins2000@martins1989. Eskiden ürediği sulakalanların çoğu kurutulmuştur. Örneğin, Ereğli Sazlığı'nda Nisan 1970'te 120 yuva ve 300 birey varken Temmuz 1996'da 160 birey sayılmış, bugün ise hiçbir üreyen çift kalmamıştır.

Üreme sonrasında tüy döküm dönemi sırasında bazı sulakalanlarda kalabalık sürüler oluşur. Temmuz 1984'te Kulu Gölü'nde 800 birey, tarih belirtilmeyen bir gözlemde Sultansazlığı'nda 12.000 birey ve Eylül 2004'te Kuyucuk Gölü'nde 10.000 birey kaydedilmiştir.

Geçiş sırasında tüm bölgelerde görülen ve ekimden itibaren mart sonuna kadar kalan bir kış göçmenidir. Kışlayan sürüler genellikle kıyısal bölgelerde yoğunlaşır. Son yıllarda görülen sürüler 300 bireyden azdır. KOSKS verilerine göre eskiden daha bol bulunduğu bilinmektedir. Ülke genelinde ortalama 5000 birey, en yüksek ise 1967'de 11.200 birey olarak sayılmıştır. Alanlarda yapılan sayımlarda Kızılırmak Deltası'nda 5000 birey, Meriç Deltası'nda 4500 birey ve Hotamış Sazlığı'nda 1500 birey tespit edilmiştir.

#box(image("images/harita_Anser anser.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Göllerdeki adalarda genellikle küçük gruplar halinde ürer. \
#strong[Yuvası:] Kulu Gölü'nde gözlenen yuvası kuru toprağa kazılmış sığ bir çukurdur ve çevredeki bitki örtüsü ile küçük tüylerle astarlanmıştır. Ereğli Sazlığı'ndaki yuvası ise saz ve diğer sucul bitkilerden oluşan, su seviyesinin üstünde kalan bir yapının üzerine kurulmuştur. \
#strong[Yumurta Sayısı:] Türkiye'de yumurta sayısına ilişkin güvenilir gözlem yoktur. Yuvadan ayrılmış beş yavru, en az beş yumurta koyduğunu gösterir. Diğer ülkelerde genellikle 4-6 yumurta bırakır. \
#strong[Üreme Dönemi:] Mart sonunda yumurtlar. En erken yavrular 23 Nisan 1988'de Kulu Gölü'nde, 27 Nisan 1988'de Sultansazlığı'nda, 30 Nisan 1968'de Mogan Gölü'nde ve 30 Nisan 1973'te Ereğli Sazlıkları'nda gözlenmiştir. 20 Nisan 1996'da Marmara'da, 14 Mayıs 1969'da Karadeniz'de, 16 Mayıs 1970'te ve 24 Haziran 1983'te Doğu Anadolu'da kaydedilen yavrular geç üremeyi işaret eder.

#strong[Alttürler ve Sınıflandırma]

Ülkemizde #emph[rubrirostris] alttürü bulunur. Bu alttür turuncu gagasıyla Batı ve Orta Avrupa'da bulunan pembe gagalı #emph[anser] alttüründen ayrılır.

== Sakarca
<sakarca>
#emph[Anser albifrons], Greater White-fronted Goose

#strong[#emph[Lokal olarak bulunan ve zaman zaman kalabalık sürüler oluşturan bir kış konuğudur.]]

Ekim sonu ile nisan başı arasında lokal olarak görülen bir kış konuğudur. Genellikle ocak ve şubat aylarında daha yaygın ve yüksek sayıda olur. Soğuk geçen kışlarda Türkiye'de kışlayan birey sayısı artar. En kalabalık sürüler Meriç Nehri boyunca, Tuz Gölü çevresinde ve Konya Ovası'nda yoğunlaşır. Büyük Menderes Deltası ve Doğu Akdeniz'deki sulakalanlarda da önemli sayılarda toplanabilir. Son zamanlarda Güneydoğu Anadolu'daki baraj göllerinde küçük sürüler halinde görülmeye başlanmıştır. Nadiren yaz aylarında sulakalanlarda az sayıda birey kalabilir.

Kış ortası su kuşu sayımlarında (KOSKS) ülke genelinde en yüksek sayı 1968--69 kışında 98.600 birey olarak kaydedilmiştir. 1987'de 84.000 birey sayılmış, ancak ardından sayı ciddi biçimde düşmüştür. 1990'lı yıllarda 20.000--30.000 arasında değişen sayılar kaydedilmiş; 1993'te 11.822 @dhkd1993, 1999'da 3956 @dhkd1999 ve 2005'te 3891 birey @caglayan2005 tespit edilmiştir. 11 Şubat 2006'da Büyükçekmece'de 15.000 birey sayılmıştır ki bu, son yıllardaki en yüksek değerdir. Bu verilere göre Türkiye'de kışlayan nüfus 1970'lerdeki 100.000'ler seviyesinden 2010'larda yaklaşık 5000 bireye düşmüştür.

#box(image("images/harita_Anser albifrons.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Avrasya ve Kuzey Amerika'nın tundra bölgelerinde yuvalar.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur.

== Küçük Sakarca
<küçük-sakarca>
#emph[Anser erythropus], Lesser White-fronted Goose

#strong[#emph[Az sayıda gelen düzenli kış konuğudur.]]

Her yıl çok az sayıda kaydedilen bir kış konuğudur. Sayıları genellikle 10'dan azdır ve diğer kaz türleriyle karışık olarak görülebilir. Bugüne kadar Türkiye'ye gelen bireylerin İskandinavya'da üreyen ve Balkan ülkelerinde kışlayan göç yoluna ait olduğu düşünülmüştür. Yunanistan'da bir alanda kışlayan ve koruma çalışmaları sayesinde sayıları artan bir sürünün kış ortasında oradan kaybolması, Marmara ve Ege bölgelerinde bir kışlama alanı olabileceği ihtimalini doğurmuştur. Ancak yapılan aramalara rağmen burada düzenli kullanılan bir kışlama alanı bulunamamıştır.

Doğu Anadolu'da 20 Kasım 2004'te Haçlı Gölü'nde uydudan izlenen bir birey sinyal verince, doğuda bir kışlama alanı olasılığı gündeme gelmiştir @morozov2004. Nitekim Van Gölü ve Erçek Gölü kıyılarında sayıları 340'a ulaşan sürüler düzenli olarak tespit edilmiştir. Bugün, Türkiye'de kışlayan ana nüfusun Doğu Anadolu'da bulunduğu söylenebilir @aou2000.

2000 öncesindeki kayıtlarda; 29 Aralık 1997'de Göksu Deltası'nda bir birey @kirwan2003, 23 Ocak 1993'te yine Göksu Deltası'nda bir birey @dhkd1993, 6 Nisan 1990'da Seyfe Gölü'nde 12 birey @kirwanmartins1994, 24 Aralık 1986'da Bafa Gölü'nde bir erişkin ve iki genç birey @kasparek1988a ve 16 Şubat 1967'de Kocabaş Çayı ağzında (Çanakkale) iki birey @ost1969 kaydedilmiştir. 1945 ile 1965 arasında ve özellikle ekim ile ocak ayları arasında, çoğunluğu Büyükçekmece ve Küçükçekmece Gölleri'nden gelen 12 kayıt mevcuttur. Ancak bu gözlemler, tür teşhisini doğrulayacak belgelerden yoksundur @kumerloeve1970a.

#box(image("images/harita_Anser erythropus.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Kuzey İskandinavya'dan Doğu Sibirya'ya kadar uzanan tundra kuşağında ürer.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Tundra Kazı
<tundra-kazı>
#emph[Anser serrirostris], Tundra Bean Goose

#strong[#emph[Nadiren gelen kış konuğudur.]]

2000 yılından sonra toplam beş kez kaydedilmiştir. 26 Şubat 2013'te Yedikır Barajı'nda ve 4--21 Şubat 2015 arasında Kızılırmak Deltası'nda birer birey, 31 Ocak 2016'da Manyas Kuş Gölü'nde üç birey ve aynı alanda 2--24 Ocak 2019'da yine üç birey kaydedilmiştir. Acıgöl'de ise 24 Aralık 2023 ile 3 Şubat 2024 arasında bir birey gözlenmiştir.

#emph[Tundra Kazı], önceleri #emph[Tayga Kazı] ile beraber tek bir tür altında #emph[Tarla Kazı] olarak sınıflandırılıyordu. Dolayısıyla, taksonomik revizyonun yapıldığı tarihten önceki kayıtlarda #emph[Tarla Kazı] olarak tanımlanmıştır. 2000 yılından sonra çekilen fotoğraflarda özellikle gaga renklenmesi incelenmiş ve bu kuşların tamamı #emph[Tundra Kazı] olarak tanımlanmıştır. Fotoğrafı veya betimlemesi olmayan eski kayıtların hangi türe ait olduğu ise belirsiz kalacaktır.

#emph[Tarla Kazı] olarak tanımlanan kuşlar, Ege, Akdeniz ve İç Anadolu'daki sulakalanlarda zaman zaman yüksek sayılarda kaydedilmiştir. Mersin'de 1870'ler ve 1880'lerde toplanan bireyler @schrader1891, bilinen en eski kayıtlardandır. 1966--2000 arasında, çoğunlukla ocak--mart aylarında 15 kez kaydedilmiştir. 2 Mart 1965'te Ereğli ile Karapınar arasında 90 birey @kumerloeve1970a, 15--16 Ekim 1969'da Karamık Sazlıkları'nda 13 birey @ost1972, 30 Nisan 1988'de Seyfe Gölü'nde, 30 Ocak 1992'de Marmara Gölü'nde 61 birey, 9 Ocak 1993'te Büyükçekmece Gölü'nde 64 birey ve 24 Ocak 1993'te Göksu Deltası'nda bir birey kaydedilmiştir @dhkd1993. Türkiye'de kışlayan Sakarca sayısındaki ciddi azalma, bu tür için de geçerli olabilir.

#box(image("images/harita_Anser serrirostris.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Üreme alanı Kuzey İskandinavya'dan Doğu Sibirya'ya uzanan tundra kuşağındadır.

#strong[Alttürler ve Sınıflandırma]

Tayga Kazı, yakın zamana kadar Tarla Kazı olarak bilinen bir türden ayrılan yeni bir türdür. Beş alttüre sahip olan Tarla Kazı (#emph[Anser fabalis]), iki gruba ayrılmıştır: #emph[fabalis], #emph[johanseni] ve #emph[middendorffii] alttürleri Tayga Kazı (#emph[Anser fabalis]), #emph[serrirostris] ve #emph[rossicus] alttürleri ise Tundra Kazı (#emph[Anser serrirostris]) olarak sınıflandırılmıştır.

== Yosun Kazı
<yosun-kazı>
#emph[Branta bernicla], Brant Goose

#strong[#emph[Rastlantısal konuktur.]]

Batı Avrupa'nın Atlantik kıyılarında kışlar. Türkiye ve çevresinde rastlantısal bir konuktur. 6 Nisan 1981'de Küçük Menderes Deltası'nda iki birey gözlenmiştir @beaman1986. 3--4 Eylül 1973'te Ardeşen açıklarında, koyu karınlı #emph[bernicla] alttürüne ait iki birey kaydedilmiştir @ost1975. 1969'da Acıgöl'den gelen bir iddia ise kabul edilmemiştir @dijksen1988. 7 Şubat 1945'te Büyükçekmece'de Prenses Zeyneb Halim tarafından vurulan bireyin gövdesi korunamamıştır @kumerloeve1970a. 1889 yılı kışında İstanbul Maltepe'de düzenli, Şubat 1891'de ise Kadıköy'de büyük sürüler hâlinde görülmüştür @matheydupraz1920.

#box(image("images/harita_Branta bernicla.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Orta ve Kuzey Sibirya'nın Kutup Denizi kıyılarında yuvalar.

#strong[Alttürler ve Sınıflandırma]

Bir kayıtta kuşun alttürü #emph[bernicla] olarak tanımlanmıştır. Keza, Kuzeybatı Avrupa'da kışlayan #emph[bernicla] alttürünün Türkiye'de görülmesi olasıdır. Yunanistan'daki bir kayıt da bu alttüre aittir @handrinos1997.

== Ak Yanaklı Kaz
<ak-yanaklı-kaz>
#emph[Branta leucopsis], Barnacle Goose

#strong[#emph[Rastlantısal konuktur.]]

5 Ocak 2003'te Büyükçekmece Gölü'nde bir birey gözlenmiş ve detaylı olarak belgelenmiştir. 1946/47 kışında Sakarya Deltası'nda bir birey, 1961 sonbahar/kışında ise başka bir birey vurulmuştur. İkinci kuşun tahniti Eylül 1964'te Ankara'da bulunmuş, ancak sahibi tahniti satmaya yanaşmamıştır @kumerloeve1966d. Bu iki kaydın belgeleri yetersizdir @kumerloeve1970a.

#box(image("images/harita_Branta leucopsis.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Grönland, İzlanda, Kuzey Batı Rusya ve Baltık Denizi kıyılarında yuvalar.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Sibirya Kazı
<sibirya-kazı>
#emph[Branta ruficollis], Red-breasted Goose

#strong[#emph[Az sayıda gelen düzensiz kış konuğudur.]]

Türkiye'de düzenli kışladığı bilinen bir alan yoktur; ana kışlama alanı Romanya ve Bulgaristan'ın Karadeniz kıyısıdır. Özellikle soğuk kışlarda, bireyler veya gruplar halinde Türkiye'ye inerler. 1964 ile 2008 yılları arasında 64 kayda rastlanmıştır. Bu kayıtların 15'i Marmara'da, 12'si İç Anadolu'da, 8'i Karadeniz'de, 6'sı Akdeniz'de ve 4'ü Ege'de alınmıştır. Kayıtların çoğu aralık sonu ile şubat başı arasındadır. Çoğunlukla bir veya birkaç kuş sayılmış, ancak 5 kayıtta 40 ila 100 bireyden oluşan nispeten kalabalık sürüler de gözlenmiştir. 2001/2002 kışında Türkiye genelinde 192 birey sayılmıştır.

Ülke genelinde yaygın olarak av mağazaları ve avcılık kulüplerinde tahnit örneklerine rastlanması ve avcıların gözlem beyanları @dijksen1985, bu kuşların kayıtlardan daha yaygın olabileceğini gösterir. İç Anadolu'dan gelen eski kayıtlar, Kış Ortası Su Kuş Sayımları sırasında kalabalık kaz sürülerinin sistematik incelenmesi ile ortaya çıkmıştır. Sakarca kazı sürüleri içinde bu türün fark edilmemesi olasıdır.

1946/47 kışında Küçükçekmece'de Kosswig tarafından gözlenmiştir @kumerloeve1966d. 1947 veya 1954 yıllarında kış boyunca (27 Kasım - 6 Mart) Büyükçekmece ve Meriç Nehri civarında düzenli olarak 9 birey ve Beylik Mandra'da 2 birey kaydedilmiştir @kumerloeve1970a. 1959 yılında belirtilmemiş bir alanda İshakoğlu tarafından sekiz birey gözlenmiş ve bir birey vurulmuştur @makatsch1950. 12 Kasım 1964'te Kuyucuk Gölü'nde 400 boz kazın arasında 2 erişkin ve 1 genç birey kaydedilmiştir @kumerloeve1964a. 17 Ocak 1965 tarihinde Çekmece'de E. Hirzel tarafından 3 birey görülmüştür.

Türkiye'de açıklama gerektiren bir yaz veya üreme kaydı vardır. 5 Ağustos 1982'de Erçek Gölü'nde 14 erişkin ve 8 yavru kaydedilmiştir @kasparek1983. Bu kayıt ya hatalı bir gözlem olarak kabul edilmeli ya da avcılar tarafından yakalanıp evcilleştirilen kuşların üremesinin bir sonucu olarak yorumlanmalıdır.

#box(image("images/harita_Branta ruficollis.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Doğu Sibirya'da tundra kuşağında yuvalar.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Sessiz Kuğu
<sessiz-kuğu>
#emph[Cygnus olor], Mute Swan

#strong[#emph[Lokal olarak az sayıda yuvalar. Yaygın olarak ve nispeten çok sayıda bulunan bir kış konuğudur.]]

Üreme kayıtlarının çoğu üç alandan gelir: Gala Gölü, Gediz Deltası ve Kızılırmak Deltası. Ulusal üreme popülasyonu muhtemelen 20 çiftten daha azdır. Kızılırmak Deltası'ndan alınan ilk muhtemel üreme kaydı 1968 yılına aittir @dijksen1985.

Geçmişte, birkaç alanda yüzlerce çiftlik bir üreme nüfusu bulunuyordu. Marmara Gölü'nde 50 çift, Akşehir Gölü'nde ise 100 çift üremiştir @kumerloeve1961. Ereğli Sazlığı en çok gözlem kaydının alındığı alandır. Lenz burada 1968'de 11 yuva, 1969'da bir yuva ve 1970'te üç yuva bulmuştur. Ereğli Sazlığı'nın yok olması ayrıntılı olarak belgelenmiştir @kilic1990, bu nedenle üreyen nüfusun azalışı da gözlenmiştir. Eski üreme alanlarında yok olmasının başlıca nedeni sulakalanların kurutulmasıdır.

Kış aylarında Karadeniz, Marmara ve Ege Bölgelerinde yaygın olarak en yüksek sayılarda gözlenir. Toplam kışlama popülasyonu 1000-10000 birey arasında değişmektedir. Meriç Deltası ve Gala Gölü kışlayan nüfusun büyük kısmının toplandığı alanlardır. 1993'te 1244, 1999'da 8900 ve 2003'te 2000 birey kaydedilmiştir @dhkd1993@dhkd1999. Kışın sert geçtiği yıllarda bu sayı artmakta olup, 1999'da ülke genelinde toplamda 9088 birey kaydedilmiştir.

#box(image("images/harita_Cygnus olor.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Geniş sazlık alanlar, su aynası bulunan büyük göller ve bataklıklarda yuvalar. \
#strong[Yuvası:] Türkiye'de henüz bir yuva tarifi yapılmamıştır. Diğer bölgelerde yuva su kıyısındaki zemin üzerinde, küçük bir adacıkta ya da sığ sudaki sazların üstüne kurulur. Yuva, saz ve diğer sucul bitkilerden oluşan büyük bir yığının ortasında çukur şekilli bir yapıdır. \
#strong[Yumurta Sayısı:] Türkiye'deki yumurta sayısı bilinmez. Ancak Türkiye dışındaki yuvalarda genellikle 5-7 yumurta bıraktığı bilinmektedir. \
#strong[Üreme Dönemi:] Nisan başında yumurtlamaya başlar, yavrular ise mayıs ve temmuz ayları arasında görülür. #strong[EGE:] 13 Mayıs 1899'da İzmir'de bir sazlıkta yuvalayan bir çift kaydedilmiştir @selous1900. #strong[İÇA:] 6 Temmuz 1976'da Ereğli Sazlığı'nda bir çift ve 4-5 genç yavru, 17 Temmuz 1982'de bir çift ve dört genç, 16 Mayıs 1987'de ise yumurtadan yeni çıkmış yavrular gözlenmiştir.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Küçük Kuğu
<küçük-kuğu>
#emph[Cygnus columbianus], Tundra Swan

#strong[#emph[Lokal olarak ve az sayıda bulunan bir kış konuğudur.]]

1993 yılına kadar nadir bir kış konuğu olduğu düşünülmüştür. Ancak daha sonra, önce Burdur Gölü ve Göller Bölgesi'nde, ardından Meriç Deltası'nda düzenli olarak bulunduğu tespit edilmiştir. Meriç Deltası'nda, karışık ve kalabalık kuğu sürüleri içinde sayıları 1000'e kadar ulaşabilir. İç Anadolu ve Göller Bölgesi'nde ise küçük gruplar halinde bulunur. Genellikle kasım ve nisan ayları arasında gözlenir.

Türkiye'de kışlayan kuşların üreme alanları ve göç koridorları tespit edilmiştir @article. 2015-2017 yıllarında GPS ve GMS vericileriyle yapılan çalışmada, yuvalama alanlarının Yamalo-Nenets Özerk Bölgesi'ndeki Yamal olduğu belirlenmiştir. Göç sırasında Ob Koyu, Turgay Ovaları, Kuzey Hazar Kıyıları ve Azov Denizi gibi durak alanları üzerinden göç ettikleri ortaya çıkmıştır.

#box(image("images/harita_Cygnus columbianus.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Sibirya Tundra kuşağında yuvalar.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de Eski Dünya'da yaşayan #emph[bewickii] alttürü bulunur; bu alttür, gaga kökü ve yüz derisinin sarı olmasıyla tanınır. Amerika'da yaşayan #emph[columbianus] alttürü ise siyah gaga ve siyah yüz derisi ile kolaylıkla ayırt edilebilir.

== Ötücü Kuğu
<ötücü-kuğu>
#emph[Cygnus cygnus], Whooper Swan

#strong[#emph[Yaygın olarak ve az sayıda görülen bir kış konuğudur.]]

Ekim sonu ile nisan başı arasında yaygın olarak az sayıda görülen bir kış konuğudur. Ocak ve şubat aylarında en yüksek sayıya ulaşır. Trakya'da Meriç Deltası hem Türkiye'deki ana toplama bölgesidir, üstelik türün Balkanlar'daki en önemli kışlama alanıdır. 25 Ocak 1998'de Meriç Deltası'nda 1200 birey kaydedilmiş, bu Türkiye'deki en yüksek sayıdır @boyla1998a. Türkiye'ye gelen kuşlar, Ukrayna ve Kırım ile Batı Karadeniz Bölgesi arasındaki deniz üzeri göç rotasını kullanır @brazil2003. Doğuda, 30 Ekim 1995'te Sodalı Gölü'nde 164 birey @adizel1998, 1992'de Diyarbakır Kabaklı Barajı'nda 133 birey kaydedilmiştir @dhkd1992.

#box(image("images/harita_Cygnus cygnus.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Üreme bölgesi Kuzey Avrasya'dadır

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Nil Kazı
<nil-kazı>
#emph[Alopochen aegyptiaca], Egyptian Goose

#strong[#emph[Durumu belirsizdir. Çoğunlukla egzotik tür kategorisinde değerlendirilir.]]

28 Nisan 1986'da Kulu Gölü'nde gözlenen bireyin doğal ve rastlantısal bir konuk olduğu düşünülmüştür. 11 Nisan 1911'de Urfa'nın güneyinde iki birey gördüğünü söyleyen Weigold'un (1912-13) kaydı kabul edilmemiştir @kasparek1992a.

İstanbul ve Ankara'da gözlenen kuşların esaretten kaçmış olabileceği düşünülmektedir. 6-13 Temmuz 2002'de Ankara'daki bir parkta bir çift fotoğraflanmış; 31 Mart 2012'de İstanbul Riva'da, 13 Mart 2012'de Ankara Hacettepe Kampüsü'nde, 5-24 Kasım 2013'de Etimesgut'ta ve 25 Mayıs-13 Haziran 2014'te Eymir Gölü'nde birer birey gözlenmiştir.

1906 ve 1928 yılları arasında Kıbrıs'ta nadir görülen bir kış göçmeni olarak kaydedilmiş ve 1958, 1962 ve 1989 yıllarında bireyler gözlenmiştir. Eskiden Suriye ve Filistin'de ürediği düşünülmüş @vaurie1965, ancak sonrasında Suriye'de hiçbir güvenilir kaydın olmadığına karar verilmiştir @kumerloeve1967a@baumgart1995.

#box(image("images/harita_Alopochen aegyptiaca.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Üreme alanları çoğunlukla Sahra Altı Afrika'dadır.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Suna
<suna>
#emph[Tadorna tadorna], Common Shelduck

#strong[#emph[Lokal olarak az sayıda ürer. Aynı zamanda lokal olarak çok sayıda bulunabilen bir kış konuğudur.]]

Ege Bölgesi, Göller Bölgesi, İç ve Doğu Anadolu'da geniş ve tuzlu sulakalanlarda ürer. Başlıca üreme alanları Gediz Deltası, Bolluk Gölü, Kulu Gölü, Tuz Gölü ve Van Gölü çevresidir. Gediz Deltası'nda 1996 yılında üreyen popülasyonun 8 çift olduğu tahmin edilmiştir @eken1997a. 24 Haziran 1992'de Bolluk Gölü'ndeki bir adada 12 yuva tespit edilmiştir.

Üreme sonrası tüy değiştiren kuşlar, ağustos ile ekim ayları arasında toplanır. Bu dönemde Erçek Gölü'nde 2500 birey, Kulu Gölü'nde ise 700 birey sayılmıştır.

Kışlayan toplam nüfus genellikle 1000-5000 birey arasında değişir. Ana kışlama alanı olan Yumurtalık Lagünü'nde, 16 Şubat 2006'da 5390 birey kaydedilmiştir. Acıgöl'de ise 1969-70 yıllarında 3450 birey, 1968-69 yıllarında 4900 birey, 2004 yılında 1802 birey ve 2005 yılında 2928 birey sayılmıştır. Diğer alanlarda daha küçük gruplar halinde kışlar.

#box(image("images/harita_Tadorna tadorna.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Geniş, sığ ve tuzlu sulakalanlarda, adalar, sedde duvarları ve çalı altlarında yuvalar. \
#strong[Yuvası:] Avrupa'da yuvaların çoğu tavşan oyuklarında, tünelin 1-2 metre içinde bulunur. Ancak Türkiye'deki yuvalar genellikle yerdedir. Bolluk Gölü'ndeki yuvaların bazıları tamamen açıkta, bazıları ise kısmen ya da tamamen çalı altında, bir tanesi ise doğal bir oyuğun içinde bulunmuştur. \
#strong[Yumurta Sayısı:] Genellikle 6-9 yumurta bıraktığı gözlenmiştir. Bolluk Gölü'ndeki yuvalarda gözlenen 10-18 yumurtanın, birden fazla dişi tarafından bırakılmış olması muhtemeldir. \
#strong[Üreme Dönemi:] Gediz Deltası'nda haziran başında yavrular gözlenmiştir @eken1997a. İç Anadolu'da nisan sonu ile haziran başında, Doğu Anadolu'da ise haziran ortasında yumurtladığı düşünülmektedir.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Angıt
<angıt>
#emph[Tadorna ferruginea], Ruddy Shelduck

#strong[#emph[Yaygın ve çok sayıda bulunan yerli türdür. Kışın göç alır, sayıları artar.]]

Üremek için genellikle yüksek kesimlerdeki küçük gölcükler, baraj gölleri, ıslak çayırlar ve dereleri tercih eder; birçok ördek ve kaz türünün aksine büyük sulakalanlarda yuvalamaz. İlk tahminlere göre üreyen popülasyonun 4000 ile 8000 çift arasında olduğu öne sürülmüştür @tucker1994. Ancak, kış ortası su kuşu sayımlarına dayanarak popülasyonun azaldığı düşünülmüş ve üreyen popülasyonun 1200-5100 çift olduğu tahmin edilmiştir @emirogullari_inprep.

Temmuz ve eylül ayları arasında tüy değişimi için bazı sulakalanlarda büyük sürüler halinde toplanır. Erçek Gölü'nde 20.000, Sultan Sazlığı'nda 11.000, Kulu Gölü'nde 10.000 ve Eylül 1936'da, bugün kurutulmuş olan Emir Gölü'nde 10.000-15.000 birey sayılmıştır. Kış öncesinde Kasım 2004'te Sarıyar Barajı'nda 8.000 birey ve Kuyucuk Gölü'nde 6.000 birey kaydedilmiştir.

Kış aylarında daha yaygın olarak görülür. En yüksek kış sayımında Türkiye genelinde 10.115 birey kaydedilmiş olup @caglayan2005, genellikle 4000-4500 birey sayılmıştır. Ocak-Şubat 1993'te sadece 711 birey, 18 Ocak 2004'te Sarıyar Barajı'nda 5636 birey ve 18 Şubat 2006'da 7641 birey kaydedilmiştir. İç Anadolu'da üreme sonrası toplanan sürülerde bir azalma gözlenirken, baraj göllerinin sayısında artış olmuştur. Kış sayımı toplamlarının yaz sonu toplamlarından düşük olması, türün dağınık şekilde kışladığını veya kış aylarında güneye göç ettiğini göstermektedir. Toplam kışlayan nüfusun 2600 ile 28.500 birey arasında değiştiği tahmin edilmektedir @emirogullari_inprep.

#box(image("images/harita_Tadorna ferruginea.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Genellikle göl kenarındaki sarp kayalıklarda, tepelerde ve yamaçlardaki çukur ve çatlaklarda, açık alanlarda yuvalar. Sıkça kayalıklarda yuva yaptığı gözlenmiştir. Beyşehir Gölü'ndeki bir adada, kayaların ve harabelerin taşları arasında ürediği kaydedilmiştir. 22-24 Mayıs 1998'de Ereğli yakınlarındaki bir kayalıkta, muhtemelen eski bir Kızıl Şahin yuvasında kuluçkaya yattığı gözlenmiştir. \
#strong[Yuvası:] Türkiye'de yuvası bitki artıkları, hav tüyleri ve bazı diğer tüylerle kaplanmış bir oyuk şeklindedir. 30 Nisan 2003'te Akköy yakınlarındaki dik bir yamaca giren bir dişi, muhtemelen bir tavşan yuvası olan bir oyuğa girerken gözlenmiş, ancak oyuğun derin olması nedeniyle yuva incelenememiştir. \
#strong[Yumurta Sayısı:] Genellikle 8-12 yumurta bıraktığı kaydedilmiştir. \
#strong[Üreme Dönemi:] Akdeniz ve Ege bölgelerinde mart sonu yumurtlama başlar. Diğer bölgelerde kuluçka nisan ve mayıs aylarında gerçekleşir.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Boz Ördek
<boz-ördek>
#emph[Mareca strepera], Gadwall

#strong[Lokal olarak birkaç alanda yuvalar. Yaygın olarak nispeten az sayılarda görülen bir kış konuğudur.]

Kızılırmak Deltası, bu türün Türkiye'deki en önemli üreme alanıdır ve yaklaşık 200 çift burada ürer. Türkiye'de toplam üreyen popülasyonun 500 ile 5000 çift arasında olduğu düşünülmüştür @tucker1994. Ancak, günümüzde bu sayının azaldığı açıktır.

İç Anadolu'daki ilkbahar göçü marttan nisan başına kadar belirgin bir şekilde gözlenir. Akdeniz'deki kıyısal sulakalanlarda ise nadiren 1000'den fazla birey kaydedilir. Kış ortası sayımlarda 1967'de Manyas Gölü'nde 5000, 1969'da Akşehir Gölü'nde 7500 ve 1971'de Hotamış Sazlığı'nda 2490 birey sayılmıştır. 1967-1973 yılları arasında ülke genelinde çoğunlukla 3000'den fazla birey kaydedilirken, 1986-2005 yılları arasında bu sayı 1000-1500 seviyelerine düşmüştür. Son yıllarda ise yeniden artış göstermiş ve 2020 kışında Kızılırmak Deltası'nda 10.000'den fazla birey sayılmıştır.

#box(image("images/harita_Mareca strepera.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Göl kıyılarında ve adalarındaki yoğun bitki örtüsü, sazlıklar ve sık bitkilerle kaplı taşkın alanlarda yuvalar. Kızılırmak Deltası, Karamık Gölü, Kulu Gölü, Bolluk Gölü, Mogan Gölü, Ahlat Sazlıkları, Haçlı Gölü ve Van Gölü'nde yuvaladığı gözlenmiştir. \
#strong[Yuvası:] Yuva, yerde bir çukura kurulur ve bitkisel malzeme ile dişinin tüyleriyle kaplanır. \
#strong[Yumurta Sayısı:] Türkiye'deki yuvalarda yumurta sayısı 6-15 arasında değişir. İç Anadolu'da 7-15 yumurtalı yuvalar gözlenmiş ve bu yuvaların bir kısmında 1 ila 6 yumurtanın başka ördek türlerine ait olduğu tespit edilmiştir. Kulu Gölü'ndeki yuvalarda 6 Mayıs 1972'de 3-11 yumurta ve 14 Temmuz 1971'de 7 yumurta sayılmıştır @kasparek1987a. 17 Mayıs 2004'te Bolluk Gölü'ndeki bir yuvada 8 yumurta bulunmuştur. \
#strong[Üreme Dönemi:] Kızılırmak Deltası'nda nisan başında yumurtlamaya başlar @hustings1994. İç Anadolu'da nisan sonu ile temmuz arasında, Doğu Anadolu'da ise haziran ile eylül arasında yavrulara rastlanmıştır.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttür görülür. Tür eskiden #emph[Anas] cinsi altında sınıflandırılıyordu.

== Fiyu
<fiyu>
#emph[Mareca penelope], Eurasian Wigeon

#strong[#emph[Yaygın olarak çok sayıda bulunan kış konuğu ve geçit türüdür.]]

Ege, Akdeniz ve İç Anadolu'nun sulakalanlarında kalabalık sürüler halinde kışlar. 1960'lı ve 1970'li yıllarda düzenli olarak ortalama 150.000 birey sayılmıştır. En yüksek sayılar 1968'de 208.600, 1969'da ise 458.800 birey olarak kaydedilmiştir. Ancak günümüze gelindiğinde ciddi bir düşüş yaşanmış, 1986 ile 2005 yılları arasındaki düzenli sayımlarda yalnızca dört yıl 40.000'den fazla birey kaydedilebilmiştir. Genellikle eylül sonunda gelir ve nisan sonuna kadar kalır.

İç Anadolu'da mart sonu ve nisan başı arasında yüksek sayılarda göç eder. Bazı göçmen bireyler mayıs sonuna kadar bölgede kalır. Nadiren de olsa, İç ve Doğu Anadolu'da üremeden yazı geçiren bireyler gözlenebilir.

#box(image("images/harita_Mareca penelope.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Kuzey Avrupa'da yuvalar.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür. Eskiden #emph[Anas] cinsi altında sınıflandırılırdı.

== Yeşilbaş
<yeşilbaş>
#emph[Anas platyrhynchos], Mallard

#strong[#emph[Yaygın olarak üreyen yerli bir türdür. Kışın göç alır, yüksek sayılara ulaşabilir.]]

Uygun yaşam alanlarının bulunduğu bölgelerde az sayıda yuvalar. En yaygın olarak İç Anadolu Bölgesi'ndeki sulakalanlarda görülür, diğer bölgelerde ise oldukça lokal bir dağılım gösterir. En yüksek yuvalama sayısı, 400-600 çiftin kaydedildiği Kızılırmak Deltası'nda olmuştur @hustings1994.

Sonbaharda göç alır ve popülasyonu artar. Kışlayan gruplar nisan başına kadar bölgede kalır. En yüksek sayılarda Karadeniz, Marmara ve Ege bölgelerinde kaydedilirken, Akdeniz ve İç Anadolu'da nispeten az sayıda, Güneydoğu Anadolu ve Doğu Anadolu'da ise çok daha az sayıda bulunur. 2000 ve 2020 yılları arasında kışlayan nüfus ortalama 20.000 birey civarındayken, kışın sert geçtiği 2005 yılında Türkiye genelinde toplam 106.140 birey ve Kızılırmak Deltası'nda 50.000 birey sayılmıştır.

1960'lı ve 1970'li yıllarda kışlayan popülasyonun 100.000'ler seviyesinde olduğu bildirilmiştir. 1967 yılında Kızılırmak ve Yeşilırmak Deltası'nda yaklaşık 52.000, Büyük Menderes Deltası'nda 42.000; 1968 yılında Manyas ve Uluabat Gölleri'nde 42.000; 1969 yılında Büyük Menderes Deltası'nda 80.000, Akyatan Lagünü'nde 40.000 ve Amik Gölü'nde 30.000; 1970 yılında ise Meriç Deltası'nda 34.500 ve Sultansazlığı'nda 30.000 birey kaydedilmiştir.

#box(image("images/harita_Anas platyrhynchos.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Göl ve nehir adalarında, sazlıklarda veya göl, sazlık ve subasar çayırların kıyılarındaki sık bitki örtüsü içinde yuvalar. \
#strong[Yuvası:] Yuvasını genellikle bitki örtüsünün altına, topraktaki bir oyuğa yapar. Diğer bölgelerde ağaç kovuklarına veya karga gibi kuşların ağaçlardaki eski yuvalarına yuvaladığı bilinir; ancak Türkiye'de bu tür yuvalara henüz rastlanmamıştır. \
#strong[Yumurta Sayısı:] Genellikle 5-9 yumurta bırakır, ancak yumurta sayısı 2-14 arasında değişebilir. Bir yuvadaki yumurtaların 14'ten fazla olması, birden fazla dişinin aynı yuvaya yumurtladığını gösterir. \
#strong[Üreme Dönemi:] Kıyı bölgelerinde marttan itibaren, diğer bölgelerde ise nisan veya mayısta yumurtlar. Yavrular mayıs başından temmuz sonuna kadar görülebilir. #strong[MAR:] 18 Nisan 1993'te Kocaçay Deltası'nda yavrularıyla gözlenen bir dişi, en erken üreme kaydıdır @ertan1996. #strong[KAR:] 19-20 Mayıs 1992'de Yeniçağa Gölü'nde yuvalarda hem yumurta hem yavrular gözlenmiştir. 5 Mayıs 1992'de Kızılırmak Deltası'nda sezonun ilk yavruları görülmüştür @hustings1994. 16 Mayıs 1967'de Manyas Gölü'nde dokuz yumurtalı bir yuva kaydedilmiştir. 20 Haziran 1973'te Trakya'da altı yavrulu bir dişi gözlenmiştir. #strong[İÇA:] 1971'de Yarma'daki birçok yuvada diğer türlerin yumurtalarına rastlanmıştır; örneğin, bir yuvada 17 Yeşilbaş, üç Boz Ördek ve üç Macar Ördeği yumurtası tanınmıştır. 13-15 Temmuz 1971'de Kulu Gölü'nde sekiz yuva incelenmiş ve yuvalarda 2-12 yumurta bulunmuştur @kasparek1987a. Başka bir tarihte, mayıs ve haziran aylarında yumurtalı yuvalar ve mayıs ortasından itibaren yavrular gözlenmiştir. #strong[DOA:] En erken kayıt, 14 Haziran 1968'de Erçek Gölü'nde kaydedilen yavrulardır. Aynı yerde 28 Haziran 1968'de beş ve sekiz yumurtalı iki yuva bulunmuş, 9 Haziran 2001'de Balık Gölü'nde iki yumurtalı yuva kaydedilmiştir @kasparek1983.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur.

== Kaşıkgaga
<kaşıkgaga>
#emph[Spatula clypeata], Northern Shoveler

#strong[#emph[Lokal olarak az sayıda yuvalar. Aynı zamanda yaygın olarak çok sayıda bulunan bir geçit türü ve kış konuğudur.]]

İç Anadolu ve Doğu Anadolu'daki birkaç büyük sulakalan ile Kızılırmak Deltası'nda yuvalar @boyla2018. 1970'lerde Kulu Gölü ve Kızılırmak Deltası bilinen üreme alanlarıdır.

Tüm bölgelerde yaygın olarak kaydedilen bir geçit türüdür. Göçmen gruplar, ilkbaharda mart başından nisan sonuna kadar, sonbaharda ise eylül ortasından kasım başına kadar zaman zaman yüksek sayılarda görülür. Eylül ayında Kulu Gölü'nde 7000, Sultansazlığı'nda 9000 ve mart sonunda Kızılırmak Deltası'nda 4500 birey sayılmıştır.

Ülkenin batı ve orta bölgelerinde kışlar. 2000 ile 2020 yılları arasında ülke çapında kışlayan kuş sayısı genellikle 5000 bireyin altında kalmıştır; ancak kışın soğuk geçtiği 2005 yılında 13.576 birey sayılmıştır. 1990'lı yıllarda daha yüksek sayılar kaydedilirdi; örneğin, 1993'te toplam 7898 birey, 1999'da ise 13.114 birey kaydedilmiştir. Daha önceki yıllarda yapılan sayımlarda; 1967'de Büyük Menderes Deltası'nda 23.000, Kızılırmak Deltası'nda 8000 birey ve 1993'te 4564 birey sayılmıştır. 1967-1973 yılları arasında İç Anadolu'daki alanlarda 3000'den fazla bireyden oluşan sürüler olağandı.

#box(image("images/harita_Spatula clypeata.png"))

#strong[Üreme]

#strong[Yuvalama alanı:] Büyük sulakalanlarda yuvalar. \
#strong[Yuvası:] Kulu Gölü'nde bir adadaki seyrek bitki örtüsü içinde yuvalamıştır. Yuvasını çıplak zeminde sığ bir oyuk açarak yapar ve içine ot, bitki gövdeleri ve tüylerini karıştırarak döşer. \
#strong[Yumurta sayısı:] 8-10 yumurta bıraktığı kaydedilmiştir. \
#strong[Üreme Dönemi:] Türkiye'deki üreme sezonu hakkında yeterli veri bulunmamaktadır; diğer ülkelerde ise üreme sezonu genellikle nisan başı ile mayıs sonu arasındadır. #strong[KAR:] 6-7 Temmuz 1972'de Kızılırmak Deltası'nda dört ve beş yavrulu iki dişi kaydedilmiştir @dijksen1985. 1992 yılında üreme kanıtlanamamış ve popülasyonun 0-1 çift olduğu belirtilmiştir @hustings1994. 1971 yılı Temmuz ortasında kaydedilen yumurtalı yuvalar, başarısız bir üremenin ardından gerçekleşen ikinci bir üreme denemesi olarak değerlendirilmiştir. #strong[İÇA:] 14-15 Temmuz 1971'de Kulu Gölü'ndeki bir adada sekiz ve on yumurtalı iki yuva tespit edilmiştir. 5-6 Ağustos 1972'de iki ve dört yavrulu iki yavru grubu gözlenmiştir @kasparek1987a. 31 Mayıs 1987'de Kulu Gölü'nde yavrular gözlenmiş, 19 Haziran 1992'de dokuz yumurtalı bir yuva bulunmuştur. Haziran 1977'de Eşmekaya'da beş yavrusuyla birlikte bir dişi gözlenmiştir @schubert1979. \
#strong[Doğu Anadolu:] 29 Mayıs 1969'da Van Gölü'nde kur davranışı gözlenmiştir.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Kılkuyruk
<kılkuyruk>
#emph[Anas acuta], Northern Pintail

#strong[Nispeten yaygın olarak bulunan bir geçit türü ve kış konuğudur. Nadiren yuvalar.]

Son yıllarda 1998 ve 1999'da, tek bir alanda, Girdev Gölü'nde üremiştir. İlkbaharda ve yazın İç Anadolu'da birçok erişkin kaydı olsa da, kanıtlanmış üreme kayıtları az sayıdadır. Üreyen popülasyonun 500 ile 1000 çift olması iddiası tamamen geçersizdir @tucker1994.

Genellikle eylül ortasından nisan başına kadar batı ve orta bölgelerde görülür.

Ülke genelinde kışlayan nüfus 10.000 bireyden azdır. 1986'da toplam 25.700 birey, 1992'de 11.070 birey ve 1999'da 13.573 birey kışlamıştır. Kışlama popülasyonunda çarpıcı bir azalma belgelenmiştir. 60'li yıllarda düzenli olarak 100.000'in üzerinde sayılırdı. Örneğin, 1967'de Büyük Menderes Deltası'nda 60.000 birey, Emir Gölü'nde 70.000 birey, 1969'da Akyatan Gölü'nde 100.000 birey ve Gâvur Gölü'nde 50.000 birey kaydedilmiştir. Bilhassa ılıman geçen kışlarda daha yüksek sayılarda kaydedilebilir. Eski tarihlerde bazı alanlardaki sayımların sonuçlarının güvenilirliği sorgulanabilir, örneğin, 1970'te Sultansazlığı'ndaki sayılan 160.000 birey muhtemelen abartılı bir tahmindir. Bu ve diğer ördek türlerinin önemli sayılarda kışladığı birkaç sulakalan kısmen ya da tamamen kurutulmuş durumdadır. Diğer yandan son yıllarda oluşan baraj göllerinde kışlamaya başlamıştır.

#box(image("images/harita_Anas acuta.png"))

#strong[Üreme]

#strong[Yuvalama alanı:] Büyük göllerde ve sulakalanlarda yuvalar. \
#strong[Yuvası:] Kulu Gölü'ndeki büyük adada kıyı vejetasyonu içinde yuvalamıştır. Yerdeki bir delikte yaptığı yuvasını bitkisel malzemeler, hav tüyleri ve kontür tüyleri ile kaplanmıştır. \
#strong[Yumurta sayısı:] 6-10 yumurta koyduğu kaydedilmiştir. \
#strong[Üreme dönemi:] Görünüşe göre mayıs ayında yumurtlar. #strong[KAR:] Kızılırmak Deltası'nda üreme davranışları gözlenmiş, ürediği kesinleşmemiştir @hustings1994. #strong[AKD:] Haziran 1998 ve 1999'da Girdev Gölü'nde yavrular gözlenmiştir. #strong[İÇA:] 22 Mayıs 1992'de Kulu Gölü'nde yedi ve on yumurtalı iki yuva, 19 Haziran 1992'de 6 ila 9 yumurtalı beş yuva bulunmuştur. 24 Haziran 1992'de Bolluk Gölü'ndeki bir çalının altına gizlenen yuvada 11 yumurta sayılmıştır.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur.

== Çıkrıkçın
<çıkrıkçın>
#emph[Spatula querquedula], Garganey

#strong[Yaygın olarak az sayıda üreyen bir yaz göçmenidir. Bunun yanında göç döneminde daha yaygın ve çok sayıdadır. Nadiren kışlar.]

Ördeklerin arasında esasen yaz göçmen olan tek türdür. Şubat ortasından itibaren görülmeye başlar, ekim sonuna kadar kalır. Leylekle beraber en erken gelen göçmen kuşlardandır. Sazlık sulakalanları tercih eder, en yoğun ürediği alanlar İç ve Doğu Anadolu'dadır. Güneydoğu Anadolu'da iki alanda üremesi olasıdır.

İlkbahar ve sonbahar boyunca Türkiye'nin tüm bölgelerinde yüzlerce, hatta binlerce birey sürüler halinde gözlenebilir. İlkbahar geçişi şubat sonundan mayıs sonuna kadar devam eder. Sonbahar geçişinde ise ağustos sonu ile eylül başı arasında Karadeniz kıyıları boyunca göçmen sürülere rastlanabilir.

Nadiren Marmara, Ege ve Akdeniz'de az sayıda kışlar. Olağandışı yumuşak geçen 1968-69 kışında Göksu Deltası'nda 3000 birey ve Gâvur Gölü'nde 5000 birey sayılmıştır. Güncel tarihlerde; Ocak 2002'de Güllük Deltası'nda 65 birey, Şubat 2002'de Bafa Gölü'nde 58 birey, Aralık 2002'de Çukurova'da 89 birey, 4 Aralık 2010'de Karkamış Barajı'nda iki birey kışlamıştır.

#box(image("images/harita_Spatula querquedula.png"))

#strong[Üreme]

#strong[Yuvalama alanı:] Sazlık sulakalanlarda yuvalar. \
#strong[Yuvası:] Göl kenarlarındaki ıslak çayırlar, bataklıklar ve sazlıklarda, ikisinin bir arada olduğu alanlarda ve göl kenarındaki vejetasyonun içinde ürer. \
#strong[Yumurta sayısı:] Türkiye'den veri yoktur, diğer yerlerde olağan yumurta sayısı 8-11'dir. \
#strong[Üreme dönemi:] Nisan ortasından itibaren ürer. Yavrular temmuza kadar görülebilir. #strong[KAR:] 19 Mayıs 1992'de Yeniçağa Gölü'nde yeni bozulmuş ancak yumurtaların taze olduğu açıkça anlaşılan iki yuva, 6 Mayıs 1993'te yakınlardaki ıslak bir çayırlıkta bir yuva bulunmuştur. 13 Mayıs 1986'da Abant Gölü'nde 17 yavru ve bir dişi gözlenmiş, yumurtlama tarihinin nisan ortası civarında olduğunu hesaplanmıştır. 2 Ağustos 1971'de Kızılırmak Deltası'nda bir çift ve yedi yavru kaydedilmiştir. #strong[İÇA:] 10-15 Mayıs 1991'de Hotamış Sazlığı'nda yavrulu birkaç çift gözlenmiş @kirwan1993a, 27 Temmuz 1971'de Kulu Gölü'nde büyük yavruları olan altı çift kaydedilmiş, Haziran ve Temmuz 1968'de Mogan Gölü'nde 1-2 kuluçka gözlenmiş, 27 Temmuz 1971'de Yarma'da büyük yavruları olan en az dört çift tespit edilmiştir.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Çamurcun
<çamurcun>
#emph[Anas crecca], Eurasian Teal

#strong[#emph[Lokal olarak az sayıda ürer. Bunun yanında yaygın olarak ve çok sayıda bulunan kış konuğudur.]]

İç Anadolu, Doğu Anadolu ve Kızılırmak Deltası'nda yuvalar. Kızılırmak Deltası'nda 1992'de 15-20 çift üremiştir @hustings1994, Doğu Anadolu'dan teyit edilmiş üreme kaydı ise çok azdır.

Geçiş sırasında eylül başından nisan başına kadar ülkenin batı ve orta bölgelerinde yaygın olarak çok sayıda görülebilir. Marmara ve Karadeniz bölgelerinde ara sıra yüksek sayılarda kaydedilebilir.

Kışın hem iç bölgelerde hem de kıyısal sulakalanlarda yüksek sayıda bulunur. Ülke çapında kışlayan nüfus 100.000 birey seviyesindedir. Son yıllarda kışlayan nüfusta düşüşler yaşanmış, örneğin 1988'de 21.000 birey ve 1989'da 13.400 birey sayılmıştır. Bu düşüş, aslında diğer yüzey ördeklerinde olduğu gibi 1960'lardan beri süre gelmektedir. 1968-69'da toplam 270.400 birey ve 1969-70'te 326.700 birey sayılmıştır. Son sayımda sadece Sultansazlığı'nda 200.000 birey gözlenmiştir. Alanda sayılan ancak türü tespit edilemeyen 400.000 ördeğin de çamurcun olabileceği düşünülürse, alandaki kışlayan çamurcun sayısı 600.000 birey olabilir.

#box(image("images/harita_Anas crecca.png"))

#strong[Üreme]

#strong[Yuvalama alanı:] Göllerde ve sazlıklarda ürer. \
#strong[Yuvası:] Yuva ve yumurta sayısı Türkiye'den bilinmez. Diğer yerlerde yuvasını yerdeki bir oyuğa yapar ve genellikle yapraklar, bitkisel malzemeler, hav tüyleri ve kontur tüyleriyle kaplar. Sulakalanlarda yüksek otların üzerine yuvalar, nadiren sudan uzağa da yuva yapabilir. \
#strong[Yumurta sayısı:] Türkiye'den veri yoktur, ancak diğer yerlerde olağan yumurta sayısı 8-12'dir. \
#strong[Üreme dönemi:] Nisan ortasından itibaren ürer, yavrular temmuza kadar görülebilir. #strong[KAR:] 29 Mayıs 1979'da Kızılırmak Deltası'nda içinde yumurta olan bir yuva bulunmuş, 28 Temmuz 1971'de dokuz yavrulu bir dişi ve 6 Ağustos 1971'de beş yavrulu bir dişi gözlenmiştir @dijksen1985. 1992'de popülasyonun 15-20 çift olduğu belirlenmiş, 5 Mayıs'ta dikkati başka yere çekme davranışı gözlenmiş ancak hiçbir yuva bulunamamıştır @hustings1994. #strong[İÇA:] 14 Mayıs 1991'de Hotamış Sazlığı'nda yavrularıyla birlikte birkaç erişkin gözlenmiş, bu da yumurtaların en geç nisan ortasında koyulmuş olduğunu göstermiştir @kirwan1993a. 5-6 Ağustos 1972'de Kulu Gölü'nde iki dişinin 7 ve 10 yavrusu gözlenmiştir @kasparek1987a. #strong[DOA:] 24 Haziran 1983'te Haçlı Gölü'nde tek yavrulu bir dişi kaydedilmiştir.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur.

== Yaz Ördeği
<yaz-ördeği>
#emph[Marmaronetta angustirostris], Marbled Duck

#strong[#emph[Türkiye'de üreyen nüfus yok olmuştur.]]

Göksu Deltası'nda üreyen popülasyonun 2013 yılından sonra yok olmasıyla, üreyen tür olarak Türkiye'deki soyunun tükendiği söylenebilir. Tek tük Doğu Akdeniz, Güneydoğu ve Doğu Anadolu'da görülebilir. Marmara, Ege ve Karadeniz bölgelerinde eski tarihli kayıtları vardır. En yakın üreme alanı Irak'taki Mezopotamya Bataklıkları'dır.

Mart başından ekim başına kadar kaydedilen bir yaz konuğu idi. Göksu Deltası'ndaki üreyen popülasyon, 1989 ile 2013 arasında adım adım azalmıştır. 1989 ve 1991'de yaklaşık 50 çift tespit edilmiş, 2000'li yıllarda bu sayı 10 çifte düşmüş, 2010 ile 2013 arasında sadece 1 ila 2 çift kalmış ve 2014 yılından itibaren alanda görülmemeye başlamıştır. Bu nedenle Türkiye'de üreyen nüfusunun yok olduğu kabul edilmiş @boyla2018 ve Yaz Ördeği, Yılanboyun'dan sonra Türkiye'de soyu tükendiği belgelenen ilk kuş türü olmuştur.

1987 yılında Çukurova'da, bugün yok edilmiş olan Dipsiz Gölü'nde 32 çift tespit edilmiştir. İç Anadolu'da Ereğli Sazlığı'nda muhtemelen 1-4 çift, Hotamış Sazlığı'nda 10-15 çift ve Sultansazlığı'nda 1-4 çift üremiştir. Van Gölü havzasında ise Erciş Gölü ve Van Sazlığı'nda az sayıda ürediği teyit edilmiş, bunun yanında Ağrı çevresi, Ahlat Sazlıkları, Bendimahi Deltası ve Kuyucuk Gölü'nde üreme döneminde görülmüştür. 1987 yılında ülke nüfusunun 50-100 çift olduğu düşünülmüştür. Üreme sonrasında Çukurova ve Göksu Deltası'nda 100-200 bireyin toplandığı bilinir. Nadiren az sayıda kışlamıştır. En son sayımlarda 1993'te Çukurova'da dört, 1997'de aynı alanda 35 birey sayılmıştır.

Amik Gölü'nün kurutulmasından önce muhtemelen önemli sayılarda bulunuyordu @kumerloeve1963a. Konya havzasındaki Yarma Sazlıkları, Gönenç Gölü ve Karapınar Ovası'nda @grimmett1989 muhtemelen üremiştir. Mogan Gölü ve Eber Gölü gibi diğer birkaç alanda da üremiş olabilir. Bu alanlar ekolojik özelliklerini kaybettikleri ve türe uygun üreme habitatları barındırmadıkları için artık üremeye elverişli değildir. Üreme sonrası toplanan bireyler, o yıllarda toplam ülke nüfusu hakkında fikir verebilir. Ağustos 1967'de Çukurova'da 2000 birey ve Göksu Deltası'nda 450 birey sayılmıştır.

#box(image("images/harita_Marmaronetta angustirostris.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Çukurova ve Göksu Deltası'nda sığ ve ötrofik göllerde bulunmuştur. Genellikle sazlık adaların, bitişik havuzlar ve sazlıkların bulunduğu yoğun sualtı vejetasyonuna sahip sığ göllerin çevresinde ürer ve geniş sulakalanları tercih eder. Sanılanın aksine acı veya tuzlu sularda değil tatlı suları tercih eder. \
#strong[Yuvası:] 9 Haziran 1993'te Göksu'da, kofanın (#emph[Juncus]) baskın olduğu ve yakınlarda sazların (#emph[Phragmites]) da bulunduğu bataklık bir bölgede sığ gölcüklerin olduğu bir alanda, yaklaşık 1 m çapındaki bir #emph[Juncus] kümesinin içinde, sudan yaklaşık 0,7 m yüksekte gizlenmiş iki yumurtalı bir yuva bulunmuştur. Yuva sazlardan ve bitki gövdelerinden yapılmış dayanıklı bir kâse şeklindedir ve ince bitkisel malzemeyle kaplanmıştır; hav tüyü kullanılmamıştır. \
#strong[Yumurta Sayısı:] Yumurta sayısı 2 ile 12 arasında değişir, ortalama 6,5 yumurta olarak hesaplanmıştır @green1993. Diğer bölgelerde ise tipik yumurta sayısı 9-13'tür (5-18). \
#strong[Üreme Dönemi:] 22 Mayıs 1971'de Çukurova'da kaydedilen altı yavru, en erken kayıttır ve yumurtlamanın nisanın ikinci yarısında başladığını gösterir. Ana yumurtlama dönemi, mayısın ikinci yarısıyla haziran başı arasındadır. Yavrular en erken 7 Haziran'da ortaya çıkar ve temmuz sonuna kadar küçük yavrular görülebilir. Tamamen palazlanmış yavrular temmuz başında kaydedilmiştir. #strong[AKD:] 1991'de Göksu Deltası'nda yaklaşık 50 çiftten en az 31'i yavru çıkarmıştır. Aynı yıl Göksu Deltası'nda 11 yuvada 8-13, 5 yuvada 4-6 ve bir yuvada 15 yavru sayılmıştır. 15 yavrunun, iki dişinin yumurtalarının bir araya gelmesiyle oluştuğu düşünülmektedir. Benzer şekilde 15-18 Temmuz 1992'de bir dişi 32 yavruyla görülmüştür @green1993. 10 Temmuz 1967'de hem büyük hem küçük yavrular haziran ve temmuzda az sayıda gözlenmiştir @vielliard1968resultats. #strong[İÇA:] 4-5 Haziran 1971'de Yarma Sazlığı'nda 6 ve 13 yumurtalı iki yuva bulunmuş, bir yuvada bir Yeşilbaş yumurtası görülmüştür. 12 Haziran 1998'de Kulu Gölü'nde tek yavrulu bir erişkin kaydedilmiş ve temmuz ayında üç farklı alanda yavrular gözlenmiştir. #strong[DOA:] 22 Temmuz 1987'de Van Sazlığı'nda küçük yavruları olan iki çift gözlenmiş, bu gözleme dayanarak yumurtlamanın haziran ortasında olduğu tahmin edilmiştir. Aynı alanda temmuz sonunda ve ağustos başında genç bireyler kaydedilmiştir.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Macar Ördeği
<macar-ördeği>
#emph[Netta rufina], Red-crested Pochard

#strong[#emph[Lokal olarak nispeten çok sayıda ürer. Kışın daha yaygındır ve bazı alanlarda yüksek sayılarda toplanır.]]

İç Anadolu'daki geniş sodalı ya da tatlı sazlık sulakalanlarda çok sayıda ürer. Sultansazlığı'nda yüksek sayılarda bulunur. 1990'larda Ereğli Sazlığı'nda 500 çift üremişken 1998'de sadece 20 çift üremiş, alanın kurutulmasıyla buradan tamamen yok olmuştur. Kızılırmak Deltası'nda 1992'de 50-75 çift üremiştir @hustings1994. Diğer alanlarda nispeten yüksek sayılarda yuvalayanlar yerli veya yarı göçmendir. Çukurova sulakalanları ve Göksu Deltası'nda üreyen nüfus 1990'dan sonra azalmıştır. Türkiye'de üreyen popülasyon 1000-5000 çift olarak tahmin edilmiştir @tucker1994. Son yıllarda İç Anadolu'da üreyen kuşların sayılarında yaşanan azalma, güncel ulusal nüfusun çok daha az olduğuna işaret etmektedir.

Ülke genelinde geçiş sırasında doğu bölgeleri dışında daha yaygındır. Çoğu zaman yüzeyi donmaya daha az eğilimli olan baraj göllerini tercih eder. Ocak 1967'de 12.000 birey sayılmış, bunun 7000'i bugün kurutulmuş olan Amik Gölü'ndendir. Türkiye genelinde 1992'de 5249, 1996'da 6522 ve 1999'da 6228 birey sayılmıştır. 2000'li yıllarda toplam sayıda artış görülmüş, sadece Beyşehir Gölü'nde Şubat 2003'te 10.000 birey ve Ocak 2005'te 20.000 birey sayılmış, son sayımda hem toplam hem de alan rekoru kırılmıştır.

#box(image("images/harita_Netta rufina.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Yoğun sazlıkların ve su kenarı bitkilerinin bulunduğu tatlı ya da sodalı göllerde ve su aynalarına sahip sazlıklarda ürer.

#strong[Yuvası:] Yerdeki bir oyuğa yaptığı yuvasını bitkisel malzeme, hav tüyleri ve tüylerle kaplar. Çoğunlukla yoğun vejetasyonun içine, nadiren açıkta (örneğin adalarda) ya da nemli alanlarda su seviyesinin üzerindeki saz öbeklerinin ya da diğer sucul bitkilerin içine genellikle iyice gizlenmiş bir yuva yapar.

#strong[Yumurta Sayısı:] Türkiye'de gözlenen yumurta sayısı 4-12 olup, ortalama 8,3'tür (18 yuvada). Bir yuvada bulunan 24 yumurta muhtemelen birden fazla dişiye aittir. Yavru sayısı 2-12 arasında değişir ve 16 yuvada ortalama 6,2'dir. Sadece 2-4 yavru çıkarabilmiş 6 dişi ortalamayı düşürmüştür.

#strong[Üreme Dönemi:] Nisan sonu ile temmuz başı arasında yumurtlar. Yavrular temmuz sonuna kadar görülebilir. #strong[MAR:] 1 Mayıs 1993'te Kocaçay Deltası'nda yumurtalı bir yuva bulunmuştur @ertan1996. #strong[KAR:] Kızılırmak Deltası'nda 27 Mayıs 1992'de beş yumurtalı bir yuva bulunmuş, 4 Haziran 1992'de yaklaşık bir haftalık ilk tüylü yavru kaydedilmiş @hustings1994 ve 27 Mayıs 1979'da sekiz yavrulu bir aile gözlenmiştir @dijksen1985. #strong[AKD:] 18 Temmuz 1992'de Karamık Gölü'nde küçük yavrulardan oluşan bir aile gözlenmiştir. #strong[İÇA:] Çoğu mayısta olmak üzere 25 Nisan'da yumurta kayıtları vardır. En geç kayıt 19 Haziran 1992'de 12 yumurtalı bir yuvadır. Biri 11 Mayıs'ta, çoğu haziranda olan birçok yavru kaydı vardır, en geç 8 Temmuz 1967'de @vielliard1968resultats ve 5 Ağustos 1972'de küçük yavrular gözlenmiştir. #strong[DOA:] 21-22 Temmuz 1986'da Van Gölü'nde 7-8 yavrulu üç yavrulu bir aile kaydedilmiştir.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Elmabaş Patka
<elmabaş-patka>
#emph[Aythya ferina], Common Pochard

#strong[Nispeten yaygın ve çok sayıda bulunan yerli ve yarı göçmen, yaygın ve çok sayıda bulunan kış konuğudur.]

İç ve Doğu Anadolu'daki sulakalanlarda orta sayılarda üreyen yerli ve yarı göçmendir. 1992'de Kızılırmak Deltası'nda 300-350 çiftin ürediği tahmin edilmiştir @hustings1994. Uygun habitatların azlığı nedeniyle Karadeniz, Güneydoğu Anadolu ve diğer bölgelerde lokal olarak bulunur. Muhtemelen gerçek üreme durumunu çarpıtacak şekilde, hatırı sayılır sayıda üremeyen birey özellikle İç ve Doğu Anadolu'da yazı geçirir.

Kışın ve geçiş dönemlerinde ülke genelinde yaygın ve boldur. Son yıllarda ortalama 67.000 bireyden fazla sayılmaktadır. 1996 yılında Beyşehir Gölü'nde 47.000, Uluabat Gölü'nde 42.000 ve ülke genelinde toplamda 250.000 birey sayılmıştır, bu en yüksek kayıtlardandır. 1999'da Eğirdir Gölü'nde 40.000, ülke genelinde ise 137.000 kuş sayılmıştır. 18 yıllık Kış Ortası Su kuşu sayımlarının ortalaması 93.000 kuştur. İstisna olarak 1968-69 kışında 355.000 bireyin kışladığı tahmin edilmiştir. Ekim ortasından itibaren yüksek sayılar gözlemlenir; Göksu Deltası'nda Ekim 1978'de 40.000, Ekim 2002'de Sodalıgöl'de 100-130.000, Kulu Gölü'nde Kasım 1970'te 45.000 ve Kasım 1971'de 28.000 birey kaydedilmiştir.

#box(image("images/harita_Aythya ferina.png"))

#strong[Üreme]

#strong[Yuvalama alanı:] Göl kıyılarındaki sazlıklarda ve su aynalarının bulunduğu sazlık bataklıklarda ürer. \
#strong[Yuvası:] 19 Haziran 1984'te Erçek Gölü yakınlarındaki küçük bir gölde, sık bir örtü içindeki sazların dibine tutturulmuş ve sakarmeke yuvasına benzer şekilde sudan yükseğe yapılmış bir yuva bulunmuştur. Yuva, ölü saz gövdeleri ve diğer bitkisel malzemelerle derin ve düzgün bir kâse şeklinde örülmüş, bol miktarda hav tüyü ve diğer tüylerle kaplanmış dayanıklı bir yapıya sahiptir. Diğer bölgelerdeki yuvalar da genellikle benzer alanlarda olup nadiren su kıyısındaki yoğun bitki örtüsünün içinde kuru zeminde de bulunabilir. \
#strong[Yumurta Sayısı:] Türkiye'de yumurta sayısı kaydedilmemiştir, ancak gözlenen yavru sayısından 8-11 yumurta bırakabileceği düşünülmektedir. Diğer bölgelerde genellikle 6-9 yumurta bırakır. Gözlenen yavru sayısı ortalama 6,6'dır. \
#strong[Üreme Dönemi:] Nisan başı ile haziran ortasına kadar yumurta bırakır. Yavrular temmuz ayında gözlenebilir. #strong[KAR.] Kızılırmak Deltası'nda 11 Mayıs 1992'de hav tüyleriyle kaplı birkaç günlük yavru, en erken kayıt olarak görülmüş ve bu da yumurtlamanın nisanın ilk haftasında olduğunu göstermiştir @hustings1994. 14 Haziran 1984'te yaklaşık 5 günlük yavrulardan oluşan bir kuluçka ile yaklaşık üç haftalık yavrulardan oluşan iki kuluçka gözlenmiştir @dijksen1985. #strong[İÇA.] Haziran başlarında iki yumurtalı (tamamlanmamış) bir yuva bulunmuş, Haziran 1971'de Boz Ördek yuvalarına iki, dört ve beş yumurta bırakıldığı tespit edilmiştir. 13 Mayıs 1991'de Hotamış'ta yumurtalı bir yuva bulunmuştur @kirwan1993a. 1970 yılının mayıs ayı sonunda Eşmekaya'da küçük yavrulardan oluşan beş yavru, 1 Haziran 1969'da Sultansazlığı'nda altı yavru ve haziran-temmuz aylarında diğer alanlarda yavrular gözlenmiştir. #strong[DOA.] 19 Haziran 1983'te Van Sazlığı'nda yavrularıyla birlikte sekiz dişi kaydedilmiştir.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Pasbaş Patka
<pasbaş-patka>
#emph[Aythya nyroca], Ferruginous Duck

#strong[Lokal olarak az sayıda üreyen yaz konuğu, yaygın ve nispeten çok sayıda bulunan geçit türü, yaygın ancak az sayıda kış konuğudur.]

Tüm bölgelerdeki sulakalanlarda oldukça lokal bir yaz konuğudur. En yüksek sayılarda İç ve Doğu Anadolu bölgelerinde bulunur. Kızılırmak Deltası (1992'de tahminen 150-200 çift @hustings1994, Kocaçay Deltası (1993'te tahminen 70 çift @ertan1996, Uluabat Gölü (1988'de tahminen 32 çift @welch1998b ve Göksu Deltası (yaklaşık 30 çift) önemli sayılarda ürediği alanlardır. Son yıllarda gerçekleştirilen çalışmalarda Güneydoğu Anadolu'da üç yeni üreme alanı belirlenmiştir. Yaz göçmenleri mart ortasından eylül sonuna kadar gözlenir.

Türkiye popülasyonu muhtemelen dünyadaki en önemlilerinden biridir ve 1000 ile 3000 çift arasında olduğu düşünülmüş @tucker1994, sonra bu tahmin 500-600 çift olarak güncellenmiştir @kirwan1997b. Avrupa'da yayılış alanının bir kısmında yaşanan sert düşüş dikkate alındığında, Türkiye popülasyonunun izlenmesine acil ihtiyaç duyulmaktadır. 1990'ların sonlarında İç Anadolu'daki birkaç alanda da azalma görülmüştür.

Geçiş sırasında az ve orta sayılarda bulunur ve ülke genelinde biraz daha yaygındır. Az sayıda kışlar, 1992 yılında 105 birey, diğer yıllarda 50 bireyden az sayılmıştır. 1990'ların ortalarından itibaren kış kayıtlarında bir artış gözlenmiş, bu durum muhtemelen gözlemci sayısının artmasına bağlanmıştır. Eskiden batı ve orta bölgelerde daha çok sayıda kışlamış, 1968-74 yıllarında 50 ile 450 birey arasında kaydedilmiştir. Marmara Gölü'nde kaydedilen 860 birey en yüksek kayıttır. Doğu ve Güneydoğu Anadolu'da 2005 yılında sayılan 44 birey bahsedilmeye değerdir.

#box(image("images/harita_Aythya nyroca.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Çevresinde sazlıkların, yoğun su üstü vejetasyonunun ve çoğunlukla daha geniş sazlıkların ve bataklıkların bulunduğu tatlı su göllerinde ürer. \
#strong[Yuvası:] Su kenarındaki yoğun vejetasyonun içine yuva yapar. Kulu Gölü'ndeki bir adada, alçak çalıların arasında çıplak zeminde hafif bir çukurun içine yapılan yuvanın ot ve hav tüyleriyle kaplandığı gözlenmiştir @pforr1982\; A. Limbrunner, kişisel görüşme). \
#strong[Yumurta Sayısı:] Türkiye'de gözlenen yumurta sayısı 6-8 arasındadır. \
#strong[Üreme Dönemi:] Nisan ile haziran başı arasında yumurta bırakır. Yavrular ağustos ayına kadar gözlenebilir. #strong[MAR:] 19 Haziran 1999'da Uluabat Gölü'nde bazıları küçük yavrulardan oluşan birkaç yavru grubu gözlenmiş, 1966'da Manyas Gölü'nde de yavrular kaydedilmiştir. #strong[KAR:] Kızılırmak Deltası'nda çiftlerin çoğu sazlık alanlarda gözlenmiştir. 5 Mayıs 1992'de altı yumurtalı bir yuva bulunmuş ve 1 Haziran 1992'de yumurtlamanın nisan sonlarından daha geç olmadığını gösteren üç ve dört yavrulu iki grup kaydedilmiştir @hustings1994. 6 Ağustos 1971'de yedi yavrulu bir grup gözlenmiştir. #strong[AKD:] 15 Mayıs 1962'de Çukurova'da sekiz yumurtalı bir yuva @kirwan1997b, 8 Mayıs 1953'te Amik Gölü'nde yumurtalı bir yuva @kirwan1997b, ve 27 Mayıs 1933'te yumurta kanalında yumurta bulunan bir dişi vurulmuştur @meinertzhagen1935. Göksu Deltası'nda en erken 17 Haziran'da olmak üzere yedi yuva alanında yavrular gözlenmiştir. #strong[İÇA:] 28 Nisan 1982'de Sultansazlığı'nda yumurtalı bir yuva bulunmuştur @kirwan1997b. Mayıs 1973'te Kulu Gölü'nde altı yumurtalı bir yuva bulunmuştur. En erken 20 Haziran'da Eber Gölü'nde olmak üzere Çöl Gölü, Gönenç Gölü, Sultansazlığı, Mogan Gölü ve Kulu Gölü'nde yavrular gözlenmiştir. #strong[DOA:] Yumurtlamanın mayıs sonunda olduğunu gösteren gözlemler 1985 ve 1987 yıllarında haziran sonunda Van Gölü'nde ve 29 Haziran 1987'de Edremit Sazlığı'nda yapılmıştır @kirwan1997b.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Tepeli Patka
<tepeli-patka>
#emph[Aythya fuligula], Tufted Duck

#strong[#emph[Lokal ve az sayıda üreyen yaz konuğu, nispeten yaygın ve çok sayıda bulunan kış konuğudur.]]

Çok nadir ve lokal olarak üremiştir. Kızılırmak Deltası'nda ve 1967 ile 1981'de Çalı Gölü'nde (Kars) ürediği kanıtlanmış, son alanda 20 çiftlik bir popülasyon tespit edilmiştir. Başka bölgelerde düzenli olarak yazı geçirir. Uluabat Gölü ve Uyuz Gölü gibi bazı alanlardaki uygun habitatlarda çiftler gözlenmiştir. Üreme sonrasında, Temmuz 1982'de Kulu Gölü'nde tüy değişimi için toplandıkları düşünülen 700 birey @kasparek1987a, Eylül 1967'de ise Sodalı Gölü'nde çoğu erkek olan 1200 birey sayılmıştır.

Ülkenin batı ve orta bölgelerinde eylül başından nisan başına kadar kaydedilen yaygın ve bol bulunan bir geçiş türü ve kış konuğudur. Karadeniz'de denizde kışlar. Kış ortası sayımlarında; 1968-69 kışında 20.800 birey, 1996'da en yüksek sayı olan 58.271 birey, 1992'de yaklaşık 13.000 birey, 1993'te 16.965 birey (sadece Eğirdir Gölü'nde 10.478 birey) ve 1999'da 18.512 birey kaydedilmiştir. Son yıllarda ise ülke toplamı genellikle 5000-10.000 birey arasındadır. En önemli kışlama alanları Sapanca Gölü ve Eğirdir Gölü'dür.

#box(image("images/harita_Aythya fuligula.png"))

#strong[Üreme]

#strong[Yuvalama alanı:] Su üstü vejetasyonu olan tatlı su göllerinde ürer. \
#strong[Yuvası:] Yuvasını bir bitki öbeğinin altına kurar. \
#strong[Yumurta sayısı:] Türkiye'de 8 yumurtalı bir yuva bulunmuştur. \
#strong[Üreme dönemi:] Mayıs ayında yumurta koyar, temmuz sonuna kadar yavrular görülebilir. #strong[KAR:] Kızılırmak Deltası'nda, 5 Mayıs 1992'de sazlıkta bir #emph[Juncus acutus] öbeğinin dibinde sekiz yumurtalı bir yuva bulunmuş @hustings1994 ve 28 Mayıs 1968'de de ürediği kanıtlanmıştır @dijksen1985. #strong[DOA:] Çalı Gölü'nde 19 Temmuz 1992'de yavrularıyla birlikte iki dişi gözlenmiştir @magninyarar1997.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Karabaş Patka
<karabaş-patka>
#emph[Aythya marila], Greater Scaup

#strong[#emph[Özellikle Karadeniz kıyılarında az sayıda ve düzenli olarak görülen kış konuğudur.]]

Karadeniz ve Marmara Bölgesi'nde hemen hemen her yıl az sayıda görülmektedir. Modern kuş tayininin başlaması sonrasında gelen kayıtlar şöyledir @ost1969@ost1972@ost1975@ost1978: Ocak-Şubat 1969'da Sakarya Deltası'nda yedi birey, Manyas ya da Uluabat Gölü'nde dört birey görülmüştür. Kızılırmak Deltası'ndaki Liman Gölü'nde 1990'ların başlarında kışlayan 38 birey, 1970'lerde aynı alandan bildirilen şüpheli kayıtların @dijksen1985 geçerli olabileceğini düşündürür.

Çoğu İstanbul civarından olan geçmiş veriler şöyledir: Şubat 1893'te Çekmece'de daha çok dişi ve gençlerden oluşan bir grup gözlenmiş ve şu anda Sofya Doğa Tarihi Müzesi'nde bulunan erkek örnek toplanmıştır @alleon1880. İstanbul Robert Kolej'de bulunan dişi örnek @matheydupraz1920, 1998'deki bir ziyarette bulunamamıştır @kirwan1997a. 1946-47 ve 1947-48 kışlarında Çatalağzı açıklarında (Zonguldak) belirsiz sayıda gözlenmiş @ogilvie1954, 15 Ocak 1950'de bilinmeyen bir yerden altı örnek alınmıştır @kumerloeve1970a. Büyükçekmece'de Ocak 1963'te bir erkek ve Şubat 1964'te bir dişi kaydedilmiştir @kumerloeve1970a.

Türün ilk yaz kaydı 30 Mayıs 1992'de Sodalı Gölü'nde kaydedilen iki erkektir @kirwanmartins1994. Öte yandan, 19 Nisan 1981'de Kulu Gölü'nde gözlenen iki birey, 12 Nisan 1990'da Göksu Deltası'nda gözlenen yaklaşık 20 birey @kirwanmartins2000 olağandışı geç kayıtlardır.

#box(image("images/harita_Aythya marila.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Avrasya ve Kuzey Amerika'nın kuzeyinde yuvalar.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur.

== Pufla
<pufla>
#emph[Somateria mollissima], Common Eider

#strong[#emph[Karadeniz kıyılarında nadiren az sayıda görülür.]]

İlk üç kayıt şu şekildedir: 20 Eylül 1983'te Çernek Gölü'nde (Kızılırmak Deltası) bir erkek @dijksen1985, 3 Ocak 1984'te Göksu Deltası'nda ölü bir dişi @kasparek1990a, 1 Şubat 1997'de Sakarya Nehri deltasının batısında, Kefken açıklarında iyi tanımlanmış ilk kışında bir erkek ve iki dişi @welch1998a bulunmuştur. Bundan sonra Riva, Terkos Gölü kıyıları, İğneada, Kızılırmak Deltası, İzmit Körfezi ve Sakarya Karasu'da 20'den fazla kayıtta 1-3 birey tespit edilmiştir.

Türkiye'de üremez, en yakın üreme kolonisi Ukrayna kıyılarındadır. Güvenilir kayıtların tümü, 1975 yılında Ukrayna'nın Karadeniz kıyısında bir üreme alanının keşfedilmesinden sonra olmuştur. Bu popülasyon 1990'ların ortasına kadar 1000 çifte ulaşmış ve günümüze kadar artmaya devam etmektedir.

Şubat 1929'un ilk yarısında Tarabya ile Beykoz arasında (İstanbul Boğazı) gözlenen bir erişkin erkek @kumerloeve1970a, tanım olmadığı için burada kabul edilmemiştir.

#box(image("images/harita_Somateria mollissima.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Ukrayna'daki koloni insan eliyle oluşturulmuş, kolonideki kuşlar zamanlar doğallaşmıştır. Doğal yuvalama alanı Kuzey Atlantik, Kuzey Buz Denizi ve Bering Boğazı'dır.

#strong[Alttürler ve Sınıflandırma]

Ülkede gözlenen alttür nominat #emph[mollissima] (Kuzeybatı Avrupa) alttürüdür.

== Kadife Ördek
<kadife-ördek>
#emph[Melanitta fusca], Velvet Scoter

#strong[#emph[Türkiye'de üreyen nüfus yok olmuştur. Karadeniz kıyılarına az sayıda kışlar.]]

Doğu Anadolu'da az sayılarda kaydedilen çok lokal bir yaz konuğu idi. Az sayıda yüksek irtifa göllerinde 3000 m'nin üstünde üremiş olduğu düşünülür. Aktaş Gölü (Ardahan) kesin olarak ürediği tek alandır. 3 Ekim 1980'de 100 birey @vanderven1980birds ve 14-15 Temmuz 1994'te aralarında gençlerin de bulunduğu 725 birey @yarar1995aktas kaydedilmiştir.

Geçmişte Nemrut Dağı'ndaki (Tatvan) krater gölünde 20 çifte ürediği düşünülmüştür. Ağrı Balık Gölü'nde geçmişte ürediği sanılmış, ancak görünüşe göre Haziran 2001'de artık üremediğine karar kılınmıştır. Çıldır Gölü'nde ürediği güçlü şekilde şüphelenilmiş, ancak teyit edilmemiştir. Kars Aygır Gölü ve Muş Nazik Gölü'nde azami 32 birey yazı geçirmiştir. Doğu Karadeniz kıyılarında kışlayan bireylerin yaz aylarında da kaldığı gözlenmiştir.

Gürcistan'da yuvalamaya devam eden bireyler Karadeniz kıyılarına az sayıda kışlar. Orta ve Doğu Karadeniz boyunca az sayıda kışlar. 1995 Aralık sonunda Yeşilırmak Deltası'nda 870 birey en yüksek kayıttır. Nadir olarak Batı Karadeniz, Marmara'da ve güneyde Akdeniz kıyısında kışlamıştır. Ocak 1970'te Burdur Gölü'nde 27 birey, Şubat 1966'da Mogan Gölü'nde ve Ocak 2005'te Hazar Gölü'nde kaydedilmiştir. Son yıllarda kaydedilen 50 birey.

4 Şubat 1917'de İstanbul Zeytinburnu açıklarında gözlenen iki birey ülke için ilk kayıttır.

#box(image("images/harita_Melanitta fusca.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Doğu Anadolu'daki iki ya da üç yüksek irtifa gölünde üremiştir. Tüm çabalara rağmen Türkiye'de yuvası bulunamamıştır. Şu anda Kafkasya popülasyonu sadece Gürcistan'da bir gölde yuvalamaktadır. \
#strong[Yuvası:] Türkiye'de yuva bulunmamıştır ancak diğer yerlerde yoğun bitki örtüsünün içine gizlenmiş şekilde yerde ve genellikle göllerdeki adalarda yuva yapar. \
#strong[Yumurta sayısı:] Olağan yumurta sayısı 7-10'dur. \
#strong[Üreme dönemi:] Eski gözlemlere göre temmuz ve ağustos ayında yuvalamıştır. #strong[DOA.] 10 Temmuz 1967'de Nemrut Dağı'ndaki krater gölünde iki, yedi ve dokuz hav tüylü küçük yavru ile birlikte üç dişi ve 20 Ağustos 1967'de Balık Gölü'nde dört, beş ve altı yavrulu üç dişi kaydedilmiştir @vielliard1968resultats. Küçük ördeklerin sadece yaklaşık bir haftalık olduğu varsayılırsa yumurtlamanın haziranın ilk günlerinde olduğu anlaşılmaktadır. 23 Ağustos 1972'de Nemrut Dağı'nda gözlenen hemen hemen yarı gelişmiş yedi yavrulu bir dişi, yumurtlamanın haziranın son haftasında olduğunu göstermektedir. 9 Temmuz 1985'te Nemrut Dağı'nda beş çift ve iki genç birey gözlenmiştir. Son zamanlara ait bir üreme kaydı yoktur ve 9 Haziran 2001'de Balık Gölü'ndeki adada yapılan kapsamlı araştırmada ne yuva bulunmuş ne de erişkin görülmüştür.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür. Eskiden Amerika ve Doğu Sibirya'da yaşayan Ak Kanatlı Kadife Ördek #emph[Melanitta deglandi] ile aynı tür olarak kabul ediliyordu.

== Kara Ördek
<kara-ördek>
#emph[Melanitta nigra,] Common Scoter

#strong[#emph[Nadir kış konuğudur.]]

Karadeniz'de çoğunlukla eylül ve mart arasında çok az sayıda kaydedilen kış göçmenidir. Düzenli olarak sadece Kızılırmak ve Yeşilırmak deltalarının açıklarında 20 birey kışlamaktadır. Karadeniz kıyısında toplam 20'den fazla kaydı vardır. Marmara ve Ege'de çok nadirdir, Akdeniz'de sadece bir kere kaydedilmiştir.

9 Nisan 1967'de Kocaçay Deltası'nda kaydedilen bir birey ülke için kabul edilebilir ilk kayıttır @ost1969. Öncesinde Ege'de nadir bir kış göçmeni olduğundan @kruper1875 ve İstanbul Boğazı ile Ceyhan Deltası'ndaki şüpheli kayıtlardan @kumerloeve1961 bahsedilmiştir.

#box(image("images/harita_Melanitta nigra.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Avrasya'nın kuzeyinde yuvalar.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Telkuyruk
<telkuyruk>
#emph[Clangula hyemalis], Long-tailed Duck

#strong[#emph[Nadir kış konuğudur.]]

Şubat 1893'te İstanbul (Büyük?) Çekmece'de, Alléon tarafından toplanan genç bir dişi ülke için ilk kayıttır ve bu örnek Sofya Doğa Tarihi Müzesi'nde görülebilir. Ardından, 13 Kasım 1968'de İzmit'te genç bir birey kaydedilmiştir @ost1975. Göksu Deltası Paradeniz Gölü'nde 1-2 Ocak 1986'da bir birey ve 5 Ocak 1989'da bir dişi @kasparek1990a görülmüştür. Sakarya Nehri ağzında 18 Şubat 2004'te @balmer2004b\; 26 Şubat 2006'da Fırtına Nehri'nin ağzında birer birey fotoğraflanmıştır. En güncel kayıtlara göre; 7-19 Ocak 2008'de İğneada'da erişkin bir dişi, 13 Şubat 2008'de Kıyıköy'de bir erkek, 10 Aralık 2008'de İğneada'da bir birey (on üçüncü kaydı) ve 28 Mart 2009'da Enez'de bir birey (on dördüncü kaydı) görülmüştür @kirwan2014.

İstisnai olarak, Van Gölü'nden 1977 ile 1987 arasında mayıs ve haziran aylarında yaz kayıtları mevcuttur. 10 Haziran 1977'de Gevaş'ın batısında Horkum'da iki birey ve Tatvan ile Ahlat arasında üç birey @beaman1986, 22 Mayıs 1985'te Van'ın güneybatısında bir erkek @martins1989, 9 Haziran 1987'de Van Sazlığı'nda bir erkek ve 22 Haziran 1987'de Van'ın 10 km güneyinde bir birey @kirwanmartins1994 kaydedilmiştir.

#box(image("images/harita_Clangula hyemalis.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Kuzey İskandinavya dağlarında ve Rusya ve Kuzey Amerika'nın tundra kuşağında yuvalar.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Altıngöz
<altıngöz>
#emph[Bucephala clangula,] Common Goldeneye

#strong[#emph[Nispeten yaygın ve az sayıda kış konuğudur.]]

Karadeniz, Marmara ve Ege'nin kıyı bölgelerinde ve daha nadir olarak iç bölgelerdeki sulakalanlarda ekim sonu ve nisan sonu arasında nadir bir kış konuğudur. En düzenli olarak Marmara ve Karadeniz bölgelerinde görülür. Kışın ülke çapında görülen kuş sayısı nadiren 100 bireyi geçer. 3 Şubat 1992'de Kızılırmak Deltası'nın açıklarında gözlenen 200 birey, kaydedilen en yüksek sayıdır. 2005-06 kışında Gediz Deltası'nda 72 birey, 3 Şubat 2002'de Gala Gölü'nde 60 birey sayılmıştır @demirci2002. Son yıllarda ilkbahar sonunda Doğu Karadeniz'de kaydedilmiştir.

1977 ile 1993 yılları arasında Doğu Anadolu'da, çoğunluğu Van Gölü'nde olmak üzere, bir dizi yaz kaydı vardır ve bu kayıtlarda bazen birden fazla birey gözlenmiştir. Bu kayıtlar, yakınlarda üreyen bir popülasyonun ihtimalini düşündürmüştür @kasparek1992a.

#box(image("images/harita_Bucephala clangula.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Avrasya ve Kuzey Amerika'nın kuzeyinde yuvalar.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur.

== Sütlabi
<sütlabi>
#emph[Mergellus albellus,] Smew

#strong[#emph[Kuzey bölgelerine az sayıda gelen bir kış konuğudur.]]

Kasımdan nisan ortasına kadar ülkenin batı ve orta bölgelerindeki sulakalanlarda ve kıyılarda tipik olarak nadir ve muhtemelen düzensiz bir kış konuğudur. En çok Marmara, Karadeniz ve İç Anadolu'da kaydedilir. Her kış genellikle 100 bireyden daha azdır. Uluabat Gölü'nde 1967'de 300, 1969-70'te 1300, 1973'te 555, 1989'da 111 ve 1995'te 248 birey kaydedilmiştir. 1992'de Manyas Gölü'nde 102 ve 1993'te Büyükçekmece'de 79 birey kışlamıştır.

Nisan 1987 sonunda Diyarbakır'da kaydedilmiştir. Doğu ve Güneydoğu Anadolu'da oluşturulan büyük baraj göllerinde gözlenmesi beklenebilir. Ocak 1979'da Irak Razzaza Gölü'nde gözlenen 1000'den fazla birey @scott1982, daha güneyde yüksek sayılarda kaydedilebileceğini göstermektedir.

Ancak ne tuhaftır ki, türün ilk keşfi Strickland tarafından İzmir'den alınan iki örnek ile yapılmıştır. Cambridge Üniversitesi Zooloji Müzesi'ndeki koleksiyonda bulunan bu örnekler, 6 Ocak 1836'da alınan bir erkek ve aynı yıl şubat ayında alınan bir dişiye aittir. 1946-48 yıllarında Çatalağzı açıklarında (Zonguldak) oldukça bol olduğu gözlenmiştir @ogilvie1954.

11 Haziran 1969'da Eymir Gölü'nde (Ankara) bir erkek @ost1972, 27 Haziran 1987'de Göründü'de (Van) bir dişi @kirwanmartins1994 ve 27 Mayıs 1995'te Uluabat Gölü'nde bir erkek ve iki dişi @kirwanmartins2000 olmak üzere yazın üç defa kaydedilmiştir.

#box(image("images/harita_Mergellus albellus.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Avrasya'nın kuzeyinde yuvalar.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür. Türkiye'de tanımlanmıştır.

== Büyük Tarakdiş
<büyük-tarakdiş>
#emph[Mergus merganser,] Common Merganser

#strong[#emph[Nadir kış konuğudur.]]

Özellikle Marmara ve Karadeniz bölgelerinde az sayıda kaydedilen nadir bir kış konuğudur. 1997-2007 arasında artan gözlemci aktivitesine karşın sadece 10 kere kaydedilmiştir @kirwan2003. Genellikle kıyısal sulakalanlarda görülür ve en düzenli olarak Kızılırmak ve Yeşilırmak deltalarında kaydedilir. Kızılırmak Deltası'nda görüldüğü en geç tarih 20 Mayıs'tır.

Doğu Anadolu'da şubat ve martta iki defa, yazın ise üç kere gözlenmiştir; 11 Haziran 1970'te Pasinler ile Horasan arasında Aras Nehri üzerinde bir çift, 7 Haziran 1986'da Van Gölü'nde bir birey ve 29 Haziran 1988'de Bendimahi Deltası'nda bir dişi ya da genç birey kaydedilmiştir. Kurutulmadan önce Sevan Gölü (Ermenistan) havzasında üreyen bir tür olduğu düşünülmüş, ancak ürediğine dair bir kanıt elde edilmemiştir @adamian1999.

#box(image("images/harita_Mergus merganser.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Avrasya ve Kuzey Amerika'nın kuzeyinde yuvalar.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur.

== Tarakdiş
<tarakdiş>
#emph[Mergus serrator], Red-breasted Merganser

#strong[#emph[Nispeten lokal olarak ve orta sayılarda görülen bir kış konuğudur.]]

Kıyısal alanlarda ekim sonu ve nisan sonu arasında kaydedilen kış göçmenidir. En çok sayıda Doğu Karadeniz, Marmara ve Ege'de kaydedilir. Gediz Deltası'nda düzenli olarak yaklaşık 100 birey konaklar; Şubat 1996'da 397 birey sayılmıştır. Büyük Menderes Deltası'nda Şubat 1993'te 67 birey ve Yumurtalık'ta 44 birey kaydedilmiştir. Ege ve Doğu Akdeniz'deki alanlarda düzenli olarak önemli sayılarda kışlar @eken1997d. Akdeniz kıyılarında seyrek olsa da Kıbrıs'ta oldukça düzenli bir türdür.

20-21 Mayıs 1994'te Göksu Deltası'nda geç kalmış bir birey kaydedilmiştir (Birdquest Newsletter 23: 59). Tek yaz kaydı 11 Haziran 1964'te Amik Gölü'nde (Antakya) kaydedilen yedi veya sekiz bireydir @kumerloeve1966-67.

#box(image("images/harita_Mergus serrator.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Avrasya ve Kuzey Amerika'nın kuzeyinde yuvalar.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Dikkuyruk
<dikkuyruk>
#emph[Oxyura leucocephala,] White-headed Duck

#strong[#emph[Lokal olarak az sayıda üreyen yaz konuğu, nispeten yaygın ve yüksek sayıda bulunabilen geçit türü ve kış konuğudur.]]

İç Anadolu ve Doğu Anadolu'da tatlı veya acı (sodalı), sığ ve ötrofik göllerdeki yoğun sazlık sulakalanlarda az ila orta sayıda yuvalar. Van Gölü çevresinde ve Kars'taki küçük sulakalanlarda ürediği teyit edilmiştir. Doğu Anadolu'daki diğer alanlardaki üreme durumu belirsizdir. Niğde Akkaya Barajı'nda üremiştir @kirwan1994b. Üreme döneminde kaydedildiği Karadeniz Bölgesi'ndeki bazı alanlarda yuvalayabilir. Doğu Akdeniz sulakalanlarında yaz kayıtları, üremeyen bireylere aittir.

1980'lerin sonu ve 1990'ların başı arasında dört kilit alanda (Ereğli Sazlığı, Hotamış Gölü, Sultansazlığı ve Kulu Gölü) üreyen İç Anadolu popülasyonu muhtemelen 150 çiftin üzerindeydi @robinson1998. Ancak 1990'ların ortasında Ereğli Sazlığı ve Hotamış Gölü'nün kurumasıyla sayıları azalmış, Kulu Gölü'nde üremez olmuştur @richardson2003. Kozanlı Gökgöl ve Uyuz Gölü'nde az sayıda üremeye devam etmektedir.

Mart ile mayıs başı arasında birçok alanda geçiş sırasında gözlenir. 23 Mart 1992'de Kızılırmak Deltası'nda 1246 birey ve Mart 1990'da Ereğli Sazlığı'nda 508 birey toplanmıştır. Mayıs ve haziran arasında toplanan sürüler muhtemelen üreme alanlarına dağılacak kuşlardan oluşur. Temmuz ve eylül arasında toplanan sürüler ise üreme sonrası dağılmaya ve göç almaya işaret eder. Temmuzda Kulu Gölü'nde 500 birey ve ağustosta Sodalı Gölü'nde 600-1000 birey kaydedilmiştir.

Kışın Akdeniz'deki birkaç sulak alanda yüksek sayıda, İç Anadolu'da genellikle daha az sayıda kaydedilir. Batı ve orta bölgelerindeki diğer yerlerde ise daha nadiren, özellikle sert hava koşullarında kaydedilir. Karadeniz Bölgesi'nde düzensiz olarak yüksek sayılarda kışlar. Bir dönem dünya popülasyonunun %50'sinden fazlasının Burdur Gölü'nde kışladığı düşünülmüştür; buradaki sayımlarda 1987'de 6400, 1988'de 9230, 1989'da 6700 ve 1991'de 10.927 birey kaydedilmiştir @green1992. Ancak 1992 sonrasında sayılarda azalma görülmüş; 1992'de 3264, 1993'te 3010 ve 1994'te 3337 birey sayılmıştır. Bu sayımlar son derece hassas olup, eş zamanlı üç ekip tarafından ideal hava koşullarında gerçekleştirilmiştir. Burdur Gölü'nde 1993'te 1991'e göre daha az genç bireyin sayılması, daha düşük üreme başarısını gösterebilir. Bir ihtimal, Kazakistan ve çevre ülkelerdeki üreyen nüfustaki azalış, Türkiye'deki kışlama nüfusunun azalmasını açıklayabilir. Bu azalmada şüphesiz kaçak avcılığın da payı vardır; 1992-93 kışında Burdur Gölü'nde 1000'den fazlasının vurulduğu tahmin edilmiştir. Ayrıca son yıllarda Burdur Gölü'nün kuruma sürecinin başlaması ve tuzluluğun artması da bir etken olabilir.

#box(image("images/harita_Oxyura leucocephala.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Çoğunlukla büyük sulak alanların yakınlarında genellikle 10 hektardan küçük ve 2 metreden sığ, sualtı vejetasyonu bol ve su aynalarının bulunduğu geniş sazlıklara sahip tatlı su göllerinde ya da sodalı göllerde ürer @anstey1989. Aynı alanda birkaç çift üreyebilir. \
#strong[Yuvası:] Yuva, ölü saz gövdeleri ile diğer sucul bitkilerin düzgün bir kâse oluşturacak şekilde örülmesi ile oluşturulmuş, birkaç tutam açık gri tüy ile astarlanmış dayanıklı bir yapıdır. \
#strong[Yumurta sayısı:] Bir yuvada en fazla 10 yumurta kaydedilmiştir. 19 Haziran 2004'te aynı gölde diz boyu derinliğindeki suda yoğun bir sazlığın içinde iyice gizlenmiş bir şekilde suyun üzerinde dikey sazların dibine tutturularak yapılmış bir yuvada on yumurtalı tamamlanmış bir kuluçka bulunmuştur. Diğer yerlerde olağan yumurta sayısı 5-12'dir. Dikkuyruk, vücut ölçülerine göre son derece büyük ve ağır yumurtalar koyar; yuva bu ağırlık nedeniyle suya batabilir. \
#strong[Üreme dönemi:] Mayıs başı ve temmuz başı arasında yumurta koyar. Eylül sonuna kadar yavrular görülebilir. #strong[İÇA:] 13 Temmuz 1987'de Kulu Gölü'ndeki sazlıkların içindeki yuvada yedi yumurta gözlenmiştir; muhtemelen dişinin kuluçkaya ara vermesi nedeniyle yuva ve yumurtalar kısmen su altında kalmıştır @anstey1989. Üreme kayıtlarının çoğu 3-10 yavrudan oluşan gruplardır: İç Anadolu'daki en erken kayıt, 5 Haziran 1975'te Kulu Gölü'nde gözlenen üç büyük ve üç hav tüylü yavrudur; bu durum yumurtlamanın mayıs başında olduğunu gösterir. 6 Ağustos 1972'de (kurutulmuş) Gönenç Gölü'nde 20 günlük beşer yavrularıyla iki dişi ve dört günlük altı yavrulu bir dişi gözlenmiştir; bu kayıtlar yumurtlamanın haziran ortası ile temmuz başında olduğunu göstermektedir. İç Anadolu'da, temmuz ve ağustosta birçok yavrulu aile kaydedilmiştir. #strong[DOA:] Haziran-eylül ayları arasında Van Gölü'nde 9 Haziran 1987 ve 14 Haziran 1990'da gözlenen genç bireyler, yumurtlamanın mayıs ortasında olduğunu göstermektedir. Temmuz-ağustos arasındaki diğer kayıtlar, yumurtlamanın haziran ortasında başladığını düşündürmektedir. Erçek Gölü yakınlarındaki küçük bir gölün ortasında dikey sazlardan oluşan bir adada bir yuva bulunmuştur; sucul bitkiler kullanılarak sazların dibine yapılmış olan yuvada 11 Haziran 2001'de iki yumurta olduğu, kuluçkanın henüz tamamlanmadığı gözlenmiştir; alanda sekiz erkek ve yedi dişi birey kaydedilmiştir. Ancak oldukça kapsamlı bir araştırma yapılmasına rağmen başka bir yuva bulunmaması, üremenin henüz tam anlamıyla başlamadığını göstermektedir.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

= Tavukgiller, Kara Kuşları
<tavukgiller-kara-kuşları>
== Orman Horozu
<orman-horozu>
#emph[Lyrurus tetrix], Black Grouse

#strong[#emph[Türkiye'de soyu tükenmiştir. Eskiden lokal olarak az sayıda bulunan yerli türdü.]]

Relikt bir popülasyon, 19. yüzyılın sonuna kadar İstanbul çevresinde devam etmiştir @kasparek1990a, ancak anlaşıldığı kadarıyla avlanma sonucunda soyu tükenmiştir. Türkiye'de yaşadığı ilk iki bilim insanı tarafından tespit edilmiştir @rigler1852@tchihatchef1864. Son olarak İstanbul Alemdağ çevresinde bulunduğu düşünülmüş @reiser1904 ve şehirde satılan, nereden geldiği bilinmeyen ölü erkek bireyler tespit edilmiştir @matheydupraz1920. Aynı dönemde Bulgaristan popülasyonunun da ciddi oranda azaldığı kaydedilmiştir @elwes1870\; bu durum muhtemelen avcılığa bağlanmaktadır. Tür burada da uzun süreden beri tükenmiş durumdadır. Genel olarak türün küresel yayılış alanı kuzey ve batıya doğru daralmıştır @hagemeijer1997@madge2002@handrinos1997. Yunanistan'da 1935 yılından bu yana Selanik ve Rodop Dağları çevresinden dört kayıt bulunmaktadır.

#box(image("images/harita_Lyrurus tetrix.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Kuzey Avrasya'daki orman kuşağında yuvalayan yerli bir türdür.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de yaşamış popülasyon muhtemelen nominat #emph[tetrix] alttürüne aittir. Literatürde #emph[Tetrao] cinsi altında da sınıflandırılmıştır.

== Dağ Horozu
<dağ-horozu>
#emph[Lyrurus mlokosiewiczi], Caucasian Grouse

#strong[#emph[Lokal olarak az sayıda bulunan yerli bir türdür.]]

Doğu Karadeniz Dağları'nın kuzey yamaçlarında bulunur. Ağaç sınırının üstündeki 1800-3000 metre arasındaki ormangülü (#emph[Rhododendron]) örtüsünde yaşar. 3000 metre üzerinden gelen üreme kayıtları @baskaya2003 doğrulama gerektirir; ancak, neredeyse yerleşim yerlerine yakın (muhtemelen 15 kilometreye kadar) ve sonbahar ile kış mevsimlerinde düşük yüksekliklerde, ağaç sınırının altında ve muhtemelen özellikle şiddetli soğuklarda daha da düşük yüksekliklerde bulunurlar. Yayılış, bodur ormangülü #emph[Rhododendron] ile alpin çayır kuşağının altındaki huş (#emph[Betula]) içeren yamaçlar üzerine yoğunlaşmıştır @atkinson1995.

Artvin'in güneydoğusundan Gürcistan sınırı üzerinde Posof'a kadar Yalnızçam Dağları'nda dar bir alanda bulunurlar. Yerel halktan alınan bilgiler ışığında Gümüşhane'nin batısında, Giresun çevresinde ve muhtemelen Bingöl'e kadar güneyde, Cilo Dağları'nda bulunması olasıdır.

Türün lokal olarak nadir ya da Doğu Karadeniz kıyı şeridi boyunca yaygın yerli olduğu gösterilene kadar, geçtiğimiz yıllar içerisindeki kayıtlarda görülen aşırı düzeydeki yetersizlik ile özellikle 1980 öncesi kayıtlardaki eksiklik, türün Türkiye'de çok az bilinmesine neden olmuştur. G. Neuhäuser, Eylül 1943 tarihinde yüksek olasılıkla Türkiye için ilk kayıt olan bir çift huş tavuğunu Rize ve Erzurum arasındaki dağlardan toplamıştır @kumerloeve1961.

Türkiye popülasyonunun muhtemelen %90'ının görüldüğü Kaçkar Dağları'nda, özellikle Sivrikaya çevresinde, 1993 yılında gerçekleştirilen gözlem çalışmalarında kur yapma amacıyla bir araya toplanan (lek poligini) 134 erkek gözlenmiştir. O tarihlerde yapılan tümevarımla toplam popülasyonun 2000 bireyden fazla olduğu tahmin edilmiştir @magninyarar1997. Türkiye popülasyon büyüklüğü, son zamanlardaki çalışmalara göre 1508-2675 birey arasında ölçülmüş ve tür 45 coğrafi yerde kaydedilmiştir @isfendiyaroglu2007. Bu coğrafi yerlerin 29 tanesi yakın bir zaman dilimi içerisinde keşfedilmiştir. Bunlardan 4 tanesi nispeten ayrık popülasyonlardır. Türün yayılış sınırlarını ve popülasyon büyüklüğünü tam olarak belirlemek için bilgisayar modellemesi kullanılmıştır @gottschalk2007. Ancak, modellemenin sonuçları bilinen ve yayılış haritasında gösterilen alanı genişletilememiştir. Bununla birlikte 4900 bireylik popülasyon tahmini, önceki en iyimser tahminlerden bile çok yüksek olmuştur.

Türkiye popülasyonu, yaylaların tatil konutlarına dönüşmesi sonucunda artan yol inşaatları nedeniyle yaşam alanlarının terkedilmesinden etkilenmekte ve nesli tehlike altına girmektedir. Daha az ölçüde avlanma baskısından (özellikle sonbahar döneminde görülen bir problem) ve tür için bir tehdit kaynağı olarak listelenen aşırı otlatma bugün kaydedilir ölçekte değildir; ancak, bu durumun izlenmesi gereklidir. Türün popülasyonlarının dengede ya da azalmakta olup olmadığını ortaya koymak için türün popülasyonu ve yayılışı ile ilgili tarihsel bilgiler yetersiz düzeydedir; ancak, popülasyonların azalmasından şüphelenilmektedir.

#box(image("images/harita_Lyrurus mlokosiewiczi.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Türkiye'de sadece iki yuvanın en iyi bilindiği lokalite, Sivrikaya'da (Rize) bulunmuştur. İlk yuva 2800-3000 metrede, bodur #emph[Rhododendron] çalılarının bulunduğu 3 hektarlık bir alanda yer almıştır. \
#strong[Yuvası:] Yuva, yoğun, kısa (1 metre) ve çok dallı çallılarda iyice gizlenmiş olup, kökten çıkan dalların arasında, zeminde sığ bir çanak şeklinde yapılmış, kuru dallar ve birkaç kuru #emph[Rhododendron] yaprağıyla astarlanmıştır. \
#strong[Yumurta sayısı:] Bu yuvada 6 Temmuz 1991 tarihinde 5 yumurta kaydedilmiştir @templelang1991. \
#strong[Üreme dönemi:] Erkekler, özellikle şafak ve gün batımında, eşeylerin çiftleşme amaçlı karşılaştığı alanlarda bir araya gelerek kur gösterileri (nümayiş) yaparlar. Diğer kayıtlarda dişinin uçarak uzaklaştığı bir yuvada 12 Temmuz 1993 tarihinde 4 yumurta görülmüş ve bir yumurta kabuğu 11 Haziran 1997 tarihinde bulunmuştur. Bir erişkin dişi ile tam gelişmemiş iki genç, 12 Haziran 2003 tarihinde Ardahan, Posof'da gözlenmiş ve yumurtlama zamanının mayıs başında başladığını göstermiştir. Başka yerlerde, yaygın kuluçka küme büyüklüğü 5-6 (2-10) adettir. Ermenistan'da, 30 Mayıs 1984'te bulunan bir yuva 8 yumurta içermiş ve bu yuvada ilk yumurtanın 21-23 Mayıs 1984 tarihinde bırakıldığı belirlenmiştir. Bir diğer yuva 20 Mayıs 1985 tarihinde yumurta içermekte olup, ilk yumurta 13-16 Mayıs 1985 tarihinde bırakılmıştır. Bir dişi üç genç bireyle (ergin büyüklüğünün %25'ine ulaşmış) birlikte 5 Haziran 1980 tarihinde ve bir diğeri 26 Temmuz 1980 tarihinde tamamiyle büyümüş 5 genç içermektedir (Adamian ve Klem 1999). Ermenistan'dan üreme döneminin daha erken gösteren kayıtlar, Türkiye kayıtlarının normal üreme dönemini yansıtıp yansıtmadığı hakkında bazı şüpheleri ortaya koymuştur.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür. Rusca literatürde çoğunlukla #emph[Lyrurus] cinsi altında, Batı Avrupa'da #emph[Tetrao] altında sınıflandırılmıştır. Farklı uygulamaların özeti için bkz. @gokhelashvili2003.

== Çilkeklik
<çilkeklik>
#emph[Perdix perdix], Grey Partridge

#strong[#emph[Lokal olarak az sayıda bulunan bir yerli türdür.]]

Özellikle ovalardaki tarım alanlarında, uzun boylu ot topluluklarının kenarlarında ve 2250 metreye kadar birincil yarı step alanlarda ürer. Özellikle İç Anadolu ve Doğu Anadolu'nun kuzey kısımlarında ve Karadeniz Bölgesi'nin iç kısımlarında yuvalar. Güney Anadolu'daki yayılış alanının çoğunda ise çok nadir ve lokaldir.

Geçtiğimiz 20 yıl içerisinde tarımın yoğunlaşması, aşırı otlatma ve avlanma nedeniyle popülasyonu önemli derecede azalmıştır. Trakya'da yabani nesli tükenmiş olup, çeşitli kurum ve kuruluşlar tarafından nüfusu takviye amaçlı genetik yapısı farklı olan yetiştirilmiş kuşlar salınmış, ancak bu kuşlar yeni bir nüfus oluşturamamıştır. Belki de Bulgaristan'daki yabani kuşların Türkiye'ye kendiliğinden gelmesi beklenmelidir.

#box(image("images/harita_Perdix perdix.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Genellikle açık tarım alanlarında ürer. \
#strong[Yuvası:] Türkiye'deki bir yuvası betimlenmemiştir, ancak diğer yerlerden gelen bilgilere göre yuva, ot ve ölü yapraklarla astarlanmış, genellikle vejetasyon içerisine iyi bir şekilde gizlenmiş ve zeminde yer alan sığ oyuklar şeklindedir. \
#strong[Yumurta sayısı:] 19 yumurta koyabilir. Diğer yerlerdeki yaygın kuluçka küme büyüklüğü 9-20 (23) arasındadır. Bazen iki dişinin aynı kuluçkayı paylaşması nedeniyle büyük kuluçkalar da kaydedilebilir. \
#strong[Üreme dönemi:] Mayıs ayında yumurtlamaya başlar. Yavrular: #strong[İÇA:] 11 Haziran 1977 tarihinde bir genç ile bir ergin Mogan Gölü'nde, 16 Temmuz 1977 tarihinde 8 genç Emir Gölü'nde ve 28 Ağustos 1984 tarihinde 7 bireylik bir aile Çavuşcu Gölü'nde kaydedilmiştir. #strong[GDA:] Diyarbakır yakınlarında, 16 Mayıs 1999 tarihinde gevenle (#emph[Astragalus sp.]) örtülü bir yamaçta on yumurta içeren bir yuva 27 Mayıs'ta 19 yumurta içermiştir @karakas2002.

#strong[Alttürler ve Sınıflandırma]

Trakya'da nominat #emph[perdix] alttürü, Anadolu'da ise #emph[canescens] alttürü bulunmaktadır. Doğaya salınan farklı orijinden bireylerin yerel kuşlarla karışması nedeniyle türün yayılış alanı içindeki coğrafi varyasyonu oldukça karışıktır @madge2002.

== Sülün
<sülün>
#emph[Phasianus colchicus], Common Pheasant

#strong[#emph[Lokal olarak az sayıda bulunan yerli türdür.]]

Türkiye'deki yerli popülasyonun yayılış alanı büyük ihtimalle Batı ve Orta Karadeniz kıyısındaki kıyısal ormanlar, "psödomaki" olarak bilinen Akdeniz bitki örtüsü ve fundalıklarla sınırlıydı. Tüm bilinen tarihi ve güncel lokaliteler haritalanmıştır @kasparek1988c, bu yayılış noktalarının çoğu Güney Marmara ve Orta Karadeniz'de yoğunlaşmış olup, en batıda Trabzon'a kadar doğuya ulaşır. Türkiye'deki yerli bir popülasyonun varlığı bir dönem şüpheyle karşılanmışsa da @madge2002, İstanbul bölgesinden 1792'den sonra gelen kayıtlar yerli popülasyonun varlığını desteklemiştir @kasparek1988c.

Doğal nüfusu neredeyse tamamen kaybolmuştur; yabani kuşların çoğunun soyu av için salınan kuşlara dayanır. Toplam stoktaki yerli kuşların varlığı çok sınırlıdır ve saf yerli kan, devamlı olarak av için salınan yabancı ve karışık kuşların içinde eriyip gitmiştir. Bugün doğal popülasyondan geriye kalanların Sinop bölgesinde ve yakın zamana kadar Kızılırmak Deltası ve çevresinde bulunması olasıdır. İç Anadolu, Ege ve Akdeniz'de görülen sülünler, şüphesiz doğaya salınan kuşlardan türemiştir.

#box(image("images/harita_Phasianus colchicus.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Kıyısal ormanlar, "psödomaki" olarak bilinen Karadeniz bitki örtüsü ve fundalıklar. \
#strong[Yuvası:] Bu konuda Türkiye'den bir bilgi yoktur. Zemine yuvalar. \
#strong[Yumurta sayısı:] Diğer yerlerde 6-11 yumurta koyar. \
#strong[Üreme dönemi:] Diğer yerlerde mayıs ve haziran arasında yumurta koyar.

#strong[Alttürler ve Sınıflandırma]

Yerli popülasyon, nominat #emph[colchicus] alttürü altında sınıflandırılmıştır @dementev1967@roselaar1995. Hatalı olarak Kuzey Kafkasya'da bulunan #emph[septentrionalis] alttürüne dahil edilmiştir @kumerloeve1961.

== Turaç
<turaç>
#emph[Francolinus francolinus], Black Francolin

#strong[#emph[Güneydoğu Anadolu ve Doğu Akdeniz'de yaygın olarak çok sayıda bulunan yerli türdür.]]

Çukurova ve Göksu Deltaları çevresinde, ayrıca Suriye sınırında Fırat ve Dicle nehirleri boyunca ürer. Doğu Akdeniz popülasyonu en iyi izlenendir. Çukurova popülasyonunun 75 çiftinin Akyatan Gölü çevresinde yoğunlaştığı, toplamda 85 çifte ulaştığı kaydedilmiştir @magninyarar1997. Göksu Deltası'nda, çoğu kumullarda olmak üzere 50 üreme çifti kaydedilmiştir @magninyarar1997. En yaygın bulunduğu bölge olan Güneydoğu Anadolu'da yaklaşık 15 lokaliteden kaydı vardır @welch2004gap.

Doğu Akdeniz'deki popülasyonu dikkate alınarak mevcut durumu ve ekolojisi derlenmiştir @berk1988. Doğu Akdeniz'deki bazı yerlerde tür için koruma tedbirleri uygulanmıştır. Güneydoğu Anadolu'da ise tarımsal faaliyetlerin artması sonucu hem sayılarının arttığı hem de yayılış alanının genişlediği düşünülmektedir.

Eskiden Güneydoğu Marmara ile Ege Bölgesi'nin güney kıyılarının bazı bölümlerinde yerli olarak kaydedilmiştir @kumerloeve1963c. Ancak, her iki bölgede 19. yüzyıl içinde ortadan kalkmıştır. İstanbul Boğazı çevresinden 1850'li yıllardan gelen tek bir kayıt vardır. Göller Bölgesi ile Anti-Toroslara kadar kuzeyde, 600 metreye kadar oldukça lokal olarak kaydedilmiştir @kumerloeve1961. Ekim 2003 tarihinde Tavas, Denizli çevresinden muhtemelen tutsak bir bireyin kaçması sonucu güncel bir kayıt gelmiştir. 1960'lı yıllarda Köyceğiz Gölü'ndeki kayıtlar, Batı Akdeniz'deki son kayıtlardır. 1990'lı yıllara kadar Akdeniz bölgesindeki yayılışı İçel, Adana, Osmaniye ile sınırlıydı. Sayıları artan kuşların yavaş yavaş Batı Akdeniz'e doğru ilerlediği kaydedilmiştir. Örneğin Antalya Havaalanı arazisinde 2010'dan beri kaydedilmektedir.

#box(image("images/harita_Francolinus francolinus.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Çalı ve çalı dışındaki bitki örtüsüne sahip kumullar ile ot, çalı ve bodur bitkilerin arasındaki oyuklarda yaşarlar. Ayrıca, olgunlaşmamış çalıların bulunduğu nemli (ıslak olmayan) alanlar, nehir kıyıları ve sık ılgın (#emph[Tamarix]) çalılarından oluşmuş sık topak şeklindeki çalılık alanlarda ve mısır tarlalarında ürerler. Kum tepelerinde (her 2-5 hektarda bir erkek) ve tarım alanlarında (15-30 hektarda bir erkek) yüksek yoğunluktadırlar @berk1988. \
#strong[Yuvası:] Göksu Deltası'ndaki kum tepelerinde 17 Haziran 1992 tarihinde bulunan eski yuva, astarlanmamış, kum içerisinde birkaç bitki parçasıyla çevrelenmiş sığ bir oyuk şeklindedir ve zemininde bir tutam ot içermektedir. \
#strong[Yumurta sayısı:] Türkiye dışında yumurta sayısının genellikle 8-12 arasında olduğu bilinir. \
#strong[Üreme dönemi:] Mart sonu ve nisan arasında yumurta bırakır. Yavrular mayıs ortasında dolaşmaya başlar ve temmuz ortasına kadar görülebilir. Manchester Müzesi'ndeki üç yumurta (tamamlanmamış bir kuluçkadan) İzmir yakılarından 10 Mayıs 1899 tarihinde alınmıştır. Tring Doğa Tarihi Müzesi'ndeki dört yumurtanın ikisi Mersin'den 7 Mayıs 1884 tarihinde ve diğer ikisi 15 Mayıs 1899 tarihinde Anadolu'da bilinmeyen bir lokaliteden alınmıştır. #strong[AKD:] Göksu Deltası'ndaki kum tepelerinde, 17 Haziran 1992 tarihinde muhtemelen bir önceki yıldan kalmış bir yuva kaydedilmiştir. Yuvada güneşten etkilenmiş ve solgun renklere sahip yumurta kabukları bulunmuştur. Yuva, astarlanmamış, kum içerisinde birkaç bitki parçasıyla çevrelenmiş sığ bir oyuk şeklindedir ve zemininde bir tutam ot içermektedir. Göksu'da, en azından 1-2 günlük 7 genç ile bir dişi 5 Mayıs 2004 tarihinde kaydedilmiştir. Bu kayıt, ilk yumurtanın 9 Nisan'da bırakıldığını göstermektedir. Bir ergin ile bir genç kuş 20 Temmuz 1986 tarihinde gözlenmiştir. Çukurova'da, yerel halk yavruları 10 Mayıs 1986 tarihinde yakalamıştır (yaygın oldukları bildirilmiştir). Bu tarih, yumurta bırakma zamanının yaklaşık nisan ortasında olduğunu göstermektedir. Ötüşteki artış ise nisan ayının ikinci yarısı ile mayıs ayının ilk yarısında tepe yapmaktadır @berk1988. Eski avcıların kayıtlarına göre "dişi kuşlar mart sonu ile nisan ayı içerisinde yuvaları ve yumurtaları ile meşguldürler" @banoglu1953. Yumurtalar, keklik (kınalı keklik) yumurtaları büyüklüğünde ve açık yeşil renktedir; Seyhan ve Ceyhan kıyılarındaki sık örtüşe sahip bodur ağaçlıklar arasında zemine bırakılır. Dörtyol ve Alik civarında, dik ve derin vadilerdeki kayalıkların sınırlarına ya da adalar arasındaki saz yatakları araları ile bodur ağaçlıklar ve çalı topakları içine yuvalanırlar. Eskiden Adana civarındaki düzlüklerde çok sayıda görülürlermiş. #strong[GDA:] Birecik'in güneyindeki geniş mısır tarlalarında erginlerin sesleri duyulmuş, üredikleri kesin olarak kaydedilmiştir.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur. Meinertzhagen tarafından Amik Gölü bölgesinden tanımlanmış #emph[billypayni] alttürü sinonim olarak kabul edilmektedir.

== Urkeklik
<urkeklik>
#emph[Tetraogallus caspius], Caspian Snowcock

#strong[#emph[Yüksek dağlarda lokal olarak az sayıda bulunan yerli türdür.]]

Yüksek dağların yerlisidir. Üç önemli popülasyon Doğu Karadeniz Bölgesi, Yüksekova ile Hakkari'ye ve İran sınırına kadar uzanan Doğu Anadolu'nun dağlık kısımları ve en batı sınırını oluşturan Toroslar olarak belirtilebilir. En batıda Toros silsilesinde Bolkar ve Melendiz dağlarında kaydedilmiştir. Yaz aylarında genellikle 2400 metrenin üzerinde kaydedilir. Ancak yazın Mersin'in kuzeyindeki dağlarda 2000 metrenin altında da görülmüştür. Ara sıra sonbahar döneminde 60 bireye kadar büyük gruplar oluştururlar; bu grupların bazıları kış ortasında alçak bölgelere inenler olabilir.

Eski kayıtlarda, en batıda Geyik Dağı, Alanya'nın kuzeyi ve Antalya'nın dağlık alanlarında gözlenmiştir @kumerloeve1961. Daha batıda Akdağlar ve Beydağları'ndaki sürekli kar örtüsüne sahip zirveler de uygun yüksekliğe sahip alanlardır.

#box(image("images/harita_Tetraogallus caspius.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Özellikle 2400 metre üzerinde, alpine çayırlarla kaplı, dik kayalıkların ve yarların olduğu, yıl boyunca karlı bölgelerde ürerler. \
#strong[Yuvası:] Karanfil Dağı'nda 2100 metre yükseklikte 23 Nisan 1876 tarihinde, bir dişi çıkıntılı bir kaya ve ardıç kökü ile sarılmış bir yuvanın bulunduğu dik bir su yolundaki küçük bir kaya üzerinden uçmuştur. Yuva, taşlı toprak üzerinde derin yuvarlak bir oyuk olup yetersiz düzeyde kuru otlar ve birkaç kuş tüyüyle astarlıdır. Bu yuvada altı yumurta kaydedilmiştir. 25 Nisan 1876 tarihinde Bolkar Dağları'ndaki iki yuva benzer özelliklerde kaydedilmiştir. Ancak bir tanesi yeşil köknar ibreleri ile astarlanmıştır. \
#strong[Yumurta sayısı:] Yukarıdaki üç yuvada altı ve dört yumurta kaydedilmiştir. İki yumurta Manchester Müzesi'nde, diğerleri ise Tring Doğa Tarihi Müzesi'nde saklanmaktadır. \
#strong[Üreme dönemi:] #strong[KAR:] Sivrikaya'da (Rize) beş genç ile bir ergin 12 Haziran 1989 tarihinde küçük karlı alanları geçerken kaydedilmiştir. #strong[AKD:] Nisan 1876 tarihinde Toroslar Aladağlar bölgesindeki yuvaları araştırmıştır @danford1877 . 8 Temmuz 1986 tarihinde Aladağlar'da 1-2 haftalık 5 genç ile bir ergin gözlenmiştir. İlk yumurta 21 Mayıs tarihinde bırakılmış olmalıdır. Çil Keklik büyüklüğünde 5-6 ferik ile bir dişi 3-5 Ağustos 1967 tarihinde kaydedilmiştir @vielliard1968resultats. 19 Ağustos 2000 tarihinde, bazıları erginlerden belirgin derecede küçük 3-4 ferikli en azından üç aile grubu kaydedilmiştir.

Ermenistan'da ortalama yumurtlama dönemi 10-15 Mayıs, kuluçka dönemi ise 20-30 Mayıs arasındadır. Yavrular 13 Haziran tarihinde kaydedilmiştir @adamian1999. Gençlere ait bazı erken kayıtlar ilk yumurtanın 23 Nisan veya öncesinde bırakıldığını ortaya koymaktadır. Nisan sonu ile mayıs başını içeren iki kayıt Danford'un Türkiye'de kaydettiği yuva tarihleri ile kabaca uyum göstermektedir.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür. Eskiden Hakkari ve Zagros Dağları'ndaki kuşların #emph[semenowtianschanskii] (Zarudny, 1908), Toros Dağları'ndaki kuşların #emph[tauricus] (Dresser, 1876) ve Erzurum bölgesindeki kuşların #emph[challayei] isimli ayrı alttürler olduğu düşünülmüştür.

== Kum Kekliği
<kum-kekliği>
#emph[Ammoperdix griseogularis], See-see Partridge

#strong[#emph[Güneydoğu Anadolu'da yaygın olarak çok sayıda bulunan yerli türdür.]]

İlk zamanlarda çoğunlukla Suriye sınırına 50 km mesafedeki 15 lokaliteden bilinirdi. Ancak, Güneydoğu Anadolu'da yürütülen kapsamlı bir biyoçeşitlilik araştırması, uygun habitatların bulunduğu alanlarla birlikte türün hemen hemen 50 coğrafi yerde bulunduğunu göstermiştir @zeydanli2005gap. Çoğunlukla az sayıda gözlenir, ancak sonbaharda 40 bireylik gruplar kaydedilmiştir.

#box(image("images/harita_Ammoperdix griseogularis.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Güneydoğu Anadolu'da zayıf vejetasyon örtüsüne sahip kurak kayalık alanlarda üremektedir. \
#strong[Yuvası:] Türkiye içerisinde yuva ve yumurta tanımlaması yapılmamıştır; ancak, diğer yerlerde yuvalar, yuvanın bulunduğu yere yakın bitki materyalleri ve otlarla astarlanmış, genellikle taş ya da bir tutam bitki ile çevrelenmiş şekilde zeminde, toprağa kazılmış halde bulunur. \
#strong[Yumurta sayısı:] Kuluçka küme büyüklüğü genellikle 8-12 arasındadır, bazen yumurta sayısı 16'ya kadar çıkabilmektedir. \
#strong[Üreme dönemi:] Nisan ayında çiftler kaydedilmiştir. 5-7 Haziran 1973 tarihinde Halfeti'de kaydedilen üç haftalık üç genç birey ile bir ergin, diğer yerlerde kaydedilen ilk yumurtayı koyma tarihiyle çelişmeyecek şekilde ilk yumurtaların nisan ortasında bırakıldığını göstermektedir. 2004-05 yıllarında Birecik'te birkaç genç birey kaydedilmiştir. 11 Ağustos 2001 tarihinde Cizre'de bir aile kaydedilmiş, gençlerin boyu hakkında detaylar verilmemiştir.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Bıldırcın
<bıldırcın>
#emph[Coturnix coturnix], Common Quail

#strong[#emph[Yaygın olarak çok sayıda bulunan bir yaz konuğu ve geçit türüdür. Nadiren az sayıda kışlar.]]

Çoğunlukla tahıl ekilen kurak tarlalar, bozkırlar, çayırlar ve yüksek otların bulunduğu dağlık bölgelerin yanında yoğun vejetasyonlu kumullar gibi alanlarda bulunur. Özellikle İç Anadolu'da oldukça yaygın olarak ürer, ancak hububat tarımının nispeten az olduğu kıyısal bölgelerde oldukça azdır. Doğu kesimlerinden en azından 2300 metreye kadar üreyebilir. Üreme ve geçit sırasında özellikle tahıl ekilen arazilerde bulunur.

Üreme dışında, geçit sırasında tüm ülkede bol sayıda bulunur. İlkbahar geçişi mart sonu ve nisan arasında, sonbahar geçişi ise ağustos sonu ve eylül boyunca, hatta kuzey bölgelerinde daha erken gerçekleşir. İlkbahar göçünde kuzey bölgelere mart sonu itibariyle ulaşır. Sonbahar göçünde Karadeniz kıyılarında kasıma kadar göçünün sürdüğü bilinir @albrecht1986. Kasım sonunda, 26 Kasım 2003'te Seyfe Gölü'nde ve 20 Kasım 2010'da Nallıhan Kuş Cenneti'nde kaydedilmiştir @balmer2004a. Az sayıda Ege ve Akdeniz kıyılarında kışlar, bu durum geçişin sonunun tespitini zorlaştırır.

Tarım arazilerinde yaşayan diğer kuşlar gibi, tarımın yoğunlaşması, tahıl dışındaki ürünlerin çoğalması ve yasadışı avcılık sonucunda sayıları ülke çapında azalmıştır. Göçmen kuşlar aşırı av baskısı altındadır ve özellikle Karadeniz bölgesinde yasadışı teyp kullanarak yakalama faaliyetleri devam etmektedir.

#box(image("images/harita_Coturnix coturnix.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Özellikle hububat tarlalarında yuvalar. \
#strong[Yuvası:] Ürediğini kanıtlamak son derece zordur ve Türkiye'de henüz bir yuvası tespit edilmemiştir. Türkiye dışında, yerdeki düzce bir çukuru ot ve yakındaki bitkisel materyal ile astarlar. \
#strong[Yumurta sayısı:] Genellikle 7-12, istisnai olarak 6-18 arasında yumurta koyar. \
#strong[Üreme dönemi:] Genellikle nisan sonu ile mayıs ortası arasında yumurta koyar. #strong[MAR:] Uluabat Gölü'nde 22 Mayıs 1966'da yavrular gözlenmiştir. Çoğu bölgeye ilkbaharda nisan ortasından gelir ve tüm yavru gözlemleri üremenin alana varıştan hemen sonra başladığını gösterir. Ağustos'ta duyulan kuşlar gecikmiş bir üremenin göstergesi olabilir. #strong[GDA:] Birecik'te 4 Haziran 1993'te tamamen palazlanmış 3 haftalık 9 yavru, hasat döneminde biçilmiş mısırın altında saklanırken görülmüş ve köylüler tarafından yenmek üzere yakalanmıştır. 5 Haziran 1993'te görülen başka 6 kuş, yumurtlama tarihinin yaklaşık 20 Nisan'da olduğunu gösterir. Suriye'de yavrularıyla dolaşan bir çift temmuz ayında gözlenmiştir @baumgart1995.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur.

== Kınalı Keklik
<kınalı-keklik>
#emph[Alectoris chukar], Chukar Partridge

#strong[#emph[Yaygın olarak çok sayıda bulunabilen bir yerli türdür.]]

Yaygın, Trakya ve Batı Karadeniz kıyı şeridinde nadir, Türkiye genelinde ise oldukça bol bulunan yerli bir kuş türüdür. İç bölgelerde genellikle 700-2000 metre arasında görülür ve genellikle kurak, kayalık tepe ve dağlık alanlarda, en az 2800 metreye kadar kaydedilmiştir. Hemen hemen 40 bireye kadar çıkabilen ve gençleri de içeren oldukça büyük sürüler gözlenmiştir.

Geçmişte özellikle Hatay ve Doğu Karadeniz kıyı şeridi gibi bölgelerde oldukça bol olarak kaydedilmiş, ancak son zamanlarda belirgin bir azalma göstermiştir.

#box(image("images/harita_Alectoris chukar.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Bodur çalılar ile kurumuş tarım alanlarının bulunduğu kayalık ve taşlık tepelerle oldukça kurak ve çorak alanlarda ürer. \
#strong[Yuvası:] Yerde yuvasını bir çalı ya da bitki dibine gizler. \
#strong[Yumurta sayısı:] Genellikle 5-22 arasında değişmekle birlikte, bazı bölgelerde daha düşük ya da yüksek sayılarda yumurta kaydedilmiştir. \
#strong[Üreme dönemi:] Genellikle mayıs sonu ile haziran başı arasında yumurtlamaya başlar. Yavrular, temmuz ayı ortasına kadar gözlemlenebilir. Farklı bölgelerde kaydedilen üreme dönemleri, ortam koşullarına bağlı olarak değişiklik gösterebilir. #strong[EGE:] Kuluçkadaki bir ergin birey, İzmir yakınlarında 14 yumurta içeren bir yuvadan @ramsay1914 7 Mayıs 1951 tarihinde alınmıştır. Yuva, yuvanın sahibi olan kuşun çok sayıda tüyü ile birlikte çalı benzeri bitkilerle astarlanmış ve dikenli meşe ile de korunmuştur. Yumurtalar krem ile kırmızı arasında bir renklenme ile kırmızımsı küçük beneklenmeler gösterir @mcneile1950. #strong[AKD:] 11 Mayıs 1899 tarihinde Acıgöl'de 5 yumurtalı bir yuva kaydedilmiştir; dişinin yumurtlamaya devam edeceği düşünülmüştür @selous1900. Karadağ'da, taze yumurtalar içeren iki yuva 1907 yılının Mayıs sonunda kaydedilmiştir. Bu yuvada taze yumurtalar haziran ayında da bulunmuştur. Bir ergin ile 5-6 iyi gelişmiş genç birey, Burdur ve Bucak arasındaki geçitte 13 Temmuz 1968 tarihinde kaydedilmiştir @rokitansky1971. #strong[İÇA:] 22 yumurta içeren bir yuva, 24 Mayıs 1998 tarihinde Ereğli yakınlarındaki bir kraterin, bir çalı ile sarılmış kaya çıkıntısı üzerinde kaydedilmiştir. 20 yumurtadan 9 tanesi nisan ayı sonunda bırakılmıştır (Banoğlu ve Burr 1953). #strong[DOA:] Nemrut Dağı'nda (Bitlis), 9 Haziran 2004 tarihinde sabah saatlerinde 15 yumurtalı bir yuva kaydedilmiştir. Ancak, günün ilerleyen saatlerinde, ergin bir birey yuva üzerine oturmuştur. Muhtemelen bu tarih inkübasyonun ilk günü olarak belirtilebilir. Yuva, kısmen yaprak döken ormandaki bodur çalılar altında bulunur. Zemine derin bir şekilde kazılmış ve birkaç adet ergin kuş tüyü ve otların kökleri ile astarlanmıştır. #strong[GDA:] Kuluçka kayıtları 2 Haziran 2001 tarihinde Işıklı'da (Gaziantep) gençleri içermektedir ve 22 Haziran 1966 tarihinde Menemen (İzmir) yakınlarında 6, 7 ve 8 yavrulu bireyleri içermektedir. Akdeniz Bölgesi'nde 22 Mayıs 1989 tarihinde bir kuluçka ve 30 Haziran 1966'da Aladağlar'da birkaç günlük genç bir birey kaydedilmiştir. Birkaç kuluçkanın birleşmesi sonucunda oluşan ve yaygın olarak gözlemlenmeyen büyük kuluçkalar, tek bir ergin ile birlikte 13 Ağustos 1967 tarihinde Kızılcahamam'da (Ankara) kaydedilmiştir @baris1984.

#strong[Alttürler ve Sınıflandırma]

Türkiye'nin güneyi boyunca #emph[cypriotes] alttürü görülmektedir. Kuzeyde #emph[kleini] ve Doğu Akdeniz bölgesine özgü #emph[sinaica] alttürünün etkili olduğu bölgede, Güneydoğu Anadolu'da #emph[kurdestanica] alttürü bulunmaktadır. Tür içerisindeki coğrafi varyasyon konusu ile ilgili kesin bir çıkarım yapılamamıştır; ancak gözlemlenen formların tamamı, güçlü bir şekilde gradient ile birlikte belirgin klinal yapı göstermektedir @madge2002.

== Kaya Güvercini
<kaya-güvercini>
#emph[Columba livia], Rock Dove

#strong[#emph[Menşei karışık olarak; yaygın ve çok sayıda bulunan yerlidir.]]

Şehir güvercini formunda ülke çapında ve özellikle İstanbul, İç Doğu ve Güneydoğu Anadolu'da yaygın ve çok boldur. Saf veya safa yakın kaya güvercini formu çok daha az sayıda bulunur ve güneyde 3000 m. kuzeyde ve doğudan 4000 metreye kadar yükseklikteki kayalık ve dağlık arazide ve deniz kıyısındaki yarlarda bulunur. Saf popülasyonların tespit edilebilmesi için gözlemcilerin yabani dondaki güvercin gruplarını daha ayrıntılı tanımlamaları gerekmektedir. Buna rağmen en azından Güneydoğu Anadolu'da şehir kuşları ve insan yerleşimlerine yakın üreyebilen yabani kuşları birbirinden ayırt etmek mümkün görünmemektedir.

#box(image("images/harita_Columba livia.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Çoğunlukla 20 çiftten az küçük koloniler halinde, bazen de tek başına yuvalar. Kaya oyukları, yarlardaki mağaralar, serpme kaya yığınları, binalar, harabeler, yer kuyuları ve yerde çalıların altına yuva yapar. Bazen yuvalama alanını diğer kuşlarla, özellikle küçük karga ile paylaşır. \
#strong[Yuvası:] Dallardan, ince bitki gövdelerinden ve köklerden oluşan ince bir platformdur. \
#strong[Yumurta sayısı:] 15 yuvada 2 yumurta, olası tamamlanmamış kuluçkalarda ise 2 yuvada 1 yumurta kaydedilmiştir. İki yuvada ikişer yavru görülmüştür. \
#strong[Üreme dönemi:] Şehir güvercini muhtemelen yıl boyu yuvalar. Kaya güvercini mart ayından itibaren yumurta koyar, yavrular mayıs sonu yuvadan ayrılır. #strong[EGE:] 8 Mayıs 1950'de Çeşme açıklarındaki Ilıca Adası'nda, düz bir zeminde bir çalının altında içinde uzun süredir kuluçkaya yatılan iki yumurta olan bir yuva görülmüştür @mcneile1950. 14 Mayıs 1899'da, İzmir yakınlarındaki bir harabede içinde iki yumurta bulunan bir yuva kaydedilmiştir @selous1900. #strong[İÇA:] 22 Mayıs 2007'de aynı yuvada hem tam gelişmiş iki yavru hem de iki yumurta görülmüştür @ramsay1914. Bunun, iki çiftin üremesinden kaynaklandığı ve muhtemelen yavruların kendi yuvalarından ayrıldığı düşünülmüştür. 7 Mayıs'ta görülen yeni palazlanmış yavru, yumurtlamanın mart ortasında başladığını göstermektedir. Bolluk Gölü'ndeki bir adada bulunan kolonide, kuşlar yerde çalıların altında suna yuvalarıyla karışık olarak yuvalamışlardır. Hem 24 Haziran 1992'de hem de 7 Mayıs 1993'te yaklaşık 5 yuvada ikişer yumurta görülmüş olup, bu durum türün yılda iki kez kuluçkaya yattığını açıkça göstermektedir. #strong[DOA:] 9 Haziran 2001'de Balık Gölü'nde birçok çift, küçük karga ile birlikte gölün ortasındaki bir adadaki kaya yığınları arasında yuvalamıştır.

#strong[Alttürler ve Sınıflandırma]

Türkiye' genelinde nominat alttür bulunur. Bunun yanında @kumerloeve1961 kuzeydoğuda gaddi alttürü ve güneyde #emph[palaestinae] alttürü olduğunu düşünmüş, Roselaar @cramp1985 Türkiye ve Kafkas popülasyonları için ayrı bir alttür tanınması önermiştir.

== Gökçe Güvercin
<gökçe-güvercin>
#emph[Columba oenas], Stock Dove

#strong[#emph[Seyrek ve lokal yaz konuğu, nispeten yaygın ve az sayıda geçit kuşu ve kış konuğudur.]]

Ülkenin zengin ormanlı dağlık bölgelerinde en azından 2100 metreye kadar çıkan oldukça az sayıda ve yerel dağılım gösteren yerli ve yarı göçmendir. Istranca Dağları'nda büyük ihtimalle üremektedir, Mayıs, Ağustos 2009 arasında yapılan çalışmada bazı ihtimaller gözlenmiştir (Özkan 2010). Bulgaristan tarafından ürediği bilindiği için büyük bir sürpriz değildi @milchev1994. Doğu Karadeniz'in bazı bölgelerinde 400 metrenin altında nispeten bol olarak ürer @faldborg1994. Geçit sırasında daha yaygındır. İstanbul Boğazı'ndan Eylül ortası ile Ekim sonu arasında en yüksek sayıda da Ekim ortasında geçit yapar @porter1983@beaman1986. Kuzeydoğu Anadolu'da en yüksek sayılarda Ekim ortası ile sonu arasında geçer @beaman1986. İlkbaharda geçişinde Kızılırmak Deltası'nda Mart sonu en yoğun geçer ve geçişi nisan ortasına kadar geçtiği saptanmış olsa da @hustings1994, bu yayındaki çalışma muhtemelen erken göçünü kaçırmıştır. Sonbahar göçünde güney kıyılarında ve hatta doğu bölgelerinde de bulunabilir. Kışın batı ve orta bölgelerinde özellikle İç Anadolu'nun batı, güneybatı ve güney kısımlarında Toros Dağları eteklerinde yer yer kayda değer sayılarda olabilir. Üremeyen kuşlar kışlama alanlarında Mayıs ortasına kadar kalabilir.

#box(image("images/harita_Columba oenas.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Bir bilgi yoktur. \
#strong[Yuvası:] Bir bilgi yoktur. \
#strong[Yumurta sayısı:] Türkiye'den bir bilgi yoktur. Muhtemelen 2 yumurta koyar. \
#strong[Üreme dönemi:] Bir bilgi yoktur.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur.

== Tahtalı
<tahtalı>
#emph[Columba palumbus], Common Wood Pigeon

#strong[#emph[Oldukça yaygın ve nispeten çok sayıda bulunan yerli ve yarı göçmen, yaygın ve çok sayıda bulunan geçit türü ve kış konuğudur.]]

Akdeniz Bölgesi'nde en yaygın, İç Anadolu'da seyrektir. Genellikle daha kurak ve çoğunlukla dağlık ibreli ormanlarda ürer, yayılışı seyrek olabilir. Deniz seviyesinde az sayıda ürer, çoğunlukla 900 metrenin üstündedir, en azından 2200 metreye kadar çıkabilir.

Ülke çapında geçit sırasında daha yaygındır, İstanbul Boğazı'ndan geçişi eylül başından ekim başı arasında, dolayısıyla gökçe güvercinden daha erkendir. 2-4 Ekim 1974'te 647 tane sayılmış, 24 Eylül ve 8 Ekim 1973'de de toplam 11.780 kuş sayılmış, en yoğun geçiş 2000 kuşla 2 Ekim'de gerçekleşmiştir. Göçü güney kıyılarında da hissedilir, ancak Akdeniz'deki büyük nehir deltalarında çok seyrektir. Marmara ve İç Anadolu'nun iç bölgelerinde göç sırasında birkaç yüzlük sürüler halinde görülebilir. Kışın yer yer yüksek sayılarda görülebilir, İç Anadolu'da genellikle azdır. Batı ve güneyde kışlayan sürüler iç bölgelerden göç alabilir, Aralık 1969'da Antalya Korkuteli'nde 950, Burdur Gölü'nde 740'lık sürülere rastlanmıştır. İlkbahar göçü mart ortası ve nisan ortası arasında yoğunlaşır, 24-31 Mart 1972'de Manyas Kuşcenneti'nde toplanan yaklaşık 10.000, 19 Kasım 2005'te Sandıklı ve Afyon arasında toplanan 2000 kuş ve Aralık 2004'te Meriç Deltası'nda toplanan binlercesi son derece istisnai bir kalabalık oluşturmuştur. Kışlama alanlarında mayısın ilk haftasına kadar kalabilir.

#box(image("images/harita_Columba palumbus.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Çam ormanları, meyvelik bahçeler ve nehir boyundaki riperyan alanlarda yuvalar. \
#strong[Yuvası:] Türkiye'den bir bilgi yoktur. \
#strong[Yumurta sayısı:] Türkiye'den bir bilgi yoktur. Muhtemelen 2 yumurta koyar. \
#strong[Üreme dönemi:] Nisan ve mayısta gösteri uçuşu yaptığı gözlenmiş, yumurta koyduğu varsayılmıştır. Yavrular mayıstan itibaren görülür. #strong[KAR:] Nisan 1992'de, Kızılırmak Deltası Yörükler Ormanı'nda bazı bireylerin gösteri uçuşu yaptığı kaydedilmiştir. 3 Haziran 1992'de yuva yakınında bir kuş görülmüştür @hustings1994. 16 Haziran 1975'te, Zigana Dağı Torul yakınlarında genç bireyler gözlenmiştir. #strong[GDA:] 3 Mayıs 2004'te, Gaziantep Karkamış'ta gösteri uçuşu gözlenmiştir.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur @roselaar1995. Güneydoğu'da #emph[iranica] alttürü ile bir geçişin görülebilir olduğundan bahseder. Doğuda #emph[iranica] alttürünün #emph[casiotis] alttürüne geçiş yaptığından dolayı #emph[iranica] #emph[casiotis] alttürünün bir sinonimi olabilir @gibbs2001.

== Üveyik
<üveyik>
#emph[Streptopelia turtur], European Turtle Dove

#strong[#emph[Yaygın ve yer yer çok çok sayıda bulunan yaz konuğu ve geçit türüdür.]]

Ülkenin çoğu yerindeki ormanlık ve tarımsal arazilerde genellikle oldukça çok ve yaygın olan bir yaz konuğudur. Batıda daha yaygın, doğuda da oldukça lokaldir. Kızılırmak Deltası'nda 1992'de toplam 600-800 çiftin ürediği tahmin edilmiştir @hustings1994. Karadeniz ve Marmara bölgelerinde 1500 metreye kadar, Toroslar'da 200-1300 metrede, Kuzeydoğu Anadolu'da da 2000 metreye kadar yuvalar. Geçit sırasında daha yaygındır, sıka çok yüksek sayılarda görülür. İlkbaharda nisan başında gelir, ekim başına kadar kalır. İstanbul Boğazı'ndan ciddi ölçekte bir geçiş olmasa da Kuzeydoğu Anadolu ve kısmen Doğu Anadolu'da çok bol sayıda görülür. 1968 Eylül sonunda yüzlercesi Silifke ve Antalya arasındaki Akdeniz kıyısında gözlenmiş, yaklaşık 1000 tanesi 16 Haziran 1975'te Zigana Geçidi ve Trabzon arasında, aynı tarihte yaklaşık 3000-4000 tanesi Erzurum ve Gümüşhane arasında, yaklaşık 2000 tanesi 2 Mayıs 2004'te Birecik'in güneyinde gecelerken gözlenmiştir. İlkbahar geçişi az ölçekte de olsa özellikle kuzey bölgelerinde haziran ortasında kadar devam eder. En erken geliş tarihi 30 Mart'tır. Dönüş temmuzun son haftasında başlar, eylül ayında tepe yapar ve genellikle ekim başında biter. İç Anadolu'da en geç 28 Ekim'de görülmüştür.

#box(image("images/harita_Streptopelia turtur.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Ağaçlık, çitlik ve yüksek çalıların bulunduğu doğal ve tarımsal arazilerde, meyve ve zeytin bahçelerinde, ormanlarda ve orman kenarlarında ürer. \
#strong[Yuvası:] Genellikle bir çalıya veya alçak bir ağaca, yerden 2-4 metre yukarıya yapılır. İnce dallardan örülmüş sığ bir platform olup, hafif çukur ortası otlar ve ince köklerle astarlanır. \
#strong[Yumurta sayısı:] On üç yuvada 2 yumurta, bir yuvada ise 1 yumurta kaydedilmiştir. Üç yuvada 2 yavru gözlenmiştir. \
#strong[Üreme dönemi:] Mayıs ayından itibaren yumurta koyar. yavrular temmuzda görülür. Türkiye dışında yılda iki hatta üç kez kuluçkaya yattığı ve üremenin ağustosa kadar devam ettiği bilinmektedir. Ancak, Türkiye'den henüz böyle bir gözlem kaydedilmemiştir. #strong[EGE:] 10 Mayıs 1950'de, içinde yeni konmuş yumurtalar bulunan bir yuva en erken üreme kaydıdır @mcneile1950. İzmir ve Aydın Akköy'de mayısın ikinci yarısı ve haziran başında birkaç başka kayıt bulunmaktadır. 24 Haziran 1966'da, Bafa Gölü'nde içinde iki yumurta bulunan bir yuva gözlenmiştir. #strong[KAR:] Kızılırmak Deltası'nda, Temmuz 1971'de 1 hektarlık ormanda sekiz tane kullanılan yuva sayılmıştır @dijksen1985. #strong[İÇA:] 30 Mayıs 1999'da, Göreme yakınlarında dört erişkin gösteri uçuşunda gözlenmiştir. 25 Haziran 1992'de, Hasan Dağı'nda içinde bir ve iki yumurta bulunan ve muhtemelen ikinci kez kuluçkaya yatılan iki yuva bulunmuştur. Ancak, 13 Haziran 1907'de Karaman Karadağ'da içinde birkaç günlük iki yavru bulunan bir yuva kaydedilmiştir @ramsay1914, bu kaydın muhtemelen ilk kuluçkaya ait olduğu düşünülmektedir. #strong[GDA:] 18 Mayıs 1993'te, Birecik'te içinde iki yumurta bulunan bir yuva bulunmuştur. 11 Mayıs 2004'te, Halfeti'de küçük bir meyve bahçesinde 1,7 metre boyundaki ağaçlarda ikişer yumurta bulunan iki yuva kaydedilmiştir. 8 Haziran 1993'te, Gaziantep yakınlarında yuva kuran erişkinler ve 14 Haziran 1996'da muhtemelen ikinci yuvayı kuran bireyler gözlenmiştir.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur.

== Büyük Üveyik
<büyük-üveyik>
#emph[Streptopelia orientalis], Oriental Turtle Dove

#strong[#emph[Rastlantısal konuktur.]]

İlk kez 12-15 Ocak 2011 tarihlerinde Ayvalık'ta bir bahçede kaydedilmiştir. İlk kışında olan ve diğer Avrupa ve Orta Doğu kayıtlarıyla uyumlu olarak meena alttürüne ait olan ilk kışındaki bu birey iyi şekilde fotoğraflanmıştır. Ardından aynı kış, 7 Şubat 2011'de Yeşilırmak Deltası'nda bir birey gözlenmiş ve fotoğraflanmıştır.

#box(image("images/harita_Streptopelia orientalis.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Yayılış alanı Doğu Asya'dır.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur. Tür bugünkü Türkiye sınırlarında tanımlanmıştır.

== Kumru
<kumru>
#emph[Streptopelia decaocto], Eurasian Collared Dove

#strong[#emph[Yaygın ve çok sayıda bulunan yerli ve yarı göçmendir.]]

Genellikle alçak bölgelerde bulunur, Doğu Anadolu'da oldukça yerel yayılış gösterir, Doğu Karadeniz'de yoktur. Son yıllarda hem Balkanlar hem de Orta Doğu'da yayılış alanında ciddi değişimler yaşanmış ve bu olgu @kasparek1996a@kasparek1998 tarafından incelenmiş ve Türkiye'yi de içine alan bu coğrafyada yayılış alanındaki genişleme belgelenmiştir. Bazı bölgelerde yarı göçmen olduğu düşünülür, kışları sert geçen iç bölgelerde kıyı bölgelerine bir hareket vardır. Kışın ve ilkbaharda yüzlerce kuştan oluşan sürüler gözlenmiştir. İstanbul ve diğer metropollerde küçük kumru ile rekabet edememiş ve yerini küçük kumruya bırakmıştır.

#box(image("images/harita_Streptopelia decaocto.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Tarım arazileri ve kentsel bölgelerde, özellikle köy ve kasabalarda yuvalar. İdeal koşullarda, yapraklı ve ibreli ağaçların karışık bulunduğu gelişmiş bahçe ve parklarda da ürer. Yuvasını ağaçlara veya yüksek çalılara yapar. Bazen Mersin'de gözlemlendiği gibi binalarda ve telefon direklerinde de yuvaladığı kaydedilmiştir @hollom1955. \
#strong[Yuvası:] İnce dal ve bitki gövdelerinden oluşan cılız bir platformdur. Daha ince bitkisel materyaller ve diğer malzemelerle özensizce astarlanır. \
#strong[Yumurta sayısı:] Üç yuvada ikişer yumurta sayılmıştır. İki yuvada ikişer yavru gözlenmiştir. \
#strong[Üreme dönemi:] Genellikle nisan ve mayıs ayında ilk yumurtaları koyar. Türkiye'de ve diğer bölgelerde yılda iki kez kuluçkaya yatar. #strong[EGE:] 23 Nisan 2003'te Aydın Akköy'de ve 9 Mayıs 1950'de İzmir'de kuluçkadaki erişkinler gözlenmiştir @mcneile1950. 2 Haziran 1954'te İzmir'de bir yuvada yeni bırakılmış iki yumurta kaydedilmiştir @mcneile1950. 29 Haziran 1966'da Akhisar'da, bir tespih ağacının üzerine yerleştirilmiş hasır bir sepetteki yuvada kuluçkaya yatmış bir erişkin gözlenmiştir. #strong[AKD:] 18 Mayıs 1951'de Mersin'de bir erişkinin yuvasını astarladığı gözlenmiştir @hollom1955. 3 Mayıs 1970'te İskenderun'da bir yüksek gerilim hattı direğine yuva kuran bir erişkin gözlenmiştir. 5 Mayıs 2003'te Dalaman Havaalanı'nda, bir sıra ibreli ağaçtaki yuvada kuluçkada bir erişkin gözlenmiştir. 6 Mayıs 2004'te Göksu Deltası'nda iki erişkinin kuluçkada olduğu iki yuva kaydedilmiştir. #strong[İÇA:] 24 Nisan 1991'de Konya Hotamış'ta bir yuva bulunmuştur @kirwan1993a. Haziran 1991'in ilk haftasında, Kayseri İncesu'da bir karaçamın içindeki yuvada iki yumurta tespit edilmiştir (BD). 23 Nisan 2004'te Şereflikoçhisar'da yol kenarındaki bir ağaçta kuluçkaya yatan bir erişkin gözlenmiştir. 15 Mayıs 2004'te Cihanbeyli'de bulunan bir yuvada yumurtadan yeni çıkmış iki yavru gözlenmiştir. #strong[GDA:] 11 Mayıs 2004'te Halfeti yakınlarında yuva yapımı gözlenmiştir. 3 Haziran 1998'de Birecik'te iki yuvada ikişer yumurta bulunmuş, 11 Mayıs 2004'te ise iki yumurta kaydedilmiştir. 25 Haziran 2001'de Birecik'te, yuvadaki iki iri yavru bir yılan tarafından yenmiştir.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur. Tür bugünkü Türkiye sınırlarında tanımlanmıştır.

== Küçük Kumru
<küçük-kumru>
#emph[Spilopelia senegalensis], Laughing Dove

#strong[#emph[Nispeten yaygın ve çok sayıda bulunan yerlidir.]]

Ülkedeki yayılış alanı ve durumu @kasparek1991 tarafından ayrıntılı bir araştırma konusu olarak ele alınmıştır. Güneydoğu Anadolu, Doğu Akdeniz ve İstanbul çevresinde kasaba ve şehirlerde çok bol bulunan yerli kuştur. İstanbul'da gelen kuşların menşei Tunus'tan getirilen kuşlar olduğu düşünülür. Ayrıca tüm yurtta çok yerel olarak şehirlerde rastlanabilir. Bazı yerleşimlerde rekabet halinde olduğu kumruyu egale etmeyi başarırken, diğerlerinde kumru daha baskın çıkar. En yoğun olarak görüldüğü şehirler İstanbul, Adana, Mersin, Adıyaman, Gaziantep, Urfa, Mardin ve Diyarbakır'dır. Daha küçük sayılarda Antalya, Afyon, Ankara, Samsun, Erzincan ve Malatya'da, tek tük İzmir, Çanakkale, Edirne, Tekirdağ, Konya, Hakkâri ve Van'da bulunur.

#box(image("images/harita_Spilopelia senegalensis.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] İstanbul ve diğer şehirlerde yerleşim alanlarında, Doğu Akdeniz ve Güneydoğu Anadolu'da köyler ve tarım arazilerinde bulunur. \
#strong[Yuvası:] Bir çalı, ağaç veya bina cephesine yuva yapar. Yuvası, ince çalılardan yapılmış basit bir platform olup, otlar ve ince bitkisel malzemelerle astarlanır. Aynı yuva, yıl içindeki birbirini takip eden kuluçkalar için tekrar kullanılabilir. Yuvanın farklı tabakalardan oluşan yapısı ve eski dışkı kalıntıları, bu olgunun göstergesi olarak kabul edilmektedir. \
#strong[Yumurta sayısı:] Bir yuvada 2 yumurta gözlenmiştir. \
#strong[Yavru sayısı:] Bir yuvada 2 yavru kaydedilmiştir. \
#strong[Üreme dönemi:] İstanbul'da ve muhtemelen diğer ılıman ve sıcak şehirlerde yıl boyu yuvaladığı düşünülür. Diğer yerlerde üreme şubat ve mart arasında başlar. #strong[MAR:] İstanbul'da, 28 Mart 1967'de çiftleşen bir çift gözlenmiş, 22 Nisan 1970'te bir pencere pervazındaki yuvada oturan bir çift görülmüş ve Temmuz 1968 sonunda yavrusu olan bir çift kaydedilmiştir. #strong[AKD:] 28 Mart 2000'de, Adana Havaalanı'ndaki bir palmiyede bir çiftin yuvaladığı gözlenmiştir. 18 Mayıs 2004'te, Adana şehir merkezinde yeni palazlanmış bir yavru görülmüştür. #strong[GDA:] 3 Mayıs 1964'te, Birecik'te yuvalayan çoğu çiftin yavrularını beslediği, ancak bir yuvada hâlâ iki yumurta bulunduğu kaydedilmiştir @warncke1964-65beitrag. 11 Mayıs 2004'te, Halfeti'de yeni uçmaya başlamış ancak hâlâ hav tüyleri görülebilen bir yavrunun yaklaşık bir hafta önce yuvadan ayrıldığı belirlenmiştir. Yakın bir noktada, yerden 4 metre yukarıda, oturulan bir evin dış cephesindeki bir çıkıntıda yaklaşık 7 günlük iki yavru gözlenmiş ve yumurtlama tarihi 20 Nisan olarak hesaplanmıştır. Aynı yuvanın yıl içinde daha önce de kullanıldığı ve üremenin şubat ve mart aylarında başladığı gözlenmiştir.

#strong[Alttürler ve Sınıflandırma]

Alttür tayini için inceleme yapılmamıştır. İstanbul'a Tunus'tan getirildiği düşünülen ve çevre bölgelere yayılan kuşlar #emph[phoenicophila] alttürü olduğu düşünülür. Güneydoğu Anadolu'da ve buradan diğer bölgelere yayılan kuşların nominat alttüre olduğunu iddia etmiştir @kasparek1991.

== Kap Kumrusu
<kap-kumrusu>
#emph[Oena capensis], Namaqua Dove

#strong[#emph[Türkiye'ye yeni yerleşen ve lokal olarak bulunan yerlidir.]]

İlk kez Birecik'in kuzeyinde 23-24 Mayıs 2005'te bir dişi fotoğraflanmıştır. Ardından birer tane 23 Mayıs 2008'de Sinop'ta, 13 Mayıs 2010'da Niğde Çukurbağ'da, 8 Haziran 2012'de Kozanlı Gökgöl'de, 24 Haziran 2012'de Birecik'te ve son olarak 8 Kasım 2014'te Milleyha Antakya'da denizden gelen bir birey fotoğraflanmıştır. İsrail'de Arava vadisinde 1961'den beri yerleşik bir popülasyonun olduğu bilinir @shirihai1996.

#box(image("images/harita_Oena capensis.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Kurak ve sıcak bölgelerde bulunur. Muhtemelen Çukurova ve Şanlıurfa'da yuvalamıştır. \
#strong[Yuvası:] Tanımlanmamıştır. \
#strong[Yumurta sayısı:] Türkiye'de yumurta sayısı bilinmemektedir. \
#strong[Üreme dönemi:] Bilinmemektedir.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur.

== Paçalı Bağırtlak
<paçalı-bağırtlak>
#emph[Syrrhaptes paradoxus,] Pallas's Sandgrouse

#strong[#emph[Rastlantısal konuktur.]]

Belki de farazi olarak kabul edilmesi daha uygun olabilir. 1888'in Kasım ortasında, türün Batı ve Orta Avrupa'ya yaptığı büyük istilalardan biri sırasında, tahminen günümüzün Rumelifeneri'nde yakalanmış 4 Paçalı Bağırtlak, İstanbul'un kümes hayvanları pazarında görülmüştür @matheydupraz1920. Bu kaydın dışında , türün yeni yerleri kolonize ettiği 1859 ve 1863 yıllarında da Türkiye'ye ulaştığından söz etmiş ancak ayrıntılı bilgi vermemiştir @ergene1945. 1962'de Tansu Gürpınar Konya Çumra Avcılar Kulübü'nde doldurulmuş 1 bireye rastlamıştır. Türün kaydedilmiş en büyük hareketleri Avrupa'ya sokulduğu 1863 ve 1888 yıllarında gözlenmiştir @madge2002. Türkiye'den güncel kayıt yoktur. Ortadoğu'daki diğer bölgelerde ise türden yalnızca "Büyük olasılıkla Hazar Denizi'nin doğusundaki İran steplerinin düzensiz konuğudur" diye söz edilmektedir @porter1996.

#box(image("images/harita_Syrrhaptes paradoxus.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Yayılış alanı Orta Asya'dır.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Kılkuyruk Bağırtlak
<kılkuyruk-bağırtlak>
#emph[Pterocles alchata], Pin-tailed Sandgrouse

#strong[#emph[Lokal ve nadir yaz konuğudur.]]

Geçmişteki çoğu sayımda 50-500 birey arasında kaydedilmiştir. Mayıs 1970'te Akçakale yakınında ve 1980'lerde Birecik'te 2000 bireye kadar sayıldığı da olmuştur. Ancak sözü geçen bölgede yakın zamanda yapılan, bir noktada en fazla ancak 31 bireyin sayıldığı ve türe 10 km karelik dört karede rastlanmış, büyük bir azalmanın yaşandığı kanıtlanmıştır @welch2004gap. Bağırtlak P. orientalis'da gözlendiği gibi, su içmek için Birecik'te Fırat Nehri'ni ziyaret eden birey sayısında yakın zamanda ciddi bir azalma görülmüştür. Büyük olasılıkla bu azalmanın nedeni kısmen, Suriye sınırından yukarıdaki baraj projeleri nedeniyle su seviyesinde yakın zamanda yaşanan değişimler olsa da, kurak bozkır alanlara açılan tarım arazileri azalmada rol sahibidir. İç Anadolu'da nadiren kaydedilmiştir. Mayıs 1971'de Tuz Gölü'nün doğusunda, Mayıs 1986'da ise Konya Havzası'nın güneyindeki iki noktada kaydedilmiştir. Kısa süre önce, Temmuz 1998'de, yalnızca bir kez ama büyük sayıda olmak üzere Van'da gözlenmiştir @kirwan1999. 19.yy'a ait kayıtlar Mersin'den (Mart ortasında) ve İzmir'den bildirilmiştir @kumerloeve1961.

#box(image("images/harita_Pterocles alchata.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Türkiye'de özellikle Şanlıurfa ili sınırlarında kurak bozkırda yuvalar. \
#strong[Yuvası:] Tanımlanmamıştır. \
#strong[Yumurta sayısı:] Türkiye'de yumurta sayısı bilinmemektedir. \
#strong[Üreme dönemi:] Haziran 1977'de, K. Warncke tarafından içinde 2 yumurta bulunan bir yuvanın ve büyük olasılıkla aynı yuvada yumurtaları ya da yavruları ile ilgili olarak kuluçkaya yatmış bir erişkinin fotoğrafı çekilmiştir @pforr1982.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de caudacutus alttürü bulunur.

== Benekli Bağırtlak
<benekli-bağırtlak>
#emph[Pterocles senegallus], Spotted Sandgrouse

#strong[#emph[Rastlantısal konuktur.]]

Her ikisi de Birecik'ten bildirilmiş olan iki kaydı vardır: 18 Temmuz 1986'da gözlenen bir dişi @martins1989 ile 20 Haziran 1999'da kaydedilen bir çift @kirwan2000sandgrouse. Her iki kayıt da gözlemciler tarafından çok iyi tarif edilmiştir. Bunların yanı sıra en az bir gözlemde daha, 17 Temmuz 1987'de yine Birecik'te, büyük olasılıkla bu türe ait 2 birey kaydedilmiştir. Bu gözleme ait bazı betimleyici ayrıntılar mevcuttur. Son olarak 26 Mart 2021'de Milleyha Antakya'da gözlenmiştir.

Benekli Bağırtlak önceden Suriye'nin orta ve güney bölgelerinde üremiştir ancak ülkenin kuzeyinden sadece bir tane, Eylül 1945 tarihli kayıt vardır. Yakın zamanlı bir diğer kayıt ise Nisan 1994'te ülkenin orta bölgesinden bildirilmiştir @baumgart1995. En yakındaki halen aktif üreme bölgeleri güney Irak ve Levant bölgesinde gibi görünmektedir.

#box(image("images/harita_Pterocles senegallus.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Yayılış alanı Sahra Çölü ve Ortadoğu'dur.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Bağırtlak
<bağırtlak>
#emph[Pterocles orientalis], Black-bellied Sandgrouse

#strong[#emph[Nispeten lokal ve az sayıda yaz konuğudur.]]

Seyrek ancak nispeten yaygın olarak bulunan bir yerli kuş ve yarı göçmendir. İç Anadolu ile Doğu Anadolu'nun genelinde ve en azından geçmişte Güneydoğu Anadolu'da en az 2300 m'de bulunur. İç Anadolu bölgesinde özellikle yaygın yayılışlıdır. En azından önceleri bu bölgede türe sıklıkla büyük sürüler halinde rastlanmıştır. 100'ün üzerinde bireyin sayıldığı birkaç gözlem ve Eylül 1974'te kaydedilen 500 birey bu bölgeden bildirilmiştir. Türün esas olarak kış konuğu olduğu (aşağıya bkz.) Karadeniz, Ege ve Akdeniz Bölgesi'nde az sayıda kaydedilir. Doğu Anadolu'da, Van Gölü çevresinde düzenli olarak kuzeyde Horasan ve Ağrı ile Kağızman ve Iğdır boyunca, doğuda Doğubayazıt bölgesine ve batıda Hafik'e kadar yayılır. Nadiren 50'yi aşan sayıda kaydedilmiştir. Tür şimdilerde, önceleri düzenli olarak 100'ün üzerinde sayıldığı Güneydoğu Anadolu'da, hatta Birecik'te bile çok nadir ve lokaldir @welch2004gap. Kuru step alanlarına yapılan tarım amaçlı değişiklikler sonucunda sözü geçen 3 bölgede de azalmaktadır.

Bağırtlak birçok bölgede yarı göçmendir. Kışın daha ılıman bölgelere hareket eder. Örneğin ekim sonu ile mart başı arasında İç Anadolu'nun birçok bölgesinde görülmez. Bu mevsimde, Ege'de ve Akdeniz Bölgesi'nde epey nadirdir. Gediz Deltası'na dek batıda da kaydedildiği olmuştur @gonzenbach1852. Akdeniz Bölgesi'nde ise Hatay'a dek güneyde rastlanmıştır. Bu kayıtlarda bildirilen birey sayısı genellikle düşüktür ancak Ocak 1970'te Acıgöl'de 120 birey kaydedilmiştir. Nisan sonunda Göksu Deltası'nda görülebilir @davidson1997.

#box(image("images/harita_Pterocles orientalis.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Çıplak zeminli ya da alçak, dağınık çalılar içeren kuru düzlük steplerde veya kurak, hafif eğimli tepelerde ürer. Genellikle yalnız ürer ancak en uygun habitatlarda, aralarında geniş mesafe bulunan birkaç çift bir arada bulunabilir. \
#strong[Yuvası:] Yere, genellikle astarlanmamış sığ bir çukura yuva yapar. \
#strong[Yumurta sayısı:] Türkiye'de gözlenen yumurta sayısı genellikle 3'tür. On bir yuvada 3 yumurta sayılmıştır. Üç yuvada yalnızca 1 yumurta bulunmuş olup, bu yuvaların tamamlanmamış kuluçkaya sahip olduğu kabul edilmiştir. \
#strong[Üreme dönemi:] Mayıs ayında yumurta koymaya başlar, yavrular haziran ayında çıkar. #strong[İÇA:] 8-14 Mayıs 1876'da Kayseri'nin kuzeyinde, her birinde 3 taze yumurta bulunan 4 yuva kaydedilmiştir @danford1877. 3 Mayıs 1989'da Karapınar'da, üçünde 3, birinde 1 yumurta olan 4 yuva bulunmuştur. Aynı yerde, 10 Mayıs 1990'da bulunan bir diğer yuvada 3 yumurta sayılmıştır. 14 Mayıs 1993'te, Bolluk Gölü yakınındaki bir yuvada, tamamlanmamış bir kuluçkada tek bir yumurta kaydedilmiştir. 29 Mayıs 1983'te, Sultansazlığı'ndaki bir yuvada 3 yumurta bulunmuş @kasparek1985, yakındaki bir başka noktada 27 Mayıs 1972'de bulunan bir diğer yuvada da 3 yumurta kaydedilmiştir. 31 Mayıs 1974'te, Cihanbeyli yakınlarında içinde 3 yumurta bulunan bir yuvanın ve aynı yerde 12 Haziran 1973'te gözlenen yeni tüylenmiş bir yavrunun fotoğrafları çekilmiştir @pforr1982.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur. Tür Türkiye'de tanımlanmıştır.

== Toy
<toy>
#emph[Otis tarda], Great Bustard

#strong[#emph[Lokal olarak çok az sayıda olan yerli bir türdür.]]

İç Anadolu ve Doğu Anadolu'da lokal olarak çok az sayıda bulunur. Bilinen üreme alanları, geniş ve ağaçsız araziler, tarımsal mozaik alanlar ve yarı bozkır bölgeler olup insan baskısının düşük olduğu ve 1800 metre yükseklikteki doğu bölgelerinde görülür. Bugün popülasyonu 10'dan az alanda bulunmakta olup bu alanlar arasında devlet üretme çiftlikleri önemli popülasyonu barındırmaktadır. Tarımsal yayılma, avcılık, habitat kaybı ve değişimi nedeniyle popülasyonun uzun vadede azaldığı gözlenmektedir. Mevcut gidişat devam ederse soyunun tükenme tehlikesi yüksek bir olasılıktır.

Türkiye'deki eski yayılışını detaylandıran bir çalışmaya göre, geçmişte tüm bölgelerde bulunmaktaydı @kasparek1989a, bu çalışmada tür için toplam 83 alan tanımlanmıştır. 1980'lerin başında, türün varlığını sürdürebilmesinin zor olacağı tahmin edilmiştir @goriup1985. Sonraki veriler @eken1999@heunks2001@heunks2002, Türkiye'deki toy sayısında son 20-30 yılda ciddi bir azalma yaşandığını göstermektedir. 2000'li yıllarda popülasyonunun 764-1250 birey arasında olduğu tahmin edilmiştir @dogadernegi2004. Murat Nehri Vadisi ve Bulanık civarında, 2002 ilkbaharında 145 birey sayılmıştır. Doğu Anadolu popülasyonunun belkemiğini oluşturan Bulanık ve Muş Ovası'nda toplam 251 bireyin olduğu tespit edilmiştir @balmer2003. Güneydoğu Anadolu'da ürediği yüksek bir olasılık olarak değerlendirilse de, 2004 yılında bölgede yapılan kapsamlı arazi çalışması sonucunda bölgede artık üremediği ortaya çıkmıştır @kirwan2003@welch2004gap@karakas2005a. 1997'ye yakın tarihlerde popülasyonun 800-3000 çift arasında olduğu tahmin edilmiştir. 1980'lerin başında Güneydoğu Anadolu'nun sınır bölgelerinde dikkate değer sayılarda kışladığı bilinmektedir @goriup1985.

Ülkedeki popülasyonun çoğunluğu yerli bireylerden oluşsa da az sayıda göç almaktadır. Güneydoğu Anadolu'da kışlayan bireylerin ise Karadeniz'in kuzeyinden geldiği düşünülmektedir. Ege, Marmara ve güney kıyı şeridinde sonbahardan ilkbahara kadar daha geniş bir alanda kaydedilmiştir.

#box(image("images/harita_Otis tarda.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Genellikle geniş, açık ve ağaçsız alanlar, büyük tarım alanları, nadasa bırakılmış tarlalar ve çayırlarda yuvalar. Sivrihisar'ın güneybatısındaki Aliken'de 45 erişkinin bulunduğu önemli bir arazinin %50'si buğday ve arpa tarlalarından, %40'ı nadas alanlarından ve %10'u taşlık bozkırdan oluşmaktadır. Kütahya civarındaki Altıntaş Ovası'nda, tahıl arazilerinin neredeyse yarısı her yıl nadasa bırakılmakta olup burada türün her yıl ürediği teyit edilmektedir @magninyarar1997. \
#strong[Yuvası:] Derin olmayan, çevrelenmemiş bir çukur şeklindedir ve genellikle kısa, seyrek bitki örtüsü içinde ya da gelişen mısır veya otlar arasında bulunur. Türkiye'de yuva yapısına dair ayrıntılı bilgi bulunmamakla birlikte, diğer bölgelerde sade bir yapıdadır. \
#strong[Yumurta sayısı:] Türkiye'de gözlenen yumurta sayısı tanımlanmamıştır; başka bölgelerde genellikle 2-3 (nadiren 4) yumurta ile kuluçkaya yatar. \
#strong[Üreme dönemi:] Nisan ortasından ağustos ortasına kadar sürer. #strong[AKD:] 9-11 Mayıs 1899'da Acıgöl yakınlarında kalmıştır @selous1900. Bu sürede yuva bulamamış fakat taze bir yumurta kendisine getirilmiştir ve o bölgede kuvvetle muhtemel hala küçük bir popülasyon bulunmaktadır @magninyarar1997. #strong[İÇA:] Tuz Gölü'nün doğu kıyısında 15 Nisan 1995'te erkeklerin ağaçsız tahıl tarlaları ve doğal bozkırlarda 2-6 bireylik gruplar veya tek olarak kur yaptığı belirlenmiştir; çiftleşme yalnızca bir kez gözlenmiştir @heunks2002. Kayseri ile Çorum arasında 8-14 Mayıs 1876'da yapılan bir yolculukta "talan edilmiş bir toy yuvası" gözlemlenmiştir @danford1877. 1972 ilkbaharında Tuz Gölü'ndeki bir adada martı kolonisinde bir toy yumurtası bulunmuştur. 27 Haziran 1951'de Çubuk Ovası'nda bir yavruyla dişi, 25 Nisan 1965'te Ereğli'de ve Mayıs 1969'da Tuz Gölü'nde kur davranışı gözlenmiştir @kasparek1989a. Tuz Gölü'nün doğu kıyısında 15 Nisan 1995'te kur davranışı kaydedilmiştir. #strong[GDA] 14 Mayıs 1975'te Viranşehir'in batısında yanında yavrusu varmış gibi davranan bir dişi ve 14 Haziran 1983'te Batman yakınlarındaki Çöltepe'de orta boylu bir yavru ile dişi gözlenmiştir. #strong[DOA:] 30 Mayıs 1992'de Bulanık'ta, içinde 6 kur yapan erkek ve bir genç dişi bulunan yaklaşık 30 bireylik bir grup gözlenmiştir. 7 Haziran 1987'de Hazar Gölü'nde Sivrice civarında bir yavru ve Van Gölü yakınlarında yavrusu varmış gibi davranan bir dişi kaydedilmiştir @kasparek1989a. Sodalı Göl'ün doğusunda üreme sezonunda 32'den fazla birey gözlenmiş ve burada ürediği teyit edilmiştir @magninyarar1997.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur.

== Asya Yakalı Toyu
<asya-yakalı-toyu>
#emph[Chlamydotis macqueenii], Macqueen's Bustard

#strong[#emph[Rastlantısal konuktuk. Üreyen nüfusu geçen yüzyılda tükenmiştir.]]

Yaklaşık 100 yıl aradan sonra tekrar görülmüştür. İlk kayıt, 17 Aralık 2012'de Konya'nın Karapınar ilçesinde avcılar tarafından yaralı halde bulunan bir bireye aittir. Selçuk Üniversitesi Veterinerlik Fakültesi'ne getirilen bu kuş Dr.~K. Erciyas'ın danışmanlığıyla tanımlanmıştır. 28 günlük tedavi ve rehabilitasyon sürecinin ardından 14 Ocak'ta Dr.~Ortaç Onmuş tarafından sırtına verici takılarak doğaya bırakılmıştır. Serbest bırakıldığında birkaç metre uçabilmiş, ardından koşarak uzaklaşmıştır; ancak ertesi gün bir çakal tarafından ölü olarak bulunmuştur. Yaralanmasının göğsüne isabet eden bir avcı saçmasından kaynaklandığı ve göğüs kasındaki kurşunun tedavi sırasında çıkarılamadığı anlaşılmıştır. Kuşun bulunduğu alanda bağırtlak ve toy sürülerinin kışladığını öğrenilmiştir.

İkinci kayıt, 20 Ekim 2020'de Trabzon'un Akçaabat ilçesinde bitkin halde bulunan, halkalı ve sırtında verici taşıyan bir bireye aittir. Sokakta göç yorgunu olarak bulunan bu bireyin bakımı kuş fotoğrafçısı Hakan Kahraman tarafından yapılmış, rehabilitasyonu tamamlanmıştır. 28 Ekim 2020'de Bayburt'un Balkaynak Köyü'nde doğaya salınan kuş, iki gün sonra Yozgat'ın Sorgun ilçesine bağlı Osmaniye Köyü kırsalında avcılar tarafından vurularak ölü bulunmuştur @ntv2020yakalitoy.

Üçüncü kayıt, 2020 Aralık ayında Bitlis'te yaralı halde bulunan bir bireyedir. Bu birey, tedavi için Van Yüzüncü Yıl Üniversitesi'ne getirildiğinde 550 gram ağırlığındaydı. Rehabilitasyon süreci sonunda ağırlığı yaklaşık 1,5 kilograma ulaşmıştır. Sağlığına kavuşan kuş, 17 Mart 2021'de Muş Ovası'nda TİGEM sahasında doğaya salınmış ve kuş fotoğrafçıları tarafından belgelenmiştir.

Eski üreyen popülasyona ait kayıtlar, 1912 yılı veya daha öncesinde Kars civarından gelmektedir @satunin1912. Ayrıca 1917 öncesinde Aras Vadisi'nde çok küçük bir popülasyonun bulunduğu belirtilmiştir @glutzvonblotzheim1973. 1910 yılında Amik Gölü yakınlarında bulunan genç bir bireyin, Aharoni tarafından muhafaza edilemediği, ancak o dönemde bu bölgede muhtemelen üremenin olduğuna dair bilgiler aktarılmıştır @kumerloeve1963a. 1981 yılında yapılan değerlendirmeler, Doğu Anadolu'nun ücra bölgelerde hala hem uygun üreme habitatlarının bulunduğunu, hem de buralarda ara sıra kışlayabileceğini öne sürmüştür @goriup1985.

#box(image("images/harita_Chlamydotis macqueenii.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Parçalı yayılış gösterir, batıda Sina (Mısır) ve doğuda Arabistan'dan Moğolistan'a kadar uzanır, kuzeyde üreyenler uzun mesafe göçmenidir.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür. Eskiden yakalı toylar tek bir tür altında #emph[Chlamydotis undulata] sınıflandırılıyordu. Yapılan moleküler analizler ve kur törenindeki farklara göre Kuzey Afrika'da bulunan #emph[undulata] ve Orta Asya'da bulunan #emph[macqueenii] alttürlerinin farklı türler olduğuna karar verilmiştir.

== Mezgeldek
<mezgeldek>
#emph[Tetrax tetrax], Little Bustard

#strong[#emph[Çok lokal ve nadir yaz konuğu, nispeten yaygın ancak nadir geçit türü ve kış konuğudur.]]

İç Anadolu ve Doğu Anadolu'da çok nadir ve lokal olarak bulunur. 1980-2000 yılları arasında soyunun tükenmiş olduğu düşünülmüştür. Ancak uzun bir aradan sonra İç Anadolu'da 1998 yılında iki küçük üreme kolonisi tespit edilmiş @eken1999 ve 2003 yılında farklı üç alanda kur davranışı sergileyerek uzun süreli kalma gözlenmiştir. Doğu Anadolu'da ise Muş yakınlarında ve Bulanık Ovası'nda daha güçlü bir popülasyonun var olduğu tespit edilmiştir. Buna karşın, Güneydoğu Anadolu'da yapılan kapsamlı arazi çalışmalarında türün varlığına dair herhangi bir veri elde edilememiştir @welch2004gap.

Türün tarihsel yayılışı ve durumu @kasparek1989a tarafından karşılaştırmalı olarak gösterilmiştir. Bu çalışmaya göre, türün esas yayılış alanı Marmara'nın güneyindeki bazı bölgeler, kıyı Ege, İç Anadolu'nun çok lokal alanları, Akdeniz, Doğu ve Güneydoğu Anadolu'dur. Urfa Ceylanpınar'da 1960'lara kadar oldukça yaygındı ve son üç bölgedeki kayıtların çoğu üreme dönemi dışındaydı. Tür için 40 kadar alanın bilinmesinin bir nedeni Türkiye'deki durumu ile ilgili literatürün çoğu 1950 öncesine ait olmasıdır @kasparek1989a. Toya benzer şekilde, tarımsal uygulamalar, habitat değişimleri ve avcılık nedeniyle popülasyon uzun vadede azalma göstermektedir.

Geç sonbaharda Karadeniz kıyısı boyunca nadir de olsa az sayıda birey göç geçişi yapar. 26 Ekim 2010'da Rize'de, 9 Kasım 2009'da İstanbul'da, 15 Kasım 2009'da Trabzon'da @balmer2010around ve Aralık 2005'te Kızılırmak Deltası'nda kaydedilmiştir. Kış mevsiminde ise az sayıda birey Karadeniz, Marmara, Ege ve Akdeniz kıyılarında görülebilir.

#box(image("images/harita_Tetrax tetrax.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Türkiye'de üreme verisi yoktur; ancak diğer bölgelerde açık çayırlar ve mısır tarlalarında yuvalar. \
#strong[Yuvası:] Derin olmayan, çevrelenmemiş bir çukur şeklinde olup genellikle bitki örtüsü içine gizlenmiştir. \
#strong[Yumurta sayısı:] Normalde 3-4 (nadiren 2-5) yumurta ile kuluçkaya yatar. \
#strong[Üreme dönemi:] #strong[AKD] Karamık Bataklığı'nda, 12 Temmuz 1969'da bulunan ölü bir bireyin neredeyse tüylenmiş yavru (palaz) olduğu düşünülmektedir. #strong[MAR] Karacabey-Bursa arasındaki yaklaşık 60 hektarlık bir alanda, Mayıs 1937'de kur yapan 7 erkek vurulmuş ve burada üredikleri teyit edilmiştir @kasparek1989a. #strong[GDA] 8 Nisan 1981'de Ceylanpınar'da kur yapan bir erkek gözlenmiştir @parr1981. #strong[İÇA] Konya Havzası'nda 23 Haziran 1998'de kur yapan bir erkek gözlenmiştir @kirwan2003. Ayrıca, 27 Mart 2004'te Kulu Gölü yakınlarında kur yapan iki erkek ve öten bir erkek ile kaçan bir dişi gözlenmiştir.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür. Önceden Otis cinsi altında yer almıştır (Collar N.; @delhoyo1996.

== Tepeli Guguk
<tepeli-guguk>
#emph[Clamator glandarius], Great Spotted Cuckoo

#strong[#emph[Seyrek yaz konuğudur.]]

Nisan başı ve eylül başı arasında oldukça yaygındır. Ege'de nispeten daha sık görülür, diğer bölgelerde nadir olarak bulunur. Güneydoğu'da ürediğine dair kısıtlı kayıt vardır. En azından 1200 metreye kadar çıkar. Doğu Anadolu'da ağustos ve eylülde görülen gençler ve az sayıdaki ilkbahar kaydı büyük ihtimalle geçide işaret eder. İlkbaharda hem de sonbaharda göç dönemini ve yoğunluğunu belirlemek kolay değildir, buna rağmen ilkbahar geçişi nisan sonuna kadar devam eder @kivit1994.

#box(image("images/harita_Clamator glandarius.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Türkiye'de sadece saksağanın paraziti olarak kaydedilmiştir. \
#strong[Yuvası:] Saksağan yuvalarına yumurta koyar. \
#strong[Yumurta sayısı:] Her yuvaya 1 yumurta koyar. \
#strong[Üreme dönemi:] Bu nedenle üreme takvimi, saksağanın üreme döngüsüyle eşzamanlıdır. #strong[MAR:] Manyas Gölü'nde, 25 Mayıs 1967'de gösteri yapan ve sıkça seslenen eşleşmiş bir çift gözlenmiştir. #strong[EGE:] 25 Haziran 1966'da Bafa Gölü'nde palazlanmış bir yavru gözlenmiştir. 4 Haziran 1971'de Güllük Körfezi'nde, oldukça erken bir tarihte bir genç birey kaydedilmiştir. 23 Mayıs 1993'te, Aydın Akköy çevresindeki tarım arazisinde bir genç birey tepeli toygarlar tarafından taciz edilmiştir. #strong[İÇA:] 8 Mayıs 1945'te, içinde beş saksağan ve bir guguk yumurtası bulunan bir yuva kaydedilmiştir @wadley1951. 21 Mayıs 1972'de, Ankara'da bir yuvada tek bir guguk yavrusu bulunmuş, saksağan yavrusu gözlenmemiştir. 14 Temmuz 1977'de, Kırşehir'de bir yuvada iki guguk yumurtası ve bir kırık saksağan yumurtası kaydedilmiş, aynı gün yakındaki başka bir yuvada yeni bırakılmış bir guguk yumurtası ve saksağan yumurtası tespit edilmiştir @schubert1979. 7 Ağustos 1967'de, bir saksağan sürüsünün içinde iki genç guguk gözlenmiştir. 11 Temmuz 1969'da, Eskişehir Gordion'da bir genç birey kaydedilmiş, 4 Temmuz 1993'te Ereğli Sazlığı'nda iki genç birey birlikte gözlenmiştir.

#strong[Alttürler ve Sınıflandırma]

Monotipik bir türdür.

== Guguk
<guguk>
#emph[Cuculus canorus], Common Cuckoo

#strong[#emph[Yaygın ve çok sayıda bulunan yaz konuğudur.]]

Deniz seviyesinden itibaren 2000 metreye kadar yayılış gösterir, ormanlardan tarım arazilerine kadar farklı yaşam alanlarında ürer, hatta oldukça kurak ve açık arazilerde bile bulunur. Kızılırmak Deltası'nda tahmini 70-90 çiftin çoğunlukla Yörükler Ormanı'nda ürediği belirlenmiştir. Buna karşın, olası konak türlerinden saz kamışçınının yüksek sayılarda bulunduğu bataklık alanlarda çok seyrek rastlanmıştır @hustings1994. Güneydoğu'da nispeten yereldir.

Geçit sırasında ülke çapında yaygın olarak görülür. Ülke genelinde nisan başından itibaren, Akdeniz ve Güney Ege'de mart sonundan itibaren görülür. Sonbaharda eylül sonuna kadar kalır. En erken 12 Şubat 2005'te Milas Tuzla Gölü'nde kaydedilmiştir. En geç kayıt 3 Ekim 1993'te Uluabat Gölü'ndendir.

#box(image("images/harita_Cuculus canorus.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Yuva paraziti olarak konak türe bağlı olarak çok farklı yaşam alanlarında bulunur. Ormanlar, tarım arazileri, çalılıklar, bataklıklar ve hatta çok kurak bölgelerde gözlenebilir. \
#strong[Yuvası:] Türkiye'den gelen kayıtlarda şimdiye kadar kurak arazide yaşayan beş farklı konak türü tespit edilmiş olsa da, türün kullandığı konak sayısının çok daha fazla olmalıdır. Sazlıklarda yaşayan saz kamışçını ve büyük kamışçınının konak türler arasında yer aldığı varsayılabilir. Türkiye dışında dişilerin, büyük olasılıkla kendilerini de yetiştiren tek bir konak türe uzmanlaştıkları bilinmektedir. Bunun Türkiye'de de geçerli olup olmadığı bilinmemektedir. \
#strong[Yumurta sayısı:] Her konağa bir yumurta bıraktığı bilinir. \
#strong[Üreme dönemi:] Afrika'dan gelir gelmez, nisan ayından itibaren yumurta koyar. #strong[EGE:] İzmir'de oturan @mcneile1950, 1950 yılında ak gözlü ötleğenin çalılık arazilerde en yaygın konak tür olduğunu aktarmıştır. 10 Mayıs 1950'de bir yuvada, hepsi yeni konulmuş bir guguk ve üç ötleğen yumurtası bulmuş, 26 Mayıs 1951'de terkedilmiş bir yuvada bir guguk ve iki ötleğen yumurtası kaydetmiştir. Bunun dışında, 2 Haziran 1951'de bir çalı bülbülü yuvasında bir guguk ve dört çalı bülbülü yumurtası gözlenmiş ve hepsi de kuluçkaya yatılmıştır. 28 Mayıs 1951'de, konak türü belli olmayan palazlanmış bir yavru kaydedilmiş olup, bu gözlem yumurtlamanın nisan sonunda gerçekleştiğini göstermektedir. Bu nispeten erken tarih, sonraki gözlemlerle de uyumludur. Aydın Altınkum'da, 22 Nisan 2002'de iki dişi guguk, yuva yapmak üzere olan kara boğazlı ötleğen çiftlerini takip ederken gözlenmiş, ötleğenlerin guguklara saldırması, onların konak yuvaları olduğu yönünde bir kanaat oluşturmuştur. #strong[KAR:] Kızılırmak Deltası'nda, Temmuz 1971'de ölü bir genç birey bulunmuştur @dijksen1985. #strong[DOA:] 16 Ağustos 1972'de Ağrı Kağızman'da, kır incirkuşundan yem isteyen iki genç birey gözlenmiştir. 17 Ağustos 1972'de, görünüşe göre bir ak kuyruksallayan tarafından yetiştirilmiş bir genç birey kaydedilmiştir. 1 Ağustos 1986'da, Bulanık'ta bir genç gözlenmiştir. #strong[GDA:] 13 Ağustos 1986'da Gaziantep Işıklı'da bir genç birey gözlenmiştir.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur.

== Çobanaldatan
<çobanaldatan>
#emph[Caprimulgus europaeus], European Nightjar

#strong[#emph[Yaygın ve çok sayıda bulunan yaz konuğudur.]]

Batı ve güneyde oldukça yaygındır. Görünüşe göre Güneydoğu Anadolu hariç ülkenin geri kalan kesiminin de büyük bölümünde lokal olarak bulunur. Muhtemelen kayıtların gösterdiğinden daha yaygın olmasına rağmen Güneydoğu Anadolu'nun sadece güneyinde varmış gibi görünmektedir. Üreme sezonunda, en az 2300 m'ye kadar genellikle kuru çalılıklarda ya da açık ağaçlık alanlarda bulunur. Geçiş sırasında biraz daha yaygındır. En azından mayıs ortasından kuzeyde eylül sonuna ve güneyde ekim sonuna kadar görülür. İstisna olarak 6 Mart 1970'te Alanya'da yorgun bir birey bulunmuştur. En geç kayıt ise 10 Kasım 1970'te yine aynı bölgeden Erdemli'dedir. Hem ilkbahar hem de sonbaharda, Uluabat ve Manyas gölleri ile Göksu Deltası'nda @berk1992a 40-100 bireylik gruplar kaydedilir. 26 Aralık 1996'da Sultansazlığı'nda bir kış kaydı iddiası vardır @kirwan1997d. Diğer kış kayıtları 20 Kasım 2010'da Şile İstanbul ve 3 Şubat 2011'de Bismil'in doğusundan gelir.

#box(image("images/harita_Caprimulgus europaeus.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Seyrek ağaçların bulunduğu ya da açık arazideki kuru çalılıklar, açık yaprak döken ve ibreli ormanlar, orman kenarları ve ağaçların yakınındaki açık alanlar, çalılık kıyı kumulları ve seyrek çalıların olduğu küçük, kayalık vadilerde ürer. Yuvalamak için çıplak, kuru zemine ihtiyaç duyar. \
#strong[Yuvası:] Yumurtalarını çıplak toprağa bırakır ve yuva malzemesi kullanmaz. \
#strong[Yumurta sayısı:] Genellikle iki yumurta bırakır. \
#strong[Üreme dönemi:] Mayıs başından eylül ayına kadar görülürler. Bu dönemde ötüşleri ve kanat çırpma kur davranışları gözlenir. Diğer bölgelerde olduğu gibi yılda iki kez kuluçkaya yattığı düşünülmektedir. #strong[AKD:] Toroslar'da 2300 metreye kadar görülür. 25 Mayıs 2004'te Akköy'de, yaklaşık 1 metre boyundaki çalıların arasında, çıplak toprak parçalarının olduğu bir yamaçtaki yuvasında, bir yumurtanın üstünde kuluçkada olan bir erişkin gözlenmiştir. Yumurtlamanın tamamlanmamış olduğu düşünülmektedir. #strong[İÇA:] 12 Mayıs 1970'te, Çay'da çalılıklarla kaplı bir yamaçta bir yuva bulunmuştur. #strong[GDA:] 9 Haziran 2004'te, 2250 metrede, Nemrut Dağı'ndaki en büyük kraterin yakınlarında, kayaların ve küçük, çıplak açıklıkların olduğu yaprak döken, seyrek ağaçlık bir alanda muhtemelen bir çift havalanmıştır. Dişi, yuvalamaya uygun çıplak bir zeminden havalanmış, yaklaşık 80 metre mesafede büyük bir kayanın üstünde dinlenen erkek kısa bir ötüş sergilemiş ve ardından uçmuştur.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de #emph[meridionalis] alttürü vardır ancak bu tür içindeki varyasyon klinaldir. #emph[Meridionalis] alttürünün geçerliliği ise tartışılmaktadır @vaurie1960a ve teşhisi zayıf temellidir.

== Çöl Çobanaldatanı
<çöl-çobanaldatanı>
#emph[Caprimulgus aegyptius], Egyptian Nightjar

#strong[#emph[Rastlantısal konuktur.]]

İlk kez 22 Nisan 2021'de Milleyha ve sahil şeridinde bir birey kaydedilmiş (#emph[E. Yoğurtcuoğlu]), 24 Nisan 2022'de aynı bölgede tekrar gözlenmiştir (#emph[E. Yoğurtcuoğlu]). 18 Nisan 2023'te bir birey daha kaydedilmiş (#emph[E. Yoğurtcuoğlu]), 15 Mayıs 2024'te yine aynı alanda görülen birey 18 Mayıs 2024'e kadar bölgede kalmıştır (#emph[E. Yoğurtcuoğlu]).

#box(image("images/harita_Caprimulgus aegyptius.png"))

#strong[Üreme]

Türkiye'de yuvalamaz. Orta Asya, Arabistan ve Kuzey Afrika çöllerinde yuvalar.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur.

== Ak Karınlı Ebabil
<ak-karınlı-ebabil>
#emph[Tachymarptis melba], Alpine Swift

#strong[#emph[Oldukça yaygın ve çok sayıda bulunan yaz konuğu ve geçit türüdür.]]

İstanbul'daki çok boldur ve Elazığ gibi birkaç başka şehirde de büyük kolonileri bilinmektedir. Deniz seviyesinden en az 2700 m'ye kadar ürer ancak çoğunlukla yaylalarda ve dağlık alanlarda kaydedilir. Özellikle Toroslar'da olmak üzere güneyde ve batıda en bol, kuzeyi ve doğusuyla sınırlı olduğu Güneydoğu Anadolu'da ise en azdır.

Lokal olarak önemli sayılarda kaydedildiği geçiş döneminde yaygındır. Düzenli olarak mart başı ya da ortasından itibaren kaydedilir. En erkeni 21'inde olmak üzere şubat sonunda üç kayıt vardır. Mart 1987 sonunda yüksek sayılar Çukurova üzerinden geçmiş @have_etal1988 ancak Göksu Deltası'nda 1971 ve 1973 yıllarında nisan başı ve ortasında yüksek sayılar kaydedilmiştir @ost1975. Sonbahar geçişi ağustos ortası ile ekim ortası arasında gerçekleşir; İstanbul Boğazı'nda eylülün ilk on günü @porter1983 ve Belen Geçidi'nde eylül ortasındaki iki hafta boyunca @sutherland1981b zirve yapar. Öte yandan, geriye kalanlar Trakya'da ekim sonuna kadar ve Akdeniz'de kasım sonuna kadar kaydedilir. Yüzlercesi, hatta binlercesi en az ekim sonuna kadar İstanbul'da kalabilir. İstisna olarak, 1994'te 6 ve 19 Aralık'ta İstanbul'da kaydedilmiştir.

#box(image("images/harita_Tachymarptis melba.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Kayalıklarda (kıyı ve iç kesimlerde), yüksek binalarda, yıkıntılarda (örneğin Van Kalesi, Doğu Anadolu), köprüler gibi insan yapımı yapılarda ve Kapadokya'daki peri bacalarında kolonileri bulunur. Koloniler, birkaç çiftten yüzlerce çifte kadar değişebilir. Örneğin, İstanbul'da 20 metrelik bir binanın tavan arasında 12 çift, Hakkâri'nin batısında ise 300 çift kaydedilmiştir. \
#strong[Yuvası:] Kaya yüzeyindeki yarıklarda, genellikle ince çatlaklarda; bir çıkıntıda ya da doğrudan yarığa tutunmuş şekilde yuva yapar. Uçuş sırasında topladığı bitki artıkları ve tüyleri tükürükle yapıştırarak sığ bir kâse oluşturur. \
#strong[Yumurta sayısı:] Türkiye'de gözlenen yumurta sayısı 2 yuvada 1 yumurta, 3 yuvada 2 yumurta ve 6 yuvada 3 yumurta olarak kaydedilmiştir. 4 yuvada 3 yavru, 2 yuvada 2 yavru gözlenmiştir. \
#strong[Üreme dönemi:] Mayıs-temmuz ayları arasında tüm bölgelerde yuvalara giren erişkin bireyler gözlenmiştir. Türkiye'den yavruların yuvada kalma süresine dair kayıt yoktur ancak diğer bölgelerde yavruların 6-8 hafta yuvada kaldığı bilinmektedir. #strong[MAR:] 21 Nisan 1970'te İstanbul'da, bir duvarla ahşap kepenk arasında bir çiftin neredeyse tamamlanmış bir yuva yaptığı gözlenmiştir. 3 Haziran 1992'de üç yumurtalı iki yuva bulunmuştur. 2004'te, eski bir binanın tavan arasında yuvalanmış en az 10 çift ve dar, dikey bir yarık oluşturan ahşap süs raflarının bir yüzeyine tutturulmuş yuvalarda üreyen iki çift kaydedilmiştir. 7 Haziran 2004'te yuvadan ve yuvaya uçan erişkinler, ayrıca yuvadan uçarken çiftleşen bir çift gözlenmiştir. 27 Haziran 2004'te bir erişkinin iki kez yuvaya uçup iki kanadıyla sıkıca tutunduğu ve en az bir büyük yavruyu beslediği görülmüştür. 13 Haziran 2006'da, bu binada kullanılan sekiz yuva bulunmuş; 17 Mayıs 2007'de iki çiftin yuva yaptığı ve bir erişkinin kuluçkada olduğu kaydedilmiştir. 14 Haziran 2006'da, bir tavan arasındaki artıkların arasında en az 12 çiftin yuvalandığı gözlenmiş; üç yuvada sırasıyla üç yumurta, üç yeni yumurtadan çıkmış yavru ve yumurtlamanın mayıs ortasında gerçekleştiğini gösteren yaklaşık 4-5 günlük iki yavru görülmüştür. #strong[EGE:] 8 Mayıs 1950'de Çeşme yakınlarında, Ilıca'da bir kayanın yüzeyindeki dar bir çatlakta bir yumurtalı bir yuva kaydedilmiştir @mcneile1950. #strong[İÇA:] 14-15 Haziran 1977'de Göreme'de, bir güvercinliğin içinde 11 yuvanın görünür olduğu, 15 çiftlik bir koloni bulunmuştur. İki yuvanın sadece 30 cm mesafede olduğu bu kolonideki altı yuvada kuluçkanın ileri evresinde yumurtalar ve dört yuvada yeni yumurtadan çıkmış yavrular gözlenmiştir @schubert1979. 14 Haziran 1993'te, Göreme'de başka bir peri bacasında, dik bir duvarda boş ancak yumurtlamaya hazır bir yuva ve bir güvercin oyuğunun dibinde iki yumurtalı başka bir yuva bulunmuştur.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de nominat alttürü bulunur.

== Ebabil
<ebabil>
#emph[Apus apus], Common Swift

#strong[#emph[Yaygın ve çok sayıda bulunan yaz konuğudur.]]

Ülke genelinde şehirlerde ve köylerde, bazen de mağaralarda ve kayalıklarda yaygın olarak ürer. Karadeniz Bölgesi'nde nispeten seyrektir. Deniz seviyesinden en az 2300 m'ye kadar ürer. Daha çok nisan başından itibaren kaydedilmesine rağmen güneydeki birçok alana şubat sonundan itibaren gelmeye başlar. 1992'de Kızılırmak Deltası'nda geçişin nisan ortasında başladığı ve mayısın son iki haftasında zirve yaptığı belirtilmiştir @hustings1994. Öte yandan, güneyde geçiş muhtemelen nisan sonu ile mayısın ilk haftasının sonu arasında @have_etal1988, İç Anadolu ile Doğu Anadolu'da ise mayısın ilk iki haftasında zirve yapar.

Geçişi, geniş bir cepheden sürekli ve yüksek sayılarda olabilir. Örneğin, 7 Mayıs 2002'de Mardin'de sadece 15 dakikada 3000 birey sayılmıştır. Üreme alanlarını ağustos başında terk etmeye başlar. 1 Ağustos 1974'te Aşkale'de sıradışı bir şekilde yaklaşık 10.000 birey kaydedilmiştir. Ağustos sonunda çoğu gitmiş olur: 1976'da Belen Geçidi'ndeki en yoğun geçiş 19-29 Ağustos'ta olmuştur @sutherland1981b. Eylül sonuna kadar nadir olsa da yaygın olarak kalabilir. İstanbul'da ekim sonuna ve İç Anadolu'da kasım ortasına kadar kaydedilmesine rağmen 1960 ortalarında İstanbul Boğazı'nda 10 Eylül'e kadar büyük çoğunluğunun gitmiş olduğu Porter tarafından gözlenmiştir. Ankara'da da Ağustos başında büyük çoğunluğu ayrılmış olur. İlkbahar göçünde Şubat sonunda Hatay'da görülür, Ankara'da ise 1 Nisan gibi görülmeye başlar.

#box(image("images/harita_Apus apus.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Çoğunlukla şehir, kasaba ve köylerde yuvalar. Hem kıyılardaki adalarda hem de iç kesimlerdeki vadi ve kanyonlarda, uzak yerlerdeki kayalıklarda ürer. Koloniler, birkaç çiftten Uludağ'da 1900 metrede otel çatılarında üreyen 200 kuşa kadar çeşitlilik gösterir @jetz1995. \
#strong[Yuvası:] Genellikle yüksek binalarda, çatıların içinde ve saçakların altında, yıkıntılarda, köprü altlarında ve kayalıklardaki deliklerde ve yarıklarda yuva yapar. Uçuş sırasında topladığı otları, artıkları ve tüyleri tükürükle birleştirerek sığ bir kâse şeklinde yaptığı yuvası bir çıkıntıda ya da düz bir zeminde bulunur. \
#strong[Yumurta sayısı:] Türkiye'den net kayıt bulunmamaktadır ancak diğer bölgelerde genellikle 2-3 yumurta bırakır. \
#strong[Üreme dönemi:] Mayıs ayında yumurta koyar, yavrular temmuz sonunda uçmuş olur. Üreme döngüsünün tamamı (tek kuluçka) 8-10 hafta sürer ki bu süre küçük bir kuş için oldukça uzundur. #strong[MAR:] 26 Haziran 1973'te Gülpınar'da, yuva malzemesi taşıyan bir erişkin gözlenmiştir. #strong[EGE:] 8 Mayıs 1950'de Çeşme yakınlarında, Ilıca açıklarındaki iki kayalık adacık ziyaret edilmiş, bir yumurtalı bir yuva (tamamlanmamış kuluçka) ve alçak kayalıklarda yatay bir çatlakta üç yumurtalı başka bir yuva bulunmuştur @mcneile1950. #strong[İÇA:] 19 Nisan 1967'de Eber Gölü'nde, 24 Nisan 1967'de Akşehir Gölü'nde ve 15 Mayıs 2004'te Cihanbeyli'de uçarken çiftleşen erişkinler gözlenmiştir. 24 Haziran 1998'de Cihanbeyli'de, İnkuyu Vadisi'nde kayalıklarda yuvalanmış bireyler kaydedilmiştir. #strong[İÇA:] 19 Nisan 1967'de Eber Gölü'nde, 24 Nisan 1967'de Akşehir Gölü'nde ve 15 Mayıs 2004'te Cihanbeyli'de uçarken çiftleşen erişkinler gözlenmiştir. 24 Haziran 1998'de Cihanbeyli'de, İnkuyu Vadisi'nde kayalıklarda yuvalanmış bireyler kaydedilmiştir. #strong[DOA:] 13 Mayıs 1970'te Ardahan yakınlarında, bir kayalıkta muhtemelen bir ev kırlangıcına ait çamurdan yapılmış bir yuvaya giren bir erişkin görülmüştür. 5 Ağustos 1966'da Van'da olmak üzere, mayıs-temmuz ayları arasında yuva deliklerine uçan erişkinler gözlenmiştir.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de çoğunlukla nominat alttürü bulunur. Ancak #emph[pekinensis] alttürünün de göçü sırasında Afrika'dan Çin'e göç ederken Doğu Anadolu'dan geçtiği tespit edilmiştir. Bu Doğu Anadolu'daki daha açık renkli bireylerin #emph[pekinensis] genlerini taşıdığı düşünülür @zhao2022. Muhtemelen Doğubeyazıt'ta kaydedilen Boz Ebabil kayıtları bu popülasyona aittir.

== Boz Ebabil
<boz-ebabil>
#emph[Apus pallidus], Pallid Swift

#strong[#emph[Nispeten yaygın ve yer yer çok sayıda bulunan yaz konuğudur.]]

Durumu nispeten belirsizdir. Türkiye'de ilk kez, Amik Gölü ile Birecik, Halfeti ve Urfa'daki gözlemlere dayanarak belgelenmiştir @kumerloeve1966d@kumerloeve1970a. 1966-67'de Uludağ'da (şimdi burada üreyen küçük bir popülasyon olduğu bilinmektedir), İstanbul'da ve İstanbul Boğazı'nda ilk gözlemler yapılmıştır @ost1969. İstanbul ve Uludağ'da, 1800-2500 m'de nispeten az sayıda kaydedilen bir yaz konuğudur. Artık İstanbul'da, Asya yakasında Kadıköy'le Bostancı arasında, Avrupa yakasında ise Bakırköy'le Ataköy arasında oldukça bol olarak ürediği bilinmektedir. Başka yerlerden daha nadir olarak bildirilir, en sık doğu Akdeniz'in uç kesimleri @ost1975@ost1978@beaman1986@martins1989 ve Güneydoğu Anadolu'nun Akdeniz'e bitişik bölgelerinde (Nemrut Dağı yakınları (Adıyaman) gibi muhtemelen ürediği yerlerde) kaydedilir. Ayrıca, güneybatı kıyıları ile Karadeniz'in güneybatısında da yaz aylarında potansiyel üreme habitatlarında kaydedilir.

Nisan başında Göksu Deltası'nda 150 bireye kadar kaydedilmesine rağmen özellikle batıda ve güneyde olmak üzere diğer alanlarda nadir bir geçiş türüdür. İlkbaharda nisan başından itibaren kaydedilir, 27 Şubat'ta Akdeniz'de bir kaydı vardır. Sonbaharda, ağustos ortasından eylül sonu/ekim başına kadar geçiş yapar. Bazen Batı Karadeniz'den ekim ortasına kadar ve İstanbul'dan ise Ekim sonuna kadar geçer. 21 Eylül 1987'de Uludağ'da bir günde 150 birey ve 2 Ekim 1997'de İstanbul Boğazı'nda 85 birey sayılmıştır.

22 Mayıs 1985'te, İshak Paşa Sarayı'nda üreyen birkaç çift kaydedilmiş, fakat sonraki değerlendirmelere göre bunların Ebabil'in #emph[pekinensis] alttürüne geçiş yapan bireyler olduğuna karar verilmiştir.

#box(image("images/harita_Apus pallidus.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Diğer bölgelerde, kayalıklardaki, duvarlardaki ve çatılardaki çatlaklarda yuva yapar. \
#strong[Yuvası:] Uçuş sırasında topladığı otları ve tüyleri tükürükle yapıştırarak sığ bir kâse şeklinde yuva oluşturur ve bu yuvaya 2-3 yumurta bırakır. #emph[Apus apus] genellikle şehirlerin eski bölümlerinde, dar sokaklardaki eski binalarda ve insan yapımı yapılarda (duvarlar gibi) ürerken, boz ebabil İstanbul'da 1980'den sonra yapılmış nispeten yeni binaları tercih etmektedir. \
#strong[Yumurta sayısı:] Türkiye'den kayıt bulunmamaktadır ancak diğer bölgelerde genellikle 2-3 yumurta bırakır. \
#strong[Üreme dönemi:] Muhtemel üreme sezonunda, mayıs sonu ile ağustos arasında görülür. Türkiye'de yuvası ve kuluçka büyüklüğü tanımlanmamıştır. #strong[MAR:] 1967'den bu yana, Uludağ'da 1850 metrede bazı binaların çatısına ebabillerle birlikte giren 25-40 birey düzenli olarak gözlenmektedir.

#strong[Alttürler ve Sınıflandırma]

Muhtemelen biraz daha koyu tüy örtüsü (her ne kadar #emph[brehmorum] alttürü içinde de kayda değer bir varyasyon olduğu bilinse de), daha belirgin soluk boğaz lekesi ve toplamda daha büyük olan #emph[illyricus] alttürü ile yer değiştirdiği Dalmaçya kıyıları dışında #emph[brehmorum] alttürü vardır @chantler1995@delhoyo1999. Bu #emph[illyricus] alttürünün zayıf bir şekilde farklılaştığı ile ilgili değerlendirmesine @vaurie1965 geçerlidir. Nisan ayında Greco Burnu'ndan (Kıbrıs) alınan ve Tring Doğa Tarihi Müzesi'nde bulunan bir örnek (1951.13.740) #emph[illyricus] alttürü ile çok iyi uyuşmakta ve bu formun Türkiye'de bulunabileceğini göstermektedir. Nominat #emph[pallidus] alttürü doğuda bulunabilir @roselaar1995. Çok yıprandığında tüy örtüsü her iki yüzeyde de çok soluk olabilir ve bu durum #emph[pallidus] formunun orada bulunabileceğini düşündürecek şekilde güneydoğuda yaz ortasında gözlediğimiz kuşlarla uyumludur. Daha önce de belirtildiği gibi, #emph[illyricus] ve #emph[brehmorum] alttürleri arasındaki farklılaşma açık şekilde çok hafiftir ancak hem bu formlar arasındaki hem de bu formlarla nominat #emph[pallidus] alttürü arasında marjinal olan varyasyon örtüşmenin derecesiyle belirsizleşir ve muhtemelen yıpranmadan çok etkilenir. Burada kabul edilen şartlar altında, #emph[brehmorum] ve #emph[illyricus] formlarını nominat pallidus alttürünün sinonimleri olarak kabul etmek en iyisidir.

== Küçük Ebabil
<küçük-ebabil>
#emph[Apus affinis], Little Swift

#strong[#emph[Lokal ve oldukça çok sayıda bulunan yaz konuğu ve lokal yerlidir.]]

Çok lokal ve genellikle nadir bir yaz konuğudur. Atatürk Barajı kadar kuzeyde bulunduğu göz önüne alınırsa Doğu Anadolu'nun güneybatısındaki bitişik alanlarda da üremesi olasıdır. En büyük kolonileri Birecik ve Halfeti'de Fırat nehri kıyısındaki kayalıklarda ve buralardan uzakta Kilis'tedir. Göksu ve Çukurova Deltaları ile Mersin gibi birkaç komşu bölgede de kaydedildiği geçiş sırasında biraz daha yaygındır. İlkbaharda, mart ortasından en az nisan sonuna kadar geçiş yapar ve sadece geçiş yaptığı yerlerde düzenli olarak 20 bireye kadar kaydedilir. Sonbaharda, eylül ortasında çoğu gitmiş olur, nadiren eylül sonuna kadar kaydedilir. Son zamanlardaki üç kış kaydı iddiası muhtemelen kışın dağıldığı bilinen İsrail'in kuzeyindeki yerli popülasyona aittir @delhoyo1999: bu kayıtların ikisi 6 Ocak 2007'de Antakya'dandır. Aynı yerde 4 Ocak'ta ve 13 Ocak 2008'de altışar tane kaydedilmiştir.

2 Temmuz 1970'te İskenderun Körfezi yakınlarında kaydedilen 8-10 birey yanlışlıkla Türkiye için ilk kayıt olarak bildirilmiştir (OST Bull. 7:1). 1881 yazında Antakya'da bir örnek alınmış @chantre1883ve Ağustos 1871'de Büyük Ağrı Dağı yakınlarında muhtemelen şüpheli olarak gözlenmiştir @radde1884 . İlk güncel kayıt Nisan 1962'dedir @eggers1964@kumerloeve1966d ve 1970'lerin sonunda Akdeniz kıyılarında veya yakınlarında en az 11 güvenilir kayıt elde edilmiştir @kumerloeve1970a.

#box(image("images/harita_Apus affinis.png"))

#strong[Üreme]

#strong[Yuvalama Alanı:] Kayalıkların ve dar vadilerin bulunduğu kuru alanlarda ürer. \
#strong[Yuvası:] Genellikle kayalıklarda, bir çıkıntının altına ya da bir oyuğun veya mağaranın tepesine tutturulur. Diğer bölgelerde (örneğin Fas ve İsrail) binalar ve yapılar gibi korunaklı alanlara yuva yaptığı kaydedilmiştir ancak Türkiye'de böyle bir kayıt yoktur. Uçuş sırasında topladığı otları ve tüyleri tükürükle yapıştırarak küre şeklinde yaptığı yuvasını, ince otlar ve tüylerle kaplar. Tek bir yuva olabileceği gibi birkaç yuva birbirine yapışık da olabilir. Her yuvanın ayrı bir girişi ve boşluğu bulunur ancak yuvaların tamamı bitişik bir kütle oluşturur. Ayrıca, çamurdan yapılmış eski ve genellikle kısmen yıpranmış ev kırlangıcı yuvalarının içine de yuva yaparlar. Aynı yuvayı onarıp art arda yıllarca kullanabilirler ancak bu konuda Türkiye'de veri yoktur. \
#strong[Yumurta sayısı:] Türkiye'de gözlenen yumurta sayısına dair veri bulunmamaktadır. Diğer bölgelerde olağan kuluçka büyüklüğü 2-3 yumurtadır. \
#strong[Üreme dönemi:] Nisan ve mayıs arasında yumurta koyar. Koloniler temmuz başına kadar aktiftir. Üreme döngüsü, küçük bir tür için oldukça uzundur. İlk yumurtanın bırakılmasından yavrunun yuvayı terk etmesine kadar geçen süre yaklaşık 9 haftadır ve genellikle yılda iki kez kuluçkaya yatar. #strong[AKD:] 11 Nisan 1971'de İskenderun yakınlarında, dar bir vadideki mağarada üreyen yaklaşık 15 çift kaydedilmiştir @warncke1972beitrag.#strong[GDA:] En iyi bilinen üreme alanlarından biri Birecik'tedir. Fırat Nehri'nin doğu kıyısındaki ve yakınlardaki vadilerde yüksek kayalıklarda küçük koloniler bulunmaktadır. 23 Mayıs 2004'te Birecik'te yaklaşık 15 yuvalı bir koloni gözlenmiştir. Bu kolonide üç yuvanın bireysel, dört yuvanın eski ev kırlangıcı yuvalarının içinde ve yaklaşık sekiz yuvanın bir kütle halinde birleşik olduğu kaydedilmiştir. En erken üreme kaydı, Suriye sınırı yakınlarında, Kilis'te bir kayalıktaki mağarada 7 Nisan 1971'de bulunan 25 çifttir. Aynı bölgede 19 Ağustos 1972'de 60 birey gözlenmiştir. 14 Mayıs 1989'da Kilis yakınlarında üremeye uygun habitatlarda 120 birey kaydedilmiştir. 1973 yazında Birecik'te toplam 62 çift üremiştir. 19 Nisan 1988'de Birecik'teki yuvaların hâlâ boş olduğu görülmüştür. Burada mayıs-ağustos ayları arasında birçok yuvada erişkin bireyler kaydedilmiş, erişkinlerin 7 Eylül 1994'e kadar yuvalarına girdikleri gözlenmiştir. 8 Temmuz 1986'da Siirt yakınlarında 20 bireyden oluşan bir koloni bulunmuştur.

#strong[Alttürler ve Sınıflandırma]

Türkiye'de #emph[galilejensis] alttürü bulunur.

#set bibliography(style: "nature.csl")

#bibliography(("references.bib"))

