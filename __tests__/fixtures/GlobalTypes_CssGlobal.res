// Generated from GlobalTypes.global.css
// Do not edit manually

type t = {
  "another-shared": string,
  "btn": string,
  "foo": string,
  "shared-class": string
}

// Access class names from the fields of the css object.
// Import is not done, the css has to be manually imported
// from the top of the component hierarchy.
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
