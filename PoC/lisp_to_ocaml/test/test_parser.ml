open Lisp_to_ocaml
open Lisp_to_ocaml.Lisp_ast
open Lisp_to_ocaml.Parser
module T = Lisp_type

(* ================================ *)
(* 整数リテラルのパース *)
(* ================================ *)

let test_parse_int () =
  let input = "(def x 42)" in
  let result = parse input in
  match result with
  | Decl (Def (Val (Bind _), Int 42)) -> Alcotest.(check pass) "parse integer" () ()
  | _ -> Alcotest.fail "Expected integer literal"


let test_parse_negative_int () =
  let input = "(def x -10)" in
  let result = parse input in
  match result with
  | Decl (Def (Val (Bind _), Int -10)) ->
    Alcotest.(check pass) "parse negative integer" () ()
  | _ -> Alcotest.fail "Expected negative integer literal"


(* ================================ *)
(* 真偽値リテラルのパース *)
(* ================================ *)

let test_parse_bool_true () =
  let input = "(def x true)" in
  let result = parse input in
  match result with
  | Decl (Def (Val (Bind _), Bool true)) -> Alcotest.(check pass) "parse true" () ()
  | _ -> Alcotest.fail "Expected true literal"


let test_parse_bool_false () =
  let input = "(def x false)" in
  let result = parse input in
  match result with
  | Decl (Def (Val (Bind _), Bool false)) -> Alcotest.(check pass) "parse false" () ()
  | _ -> Alcotest.fail "Expected false literal"


(* ================================ *)
(* 関数定義のパース *)
(* ================================ *)

let test_parse_simple_function () =
  let input = "(def (f x) (+ x 1))" in
  let result = parse input in
  match result with
  | Decl (Def (Func (_, [ Bind _ ], T.Inferred), FnAp _)) ->
    Alcotest.(check pass) "parse simple function" () ()
  | _ -> Alcotest.fail "Expected simple function definition"


let test_parse_function_with_type () =
  let input = "(def (f x) : Int (+ x 1))" in
  let result = parse input in
  match result with
  | Decl (Def (Func (_, [ Bind _ ], T.Int), FnAp _)) ->
    Alcotest.(check pass) "parse function with type" () ()
  | _ -> Alcotest.fail "Expected function with type annotation"


let test_parse_function_with_typed_param () =
  let input = "(def (f (x : Int)) : Int (+ x 1))" in
  let result = parse input in
  match result with
  | Decl (Def (Func (_, [ TypedBind (_, T.Int) ], T.Int), FnAp _)) ->
    Alcotest.(check pass) "parse function with typed parameter" () ()
  | _ -> Alcotest.fail "Expected function with typed parameter"


(* ================================ *)
(* let式のパース *)
(* ================================ *)

let test_parse_let_simple () =
  let input = "(let (x 10) x)" in
  let result = parse input in
  match result with
  | Expr (Let ([ (Val (Bind _), Int 10) ], Sym _)) ->
    Alcotest.(check pass) "parse simple let" () ()
  | _ -> Alcotest.fail "Expected simple let expression"


let test_parse_let_multiple_bindings () =
  let input = "(let (x 10 y 20) (+ x y))" in
  let result = parse input in
  match result with
  | Expr (Let ([ (Val (Bind _), Int 10); (Val (Bind _), Int 20) ], FnAp _)) ->
    Alcotest.(check pass) "parse let with multiple bindings" () ()
  | _ -> Alcotest.fail "Expected let with multiple bindings"


let test_parse_let_with_type () =
  let input = "(let ((x : Int) 10) x)" in
  let result = parse input in
  match result with
  | Expr (Let ([ (Val (TypedBind (_, T.Int)), Int 10) ], Sym _)) ->
    Alcotest.(check pass) "parse let with type" () ()
  | _ -> Alcotest.fail "Expected let with type annotation"


let test_parse_let_function () =
  let input = "(let ((f x) (+ x 1)) (f 10))" in
  let result = parse input in
  match result with
  | Expr (Let ([ (Func (_, [ Bind _ ], T.Inferred), FnAp _) ], FnAp _)) ->
    Alcotest.(check pass) "parse let with function binding" () ()
  | _ -> Alcotest.fail "Expected let with function binding"


(* ================================ *)
(* fn式のパース *)
(* ================================ *)

let test_parse_fn_simple () =
  let input = "(fn (x) x)" in
  let result = parse input in
  match result with
  | Expr (Fn ([ Bind _ ], T.Inferred, Sym _)) ->
    Alcotest.(check pass) "parse simple fn" () ()
  | _ -> Alcotest.fail "Expected simple fn expression"


let test_parse_fn_with_type () =
  let input = "(fn (x) : Int x)" in
  let result = parse input in
  match result with
  | Expr (Fn ([ Bind _ ], T.Int, Sym _)) ->
    Alcotest.(check pass) "parse fn with type" () ()
  | _ -> Alcotest.fail "Expected fn with type annotation"


let test_parse_fn_with_typed_param () =
  let input = "(fn ((x : Int)) x)" in
  let result = parse input in
  match result with
  | Expr (Fn ([ TypedBind (_, T.Int) ], T.Inferred, Sym _)) ->
    Alcotest.(check pass) "parse fn with typed parameter" () ()
  | _ -> Alcotest.fail "Expected fn with typed parameter"


(* ================================ *)
(* if式のパース *)
(* ================================ *)

let test_parse_if () =
  let input = "(if true 1 0)" in
  let result = parse input in
  match result with
  | Expr (If (Bool true, Int 1, Int 0)) ->
    Alcotest.(check pass) "parse if expression" () ()
  | _ -> Alcotest.fail "Expected if expression"


(* ================================ *)
(* match式のパース *)
(* ================================ *)

let test_parse_match_simple () =
  let input = "(match x 0 1 _ 2)" in
  let result = parse input in
  match result with
  | Expr (Match (Sym _, [ (Int 0, Int 1); (Wildcard, Int 2) ])) ->
    Alcotest.(check pass) "parse simple match" () ()
  | _ -> Alcotest.fail "Expected simple match expression"


let test_parse_match_list () =
  let input = "(match lst [] 0 (x :: xs) 1)" in
  let result = parse input in
  match result with
  | Expr (Match (Sym _, [ (List [], Int 0); (Cons (Bind _, Bind _), Int 1) ])) ->
    Alcotest.(check pass) "parse match with list patterns" () ()
  | _ -> Alcotest.fail "Expected match with list patterns"


(* ================================ *)
(* リストのパース *)
(* ================================ *)

let test_parse_empty_list () =
  let input = "[]" in
  let result = parse input in
  match result with
  | Expr (List []) -> Alcotest.(check pass) "parse empty list" () ()
  | _ -> Alcotest.fail "Expected empty list"


let test_parse_list_literal () =
  let input = "[1 2 3]" in
  let result = parse input in
  match result with
  | Expr (List [ Int 1; Int 2; Int 3 ]) ->
    Alcotest.(check pass) "parse list literal" () ()
  | _ -> Alcotest.fail "Expected list literal"


(* ================================ *)
(* 型注釈のパース *)
(* ================================ *)

let test_parse_arrow_type () =
  let input = "(def (f x) : (Int -> Int) x)" in
  let result = parse input in
  match result with
  | Decl (Def (Func (_, _, T.Arrow (T.Int, T.Int)), _)) ->
    Alcotest.(check pass) "parse arrow type" () ()
  | _ -> Alcotest.fail "Expected arrow type"


let test_parse_list_type () =
  let input = "(def x : [Int] [])" in
  let result = parse input in
  match result with
  | Decl (Def (Val (TypedBind (_, T.List T.Int)), List [])) ->
    Alcotest.(check pass) "parse list type" () ()
  | _ -> Alcotest.fail "Expected list type"


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
      , [ test_case "parse arrow type" `Quick test_parse_arrow_type
        ; test_case "parse list type" `Quick test_parse_list_type
        ] )
    ]
