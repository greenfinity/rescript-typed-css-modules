(* rescript-typed-css-ppx - PPX for type-safe CSS modules in ReScript *)
(* MIT License *)

let () =
  Ppxlib.Driver.V2.register_transformation
    ~rules:[ Css_module.rule; Css_global.rule ]
    "rescript-typed-css-ppx"
