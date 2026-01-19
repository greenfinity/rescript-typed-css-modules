(* Common utilities for rescript-typed-css-ppx *)

let read_file filepath = In_channel.with_open_bin filepath In_channel.input_all

let extract_css_class_names css_filepath =
  let parser_basename = "parser.bundle.js" in
  let parser_filepath =
    parser_basename |> Filename.concat (Filename.dirname Sys.argv.(0))
  in
  (* Make parser executable *)
  let _ =
    Filename.quote_command "chmod" [ "+x"; parser_filepath ] |> Sys.command
  in
  let temp_file_path = Filename.temp_file "css_class_names" ".txt" in
  let exit_code =
    Filename.quote_command "node" [ parser_filepath; css_filepath; temp_file_path ]
    |> Sys.command
  in
  if exit_code <> 0 then
    failwith ("Failed to parse CSS file: " ^ css_filepath)
  else
    let content = read_file temp_file_path in
    (* Clean up temp file *)
    Sys.remove temp_file_path;
    if String.length content = 0 then
      []
    else
      String.split_on_char ',' content
