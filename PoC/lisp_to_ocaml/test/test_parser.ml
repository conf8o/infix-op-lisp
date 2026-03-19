open Lisp_to_ocaml
open Lisp_to_ocaml.Lisp_ast
open Lisp_to_ocaml.Parser
module T = Lisp_type

let string_of_lisp_list lisp_list =
  lisp_list |> List.map Lisp_ast.lisp_to_string |> String.concat " "


let inspect_of_lisp_list lisp_list =
  lisp_list |> List.map Lisp_ast.inspect_lisp |> String.concat "\n"


let fail_parse parsed label =
  Alcotest.fail
  @@ Printf.sprintf
       "%s:\nPretty: %s\nInspect: %s"
       label
       (string_of_lisp_list parsed)
       (inspect_of_lisp_list parsed)


(* ================================ *)
(* 整数リテラルのパース *)
(* ================================ *)

let test_parse_int () =
  let input = "(def x 42)" in
  let result = parse input in
  match result with
  | Ok [ Decl (Def (Val (Bind _, _), Int 42)) ] ->
    Alcotest.(check pass) "parse integer" () ()
  | Ok fail -> fail_parse fail "Expected integer literal"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


let test_parse_negative_int () =
  let input = "(def x -10)" in
  let result = parse input in
  match result with
  | Ok [ Decl (Def (Val (Bind _, _), Int -10)) ] ->
    Alcotest.(check pass) "parse negative integer" () ()
  | Ok fail -> fail_parse fail "Expected negative integer literal"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


(* ================================ *)
(* 真偽値リテラルのパース *)
(* ================================ *)

let test_parse_bool_true () =
  let input = "(def x true)" in
  let result = parse input in
  match result with
  | Ok [ Decl (Def (Val (Bind _, _), Bool true)) ] ->
    Alcotest.(check pass) "parse true" () ()
  | Ok fail -> fail_parse fail "Expected true literal"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


let test_parse_bool_false () =
  let input = "(def x false)" in
  let result = parse input in
  match result with
  | Ok [ Decl (Def (Val (Bind _, _), Bool false)) ] ->
    Alcotest.(check pass) "parse false" () ()
  | Ok fail -> fail_parse fail "Expected false literal"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


(* ================================ *)
(* 関数定義のパース *)
(* ================================ *)

let test_parse_simple_function () =
  let input = "(def (f x) (+ x 1))" in
  let result = parse input in
  match result with
  | Ok [ Decl (Def (Func (_, [ Bind _, _ ], T.Inferred), FnAp _)) ] ->
    Alcotest.(check pass) "parse simple function" () ()
  | Ok fail -> fail_parse fail "Expected simple function definition"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


let test_parse_function_with_type () =
  let input = "(def (f x) : Int (+ x 1))" in
  let result = parse input in
  match result with
  | Ok [ Decl (Def (Func (_, [ Bind _, _ ], T.Int), FnAp _)) ] ->
    Alcotest.(check pass) "parse function with type" () ()
  | Ok fail -> fail_parse fail "Expected function with type annotation"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


let test_parse_function_with_typed_param () =
  let input = "(def (f (x : Int)) : Int (+ x 1))" in
  let result = parse input in
  match result with
  | Ok [ Decl (Def (Func (_, [ Bind _, T.Int ], T.Int), FnAp _)) ] ->
    Alcotest.(check pass) "parse function with typed parameter" () ()
  | Ok fail -> fail_parse fail "Expected function with typed parameter"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


(* ================================ *)
(* let式のパース *)
(* ================================ *)

let test_parse_let_simple () =
  let input = "(let (x 10) x)" in
  let result = parse input in
  match result with
  | Ok [ Expr (Let ([ (Val (Bind _, _), Int 10) ], Sym _)) ] ->
    Alcotest.(check pass) "parse simple let" () ()
  | Ok fail -> fail_parse fail "Expected simple let expression"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


let test_parse_let_multiple_bindings () =
  let input = "(let (x 10 y 20) (+ x y))" in
  let result = parse input in
  match result with
  | Ok [ Expr (Let ([ (Val (Bind _, _), Int 10); (Val (Bind _, _), Int 20) ], FnAp _)) ] ->
    Alcotest.(check pass) "parse let with multiple bindings" () ()
  | Ok fail -> fail_parse fail "Expected let with multiple bindings"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


let test_parse_let_with_type () =
  let input = "(let ((x : Int) 10) x)" in
  let result = parse input in
  match result with
  | Ok [ Expr (Let ([ (Val (Bind _, T.Int), Int 10) ], Sym _)) ] ->
    Alcotest.(check pass) "parse let with type" () ()
  | Ok fail -> fail_parse fail "Expected let with type annotation"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


let test_parse_let_function () =
  let input = "(let ((f x) (+ x 1)) (f 10))" in
  let result = parse input in
  match result with
  | Ok [ Expr (Let ([ (Func (_, [ Bind _, _ ], T.Inferred), FnAp _) ], FnAp _)) ] ->
    Alcotest.(check pass) "parse let with function binding" () ()
  | Ok fail -> fail_parse fail "Expected let with function binding"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


(* ================================ *)
(* fn式のパース *)
(* ================================ *)

let test_parse_fn_simple () =
  let input = "(fn (x) x)" in
  let result = parse input in
  match result with
  | Ok [ Expr (Fn ([ Bind _, _ ], T.Inferred, Sym _)) ] ->
    Alcotest.(check pass) "parse simple fn" () ()
  | Ok fail -> fail_parse fail "Expected simple fn expression"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


let test_parse_fn_with_type () =
  let input = "(fn (x) : Int x)" in
  let result = parse input in
  match result with
  | Ok [ Expr (Fn ([ Bind _, _ ], T.Int, Sym _)) ] ->
    Alcotest.(check pass) "parse fn with type" () ()
  | Ok fail -> fail_parse fail "Expected fn with type annotation"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


let test_parse_fn_with_typed_param () =
  let input = "(fn ((x : Int)) x)" in
  let result = parse input in
  match result with
  | Ok [ Expr (Fn ([ Bind _, T.Int ], T.Inferred, Sym _)) ] ->
    Alcotest.(check pass) "parse fn with typed parameter" () ()
  | Ok fail -> fail_parse fail "Expected fn with typed parameter"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


(* ================================ *)
(* if式のパース *)
(* ================================ *)

let test_parse_if () =
  let input = "(if true 1 0)" in
  let result = parse input in
  match result with
  | Ok [ Expr (If (Bool true, Int 1, Int 0)) ] ->
    Alcotest.(check pass) "parse if expression" () ()
  | Ok fail -> fail_parse fail "Expected if expression"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


(* ================================ *)
(* match式のパース *)
(* ================================ *)

let test_parse_match_simple () =
  let input = "(match x 0 1 _ 2)" in
  let result = parse input in
  match result with
  | Ok [ Expr (Match (Sym _, [ ((Int 0, _), Int 1); ((Wildcard, _), Int 2) ])) ] ->
    Alcotest.(check pass) "parse simple match" () ()
  | Ok fail -> fail_parse fail "Expected simple match expression"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


let test_parse_match_list () =
  let input = "(match lst [] 0 (x :: xs) 1)" in
  let result = parse input in
  match result with
  | Ok [ Expr (Match (Sym _, [ ((List [], _), Int 0); ((Cons ((Bind _, _), (Bind _, _)), _), Int 1) ])) ] ->
    Alcotest.(check pass) "parse match with list patterns" () ()
  | Ok fail -> fail_parse fail "Expected match with list patterns"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


(* ================================ *)
(* リストのパース *)
(* ================================ *)

let test_parse_empty_list () =
  let input = "[]" in
  let result = parse input in
  match result with
  | Ok [ Expr (List []) ] -> Alcotest.(check pass) "parse empty list" () ()
  | Ok fail -> fail_parse fail "Expected empty list"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


let test_parse_list_literal () =
  let input = "[1 2 3]" in
  let result = parse input in
  match result with
  | Ok [ Expr (List [ Int 1; Int 2; Int 3 ]) ] ->
    Alcotest.(check pass) "parse list literal" () ()
  | Ok fail -> fail_parse fail "Expected list literal"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


(* ================================ *)
(* 型注釈のパース *)
(* ================================ *)

let test_parse_int_type () =
  let input = "(def x : Int 1)" in
  let result = parse input in
  match result with
  | Ok [ Decl (Def (Val (Bind _, T.Int), Int 1)) ] ->
    Alcotest.(check pass) "parse int type" () ()
  | Ok fail -> fail_parse fail "Expected int type"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


let test_parse_arrow_type () =
  let input = "(def (f x) : (Int -> Int) x)" in
  let result = parse input in
  match result with
  | Ok [ Decl (Def (Func (_, _, T.Arrow (T.Int, T.Int)), _)) ] ->
    Alcotest.(check pass) "parse arrow type" () ()
  | Ok fail -> fail_parse fail "Expected arrow type"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


let test_parse_list_type () =
  let input = "(def x : [Int] [])" in
  let result = parse input in
  match result with
  | Ok [ Decl (Def (Val (Bind _, T.List T.Int), List [])) ] ->
    Alcotest.(check pass) "parse list type" () ()
  | Ok fail -> fail_parse fail "Expected list type"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


(* ================================ *)
(* 複数行のパース *)
(* ================================ *)

let test_parse_multiple_definitions () =
  let input =
    {|
    (def x 10)
    (def y 20)
    (def (add a b) (+ a b))
    (def result (add x y))
    |}
  in
  let result = parse input in
  match result with
  | Ok
      [ Decl (Def (Val (Bind _, _), Int 10))
      ; Decl (Def (Val (Bind _, _), Int 20))
      ; Decl (Def (Func (_, [ Bind _, _; Bind _, _ ], T.Inferred), FnAp _))
      ; Decl (Def (Val (Bind _, _), FnAp _))
      ] -> Alcotest.(check pass) "parse multiple definitions" () ()
  | Ok fail -> fail_parse fail "Expected multiple definitions"
  | Error msg -> Alcotest.fail ("Parse error: " ^ msg)


(* ================================ *)
(* テストスイート *)
(* ================================ *)

let () =
  let open Alcotest in
  run
    "Parser tests"
    [ ( "integer"
      , [ test_case "parse int" `Quick test_parse_int
        ; test_case "parse negative int" `Quick test_parse_negative_int
        ] )
    ; ( "boolean"
      , [ test_case "parse true" `Quick test_parse_bool_true
        ; test_case "parse false" `Quick test_parse_bool_false
        ] )
    ; ( "function"
      , [ test_case "parse simple function" `Quick test_parse_simple_function
        ; test_case "parse function with type" `Quick test_parse_function_with_type
        ; test_case
            "parse function with typed param"
            `Quick
            test_parse_function_with_typed_param
        ] )
    ; ( "let"
      , [ test_case "parse simple let" `Quick test_parse_let_simple
        ; test_case
            "parse let with multiple bindings"
            `Quick
            test_parse_let_multiple_bindings
        ; test_case "parse let with type" `Quick test_parse_let_with_type
        ; test_case "parse let function" `Quick test_parse_let_function
        ] )
    ; ( "fn"
      , [ test_case "parse simple fn" `Quick test_parse_fn_simple
        ; test_case "parse fn with type" `Quick test_parse_fn_with_type
        ; test_case "parse fn with typed param" `Quick test_parse_fn_with_typed_param
        ] )
    ; "if", [ test_case "parse if" `Quick test_parse_if ]
    ; ( "match"
      , [ test_case "parse simple match" `Quick test_parse_match_simple
        ; test_case "parse match list" `Quick test_parse_match_list
        ] )
    ; ( "list"
      , [ test_case "parse empty list" `Quick test_parse_empty_list
        ; test_case "parse list literal" `Quick test_parse_list_literal
        ] )
    ; ( "type"
      , [ test_case "parse int type" `Quick test_parse_int_type
        ; test_case "parse arrow type" `Quick test_parse_arrow_type
        ; test_case "parse list type" `Quick test_parse_list_type
        ] )
    ; ( "multiple"
      , [ test_case "parse multiple definitions" `Quick test_parse_multiple_definitions ]
      )
    ]
