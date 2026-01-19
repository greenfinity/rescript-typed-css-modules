(* CSS Module PPX extension - generates typed bindings with @module import *)
(* Based on typed-css-classes by ribeirotomas1904 (MIT License) *)
(* Wraps import with Proxy to support :global() classes *)

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
  (* Use loc.loc_start.pos_fname for the original source path *)
  (* This works correctly during incremental builds where input_name *)
  (* points to a temporary copy in lib/bs/___incremental/ *)
  let source_file_dir =
    loc.loc_start.pos_fname |> Filename.dirname
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

    (* Internal name for the raw import *)
    let raw_var_name = "__css_" ^ var_name ^ "_raw" in

    (* @module("./path.css") attribute *)
    let module_attr =
      attribute ~name:{ txt = "module"; loc }
        ~payload:(PStr [ pstr_eval (estring css_path) [] ])
    in

    (* external __css_raw: <object_type> = "default" *)
    let raw_value_description =
      {
        pval_name = { txt = raw_var_name; loc };
        pval_type = object_type;
        pval_prim = [ "default" ];
        pval_attributes = [ module_attr ];
        pval_loc = loc;
      }
    in

    let external_decl = pstr_primitive raw_value_description in

    (* Proxy wrapper: new Proxy(obj, { get: (o, k) => o[k] || k }) *)
    (* This handles :global() classes that aren't in the bundler's export *)
    let proxy_js = Printf.sprintf
      {|new Proxy(%s, { get: (o, k) => o[k] || k })|}
      raw_var_name
    in

    let raw_extension =
      pexp_extension ({ txt = "raw"; loc }, PStr [ pstr_eval (estring proxy_js) [] ])
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

    let let_decl = pstr_value Nonrecursive [ value_binding ] in

    (* Return both declarations as an include of a module *)
    (* We need to return multiple structure items, so we wrap in a module *)
    pstr_include {
      pincl_mod = pmod_structure [ external_decl; let_decl ];
      pincl_loc = loc;
      pincl_attributes = [];
    }

let extension =
  Extension.V3.declare extension_name Extension.Context.structure_item extractor
    expander

let rule = Context_free.Rule.extension extension
