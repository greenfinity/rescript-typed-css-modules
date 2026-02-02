// Generated from Theme.global.css
// Do not edit manually

type t = {
  "dark-mode": string,
  "light-mode": string,
  "primary-color": string
}

@module("./Theme.global.css") external _imported: t = "default"

// Access class names from the fields of the css object.
// For all classes, the class name is returned as-is: no scoping.
// Classes from @import are also available.

@new external proxy: ('a, 'b) => 'c = "Proxy"
type empty = {}
%%private(
  let withProxy = (obj: empty): t =>
    proxy(
      obj,
      {
        "get": (_: empty, className: string): string => className,
      },
    )
)
let css = withProxy({})
