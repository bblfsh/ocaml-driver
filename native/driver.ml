open Yojson.Basic
open Yojson.Basic.Util

let _ =
  try
    while true do
      let line_json = from_string (input_line stdin) in
      let encoding = line_json |> member "encoding" |> to_string
      and content = line_json |> member "content" |> to_string in
      let src = match encoding with
        | "UTF8" -> content
        | "Base64" -> B64.decode content
        | _ -> invalid_arg encoding
      in
      let ast = Parse.implementation (Lexing.from_string src) in
      let ast_json = Astjson.structure_to_yojson ast in
      print_endline (Yojson.Safe.to_string ast_json)
    done
  with
  | End_of_file -> ()
  | _ -> exit 1
