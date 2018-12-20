open Core
open Async
open Stationary
open Common

let roman n =
  let symbols =
    [ (1000, "M")
    ; (900, "CM")
    ; (500, "D")
    ; (400, "CD")
    ; (100, "C")
    ; (90, "XC")
    ; (50, "L")
    ; (40, "XL")
    ; (10, "X")
    ; (9, "IX")
    ; (5, "V")
    ; (4, "IV")
    ; (1, "I") ]
  in
  List.fold symbols ~init:([], n) ~f:(fun (acc, n) (base, name) ->
      let q, r = (n / base, n mod base) in
      (List.init q ~f:(Fn.const name) @ acc, r) )
  |> fst |> List.rev |> String.concat

let title s =
  let open Html_concise in
  h1 [Style.just "f2 f1-ns ddinexp tracked-tightish mb1"] [text s]

let subtitle s =
  let open Html_concise in
  h2 [Style.just "f4 f3-ns ddinexp mt0 mb4 fw4"] [text s]

let author s =
  let open Html_concise in
  h4
    [Style.just "f7 fw4 tracked-supermega ttu metropolis mt0 mb1"]
    [text ("by " ^ s)]

let date d =
  let month_day = Date.format d "%B %d" in
  let year = Date.year d in
  let s = month_day ^ " " ^ roman year in
  let open Html_concise in
  h4
    [Style.just "f7 fw4 tracked-supermega ttu o-50 metropolis mt0 mb35"]
    [text s]

module Share = struct
  open Html_concise
  let content = 
    let channels = [ 
        ("Twitter", "https://twitter.com/codaprotocol?lang=en") 
      ; ("Discord", "https://discord.gg/UyqY37F") 
      ; ("Telegram", "https://t.me/codaprotocol") 
      ] 
    in
    let channels = 
      List.map channels ~f:(fun (name,link) -> a [href link] [text name]) 
    in
    let channels =
      List.intersperse channels ~sep:(text "•")
    in
    h4 [Style.(render (of_class "share"))] 
      ([text "SHARE:"] @ channels)
end

let post name =
  let open Html_concise in
  let%map post = Post.load ("posts/" ^ name) in
  div
    [Style.just "ph3 ph4-m ph5-l"]
    [ div
        [Style.just "mw65-ns ibmplex f5 center blueblack"]
        ( title post.title
          :: (match post.subtitle with None -> [] | Some s -> [subtitle s])
        @ [ author post.author
          ; date post.date
          ; div
              [Stationary.Attribute.class_ "blog-content lh-copy"]
              [ post.content
              ; hr []
              (* HACK: to reuse styles from blog hr, we can just stick it in blog-content *)
               ]
          ; Share.content
          ; h4 [] [text "TODO: Disqus comments"] ] ) ]

let content name =
  let%map p = post name in
  wrap
    ~headers:
      [ Html.literal
          {html|<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.10.0/dist/katex.min.css" integrity="sha384-9eLZqc9ds8eNjO3TmqPeYcDj8n+Qfa4nuSiGYa6DjLNcv9BtN69ZIulL9+8CqC9Y" crossorigin="anonymous">|html}
      ; Html.literal
          {html|<script defer src="https://cdn.jsdelivr.net/npm/katex@0.10.0/dist/katex.min.js" integrity="sha384-K3vbOmF2BtaVai+Qk37uypf7VrgBubhQreNQe9aGsz9lB63dIFiQVlJbr92dw2Lx" crossorigin="anonymous"></script>|html}
      ; Html.literal
          {html|<link rel="stylesheet" href="/static/css/blog.css">|html}
      ; Html.literal
          {html|<script defer src="https://cdn.jsdelivr.net/npm/katex@0.10.0/dist/contrib/auto-render.min.js" integrity="sha384-kmZOZB5ObwgQnS/DuDg6TScgOiWWBiVt0plIRkZCmE6rDZGrEOQeHM5PcHi+nyqe" crossorigin="anonymous"
    onload="renderMathInElement(document.body);"></script>|html}
      ; Html.literal
          {html|<script>
            document.addEventListener("DOMContentLoaded", function() {
              var blocks = document.querySelectorAll(".katex-block code");
              for (var i = 0; i < blocks.length; i++) {
                var b = blocks[i];
                katex.render(b.innerText, b);
              }
            });
          </script>|html}
      ]
    ~tight:true ~fixed_footer:false
    ~page_label:Links.(label blog)
    [(fun _ -> p)]