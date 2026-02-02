// Generated from WithGlobal.module.scss
// Do not edit manually

type t = {
  "another-shared": string,
  "btn": string,
  "external-class": string,
  "shared-class": string
}

@module("./WithGlobal.module.scss") external css: t = "default"

// Access class names from the fields of the css object.
// For scoped classses, the hashed class name is returned.
// For :global() classes, the class name is returned as-is: no scoping.
// Classes from @import are also available.

@new external proxy: ('a, 'b) => 'c = "Proxy"
%%private(
  external toDict: t => dict<string> = "%identity"
  let withProxy = (obj: t): t =>
    proxy(
      obj,
      {
        // "get": (_b, _c): string => %raw("_b[_c] || _c"),
        "get": (base, className) =>
          switch base->toDict->Dict.get(className) {
          | Some(className) => className
          | None => className
          },
      },
    )
)
let css = withProxy(css)


