open Lisp_to_ocaml.Lisp_ast
open Lisp_to_ocaml.Type_checker
open Lisp_to_ocaml.Validation
module T = Lisp_to_ocaml.Lisp_type

let scope_counter = ref 0

let v name =
  incr scope_counter;
  make_var name ("__" ^ string_of_int !scope_counter)


let run checker env = run checker env

let assert_type_ok expected_type checker =
  let result = run checker (init_type_env ()) in
  match result with
  | Success actual_type ->
    Alcotest.(check bool) "type matches" true (expected_type = actual_type)
  | Failure _ -> Alcotest.fail "Expected success but got type error"


let assert_type_error checker =
  let result = run checker (init_type_env ()) in
  match result with
  | Success _ -> Alcotest.fail "Expected type error, but got success"
  | Failure _ -> ()


(** judge_name_type のテスト *)
let test_judge_name_type_builtin () =
  scope_counter := 0;
  let plus_var = top_var "+" in
  let checker = judge_name_type plus_var in
  assert_type_ok (T.Arrow (T.Int, T.Arrow (T.Int, T.Int))) checker


let test_judge_name_type_unbound () =
  scope_counter := 0;
  let unknown_var = v "unknown" in
  let checker = judge_name_type unknown_var in
  assert_type_error checker


(** judge_type のテスト *)
let test_judge_type_int () =
  let checker = judge_type (Expr (Int 42)) in
  assert_type_ok T.Int checker


let test_judge_type_bool () =
  let checker = judge_type (Expr (Bool true)) in
  assert_type_ok T.Bool checker


let test_judge_type_sym () =
  scope_counter := 0;
  let plus_var = top_var "+" in
  let checker = judge_type (Expr (Sym plus_var)) in
  assert_type_ok (T.Arrow (T.Int, T.Arrow (T.Int, T.Int))) checker


(** judge_fn_type のテスト *)
let test_judge_fn_type_simple () =
  scope_counter := 0;
  let x = v "x" in
  let args = [ Bind (x, T.Int) ] in
  let body = Sym x in
  let return_type = T.Int in
  let checker = judge_fn_type args (body, return_type) in
  assert_type_ok (T.Arrow (T.Int, T.Int)) checker


let test_judge_fn_type_multiple_args () =
  scope_counter := 0;
  let x = v "x" in
  let y = v "y" in
  let plus_var = top_var "+" in
  let args = [ Bind (x, T.Int); Bind (y, T.Int) ] in
  let body = FnAp [ Sym plus_var; Sym x; Sym y ] in
  let return_type = T.Int in
  let checker = judge_fn_type args (body, return_type) in
  assert_type_ok (T.Arrow (T.Int, T.Arrow (T.Int, T.Int))) checker


(** judge_fnap_type のテスト *)
let test_judge_fnap_type_empty () =
  let checker = judge_fnap_type [] in
  assert_type_ok T.Unit checker


let test_judge_fnap_type_single () =
  let checker = judge_fnap_type [ Int 42 ] in
  assert_type_ok T.Int checker


let test_judge_fnap_type_addition () =
  scope_counter := 0;
  let plus_var = top_var "+" in
  let items = [ Sym plus_var; Int 1; Int 2 ] in
  let checker = judge_fnap_type items in
  assert_type_ok T.Int checker


(** judge_fnap_result_type のテスト *)
let test_judge_fnap_result_type_single_arg () =
  let fn_type = T.Arrow (T.Int, T.Int) in
  let args = [ Int 42 ] in
  let checker = judge_fnap_result_type fn_type args in
  assert_type_ok T.Int checker


let test_judge_fnap_result_type_multiple_args () =
  let fn_type = T.Arrow (T.Int, T.Arrow (T.Int, T.Int)) in
  let args = [ Int 1; Int 2 ] in
  let checker = judge_fnap_result_type fn_type args in
  assert_type_ok T.Int checker


let test_judge_fnap_result_type_no_args () =
  let fn_type = T.Int in
  let args = [] in
  let checker = judge_fnap_result_type fn_type args in
  assert_type_ok T.Int checker


(** judge_let_type のテスト *)
let test_judge_let_type_single_binding () =
  scope_counter := 0;
  let x = v "x" in
  let bindings = [ Val (Bind (x, T.Int)), Int 42 ] in
  let body = Sym x in
  let checker = judge_let_type bindings body in
  assert_type_ok T.Int checker


let test_judge_let_type_multiple_bindings () =
  scope_counter := 0;
  let x = v "x" in
  let y = v "y" in
  let plus_var = top_var "+" in
  let bindings = [ Val (Bind (x, T.Int)), Int 10; Val (Bind (y, T.Int)), Int 20 ] in
  let body = FnAp [ Sym plus_var; Sym x; Sym y ] in
  let checker = judge_let_type bindings body in
  assert_type_ok T.Int checker


(** judge_if_type のテスト *)
let test_judge_if_type_simple () =
  let pred = Bool true in
  let then_expr = Int 1 in
  let else_expr = Int 2 in
  let checker = judge_if_type pred then_expr else_expr in
  assert_type_ok T.Int checker


let test_judge_if_type_with_comparison () =
  scope_counter := 0;
  let lt_var = top_var "<" in
  let pred = FnAp [ Sym lt_var; Int 1; Int 2 ] in
  let then_expr = Int 10 in
  let else_expr = Int 20 in
  let checker = judge_if_type pred then_expr else_expr in
  assert_type_ok T.Int checker


(** jugde_if_pred_type のテスト *)
let test_jugde_if_pred_type_bool () =
  let pred = Bool true in
  let checker = jugde_if_pred_type pred in
  assert_type_ok T.Bool checker


let test_jugde_if_pred_type_comparison () =
  scope_counter := 0;
  let eq_var = top_var "=" in
  let pred = FnAp [ Sym eq_var; Int 1; Int 1 ] in
  let checker = jugde_if_pred_type pred in
  assert_type_ok T.Bool checker


(** judge_match_type のテスト *)
let test_judge_match_type_int () =
  scope_counter := 0;
  let value = Int 42 in
  let cases : matching_case list = [ Int 0, Bool true; Wildcard, Bool false ] in
  let checker = judge_match_type value cases in
  assert_type_ok T.Bool checker


(** judge_common_type のテスト *)
let test_judge_common_type_all_same () =
  let checkers = [ judge_type (Expr (Int 1)); judge_type (Expr (Int 2)) ] in
  let expected = T.Int in
  let error (ty, seq_types) = BranchTypeMismatch (ty, seq_types) in
  let checker = judge_common_type checkers expected error in
  assert_type_ok T.Int checker


let test_judge_common_type_empty () =
  let checkers = [] in
  let expected = T.Int in
  let error (ty, seq_types) = BranchTypeMismatch (ty, seq_types) in
  let checker = judge_common_type checkers expected error in
  assert_type_ok T.Int checker


let () =
  let open Alcotest in
  run
    "Type Checker Tests"
    [ ( "judge_name_type"
      , [ test_case "builtin operator" `Quick test_judge_name_type_builtin
        ; test_case "unbound variable" `Quick test_judge_name_type_unbound
        ] )
    ; ( "judge_type"
      , [ test_case "integer literal" `Quick test_judge_type_int
        ; test_case "boolean literal" `Quick test_judge_type_bool
        ; test_case "symbol" `Quick test_judge_type_sym
        ] )
    ; ( "judge_fn_type"
      , [ test_case "simple function" `Quick test_judge_fn_type_simple
        ; test_case "multiple arguments" `Quick test_judge_fn_type_multiple_args
        ] )
    ; ( "judge_fnap_type"
      , [ test_case "empty application" `Quick test_judge_fnap_type_empty
        ; test_case "single expression" `Quick test_judge_fnap_type_single
        ; test_case "addition" `Quick test_judge_fnap_type_addition
        ] )
    ; ( "judge_fnap_result_type"
      , [ test_case "single argument" `Quick test_judge_fnap_result_type_single_arg
        ; test_case "multiple arguments" `Quick test_judge_fnap_result_type_multiple_args
        ; test_case "no arguments" `Quick test_judge_fnap_result_type_no_args
        ] )
    ; ( "judge_let_type"
      , [ test_case "single binding" `Quick test_judge_let_type_single_binding
        ; test_case "multiple bindings" `Quick test_judge_let_type_multiple_bindings
        ] )
    ; ( "judge_if_type"
      , [ test_case "simple if" `Quick test_judge_if_type_simple
        ; test_case "with comparison" `Quick test_judge_if_type_with_comparison
        ] )
    ; ( "jugde_if_pred_type"
      , [ test_case "boolean literal" `Quick test_jugde_if_pred_type_bool
        ; test_case "comparison" `Quick test_jugde_if_pred_type_comparison
        ] )
    ; "judge_match_type", [ test_case "int patterns" `Quick test_judge_match_type_int ]
    ; ( "judge_common_type"
      , [ test_case "all same type" `Quick test_judge_common_type_all_same
        ; test_case "empty sequence" `Quick test_judge_common_type_empty
        ] )
    ]
