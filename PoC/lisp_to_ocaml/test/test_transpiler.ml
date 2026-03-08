open Lisp_to_ocaml.Lisp_ast
open Lisp_to_ocaml.Transpiler
open Parsetree

(** 構造をOCamlコード文字列に変換する *)
let structure_to_string (structures : structure) : string =
  let buf = Buffer.create 1024 in
  let fmt = Format.formatter_of_buffer buf in
  Pprintast.structure fmt structures;
  Format.pp_print_flush fmt ();
  Buffer.contents buf


(** lisp式をOCamlコード文字列に変換する *)
let transpile_to_string (lisp_program : lisp list) : string =
  let structures = List.concat_map to_structure lisp_program in
  structure_to_string structures


(** ファイルの内容を読み込む *)
let read_file (path : string) : string =
  let ic = open_in path in
  let len = in_channel_length ic in
  let content = really_input_string ic len in
  close_in ic;
  content


(** 生成されたコードと期待されるファイルの内容を比較するテスト *)
let test_transpile_from_file
      (name : string)
      (lisp_program : lisp list)
      (expected_file : string)
      ()
  =
  let actual = transpile_to_string lisp_program in
  let expected = read_file expected_file in
  Alcotest.(check string) name expected actual


(** 整数値の定義のテスト *)
let test_int () =
  let program = [ Decl (Def (Val "n", Int 42)) ] in
  let expected_file = "expected/int.ml" in
  test_transpile_from_file "int definition" program expected_file ()


(** 真偽値の定義のテスト *)
let test_bool () =
  let program = [ Decl (Def (Val "flag", Bool true)) ] in
  let expected_file = "expected/bool.ml" in
  test_transpile_from_file "bool definition" program expected_file ()


(** リストの定義のテスト *)
let test_list () =
  let program = [ Decl (Def (Val "nums", List [ Int 1; Int 2; Int 3 ])) ] in
  let expected_file = "expected/list.ml" in
  test_transpile_from_file "list definition" program expected_file ()


(** 関数定義のテスト *)
let test_function () =
  let program =
    [ Decl (Def (Fn ("add", [ "x"; "y" ]), FnAp [ Sym "+"; Sym "x"; Sym "y" ])) ]
  in
  let expected_file = "expected/function.ml" in
  test_transpile_from_file "function definition" program expected_file ()


(** 再帰関数のテスト *)
let test_recursive_function () =
  let program =
    [ Decl
        (Def
           ( Fn ("fact", [ "n" ])
           , If
               ( FnAp [ Sym "="; Sym "n"; Int 0 ]
               , Int 1
               , FnAp
                   [ Sym "*"
                   ; Sym "n"
                   ; FnAp [ Sym "fact"; FnAp [ Sym "-"; Sym "n"; Int 1 ] ]
                   ] ) ))
    ]
  in
  let expected_file = "expected/recursive_function.ml" in
  test_transpile_from_file "recursive function" program expected_file ()


(** let式のテスト（単一、ネスト、複数束縛） *)
let test_let () =
  let program =
    [ (* 単一let *)
      Decl
        (Def
           (Fn ("calc1", []), Let ([ Val "x", Int 10 ], FnAp [ Sym "+"; Sym "x"; Int 5 ])))
    ; (* ネストlet *)
      Decl
        (Def
           ( Fn ("calc2", [])
           , Let
               ( [ Val "x", Int 10; Val "y", FnAp [ Sym "+"; Sym "x"; Int 5 ] ]
               , FnAp [ Sym "+"; Sym "x"; Sym "y" ] ) ))
    ; (* 複数束縛let *)
      Decl
        (Def
           ( Fn ("calc3", [])
           , Let
               ( [ Val "x", Int 10; Val "y", Int 20; Val "z", Int 30 ]
               , FnAp [ Sym "+"; Sym "x"; FnAp [ Sym "+"; Sym "y"; Sym "z" ] ] ) ))
    ]
  in
  let expected_file = "expected/let.ml" in
  test_transpile_from_file "let expressions" program expected_file ()


(** if式のテスト *)
let test_if () =
  let program =
    [ Decl
        (Def
           ( Fn ("abs", [ "x" ])
           , If
               ( FnAp [ Sym "<"; Sym "x"; Int 0 ]
               , FnAp [ Sym "-"; Int 0; Sym "x" ]
               , Sym "x" ) ))
    ]
  in
  let expected_file = "expected/if.ml" in
  test_transpile_from_file "if expression" program expected_file ()


(** match式のテスト *)
let test_match () =
  let program =
    [ Decl
        (Def
           ( Fn ("list_sum", [ "lst" ])
           , Match
               ( Sym "lst"
               , [ List [], Int 0
                 ; ( Cons (Bind "x", Bind "xs")
                   , FnAp [ Sym "+"; Sym "x"; FnAp [ Sym "list_sum"; Sym "xs" ] ] )
                 ] ) ))
    ]
  in
  let expected_file = "expected/match.ml" in
  test_transpile_from_file "match expression" program expected_file ()


(** テストスイート *)
let () =
  let open Alcotest in
  run
    "Transpiler"
    [ ( "basic values"
      , [ test_case "int" `Quick test_int
        ; test_case "bool" `Quick test_bool
        ; test_case "list" `Quick test_list
        ] )
    ; ( "functions"
      , [ test_case "function" `Quick test_function
        ; test_case "recursive function" `Quick test_recursive_function
        ] )
    ; ( "control flow"
      , [ test_case "let" `Quick test_let
        ; test_case "if" `Quick test_if
        ; test_case "match" `Quick test_match
        ] )
    ]
