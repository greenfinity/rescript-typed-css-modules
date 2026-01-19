(* CSS Global PPX extension - generates typed bindings without @module import *)
(* For global CSS files where classes are not hashed/scoped *)
(* Based on typed-css-classes by ribeirotomas1904 (MIT License) *)

open Ppxlib
open Common

let extension_name = "css.global"

let extractor =
  Ast_pattern.(
    pstr
      (pstr_value nonrecursive
         (value_binding ~pat:(ppat_var __) ~expr:(estring __) ^:: nil)
      ^:: nil))

let expander ~ctxt var_name css_path =
  let loc = Expansion_context.Extension.extension_point_loc ctxt in
  let module Loc = struct
    let loc = loc
  end in
  let module Builder = Ast_builder.Make (Loc) in
  let source_file_dir =
    ctxt |> Expansion_context.Extension.input_name |> Filename.dirname
  in
  let css_filepath = Filename.concat source_file_dir css_path in

  let open Builder in
  if not (Sys.file_exists css_filepath) then
    pstr_extension
      (Location.error_extensionf ~loc "CSS file not found: %s" css_filepath)
      []
  else
    let class_names = extract_css_class_names css_filepath in

    (* Build object type with fields for each class name *)
    let object_type =
      let object_fields =
        class_names
        |> List.map (fun class_name ->
               otag { txt = class_name; loc } [%type: string])
      in
      ptyp_object object_fields Closed
    in

    (* For global CSS: Use %raw to generate the object literal *)
    (* Generate: let css: <type> = %raw(`{"class1": "class1", ...}`) *)
    let json_obj =
      let pairs = class_names |> List.map (fun name ->
        Printf.sprintf {|"%s": "%s"|} name name
      ) in
      "{" ^ String.concat ", " pairs ^ "}"
    in

    let raw_extension =
      pexp_extension ({ txt = "raw"; loc }, PStr [ pstr_eval (estring json_obj) [] ])
    in

    let typed_expr = pexp_constraint raw_extension object_type in

    let value_binding =
      {
        pvb_pat = ppat_var { txt = var_name; loc };
        pvb_expr = typed_expr;
        pvb_attributes = [];
        pvb_loc = loc;
      }
    in

    pstr_value Nonrecursive [ value_binding ]

let extension =
  Extension.V3.declare extension_name Extension.Context.structure_item extractor
    expander

let rule = Context_free.Rule.extension extension
