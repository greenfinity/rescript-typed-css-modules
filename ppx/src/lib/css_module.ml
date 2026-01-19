(* CSS Module PPX extension - generates typed bindings with @module import *)
(* Based on typed-css-classes by ribeirotomas1904 (MIT License) *)

open Ppxlib
open Common

let extension_name = "css.module"

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

    (* @module("./path.css") attribute *)
    let module_attr =
      attribute ~name:{ txt = "module"; loc }
        ~payload:(PStr [ pstr_eval (estring css_path) [] ])
    in

    (* external css: <object_type> = "default" *)
    let value_description =
      {
        pval_name = { txt = var_name; loc };
        pval_type = object_type;
        pval_prim = [ "default" ];
        pval_attributes = [ module_attr ];
        pval_loc = loc;
      }
    in

    pstr_primitive value_description

let extension =
  Extension.V3.declare extension_name Extension.Context.structure_item extractor
    expander

let rule = Context_free.Rule.extension extension
