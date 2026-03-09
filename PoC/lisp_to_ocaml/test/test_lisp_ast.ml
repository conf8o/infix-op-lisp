open Lisp_to_ocaml.Lisp_ast

let scope_counter = ref 0

let v name =
  incr scope_counter;
  make_var name ("__" ^ string_of_int !scope_counter)


let v0 name = make_var name ""

(** 直接的な再帰呼び出しの検知 *)
let test_direct_recursion () =
  scope_counter := 0;
  let fact = v "fact" in
  let expr = Sym fact in
  let result = contains_rec_call fact expr in
  Alcotest.(check bool) "direct symbol reference" true result


(** 関数適用内での再帰呼び出しの検知 *)
let test_recursion_in_application () =
  scope_counter := 0;
  let fact = v "fact" in
  let n = v "n" in
  let expr = FnAp [ Sym fact; Sym n ] in
  let result = contains_rec_call fact expr in
  Alcotest.(check bool) "recursion in function application" true result


(** 再帰呼び出しがない場合 *)
let test_no_recursion () =
  scope_counter := 0;
  let fact = v "fact" in
  let other = v "other" in
  let n = v "n" in
  let expr = FnAp [ Sym other; Sym n ] in
  let result = contains_rec_call fact expr in
  Alcotest.(check bool) "no recursion" false result


(** 関数の引数でシャドーイングされる場合 *)
let test_shadowing_by_function_arg () =
  scope_counter := 0;
  let fact1 = v "fact" in
  let fact2 = v "fact" in
  let n = v "n" in
  let expr = Fn ([ fact2; n ], Sym fact2) in
  let result = contains_rec_call fact1 expr in
  Alcotest.(check bool) "shadowed by function argument" false result


(** Let 式でシャドーイングされる場合 *)
let test_shadowing_by_let () =
  scope_counter := 0;
  let fact1 = v "fact" in
  let fact2 = v "fact" in
  let expr = Let ([ Var fact2, Int 42 ], Sym fact2) in
  let result = contains_rec_call fact1 expr in
  Alcotest.(check bool) "shadowed by let binding" false result


(** Let 式の束縛の右辺で再帰呼び出しがある場合 *)
let test_recursion_in_let_binding () =
  scope_counter := 0;
  let fact = v "fact" in
  let x = v "x" in
  let n = v "n" in
  let expr = Let ([ Var x, FnAp [ Sym fact; Sym n ] ], Sym x) in
  let result = contains_rec_call fact expr in
  Alcotest.(check bool) "recursion in let binding expression" true result


(** Let 式で複数の束縛があり、途中でシャドーイングされる場合 *)
let test_shadowing_in_middle_of_bindings () =
  scope_counter := 0;
  let fact = v "fact" in
  let x = v "x" in
  let fact_shadow = v "fact" in
  let y = v "y" in
  let expr =
    Let
      ( [ Var x, FnAp [ Sym fact; Int 5 ]
        ; Var fact_shadow, Int 100
        ; Var y, Sym fact_shadow
        ]
      , Sym fact_shadow )
  in
  let result = contains_rec_call fact expr in
  Alcotest.(check bool) "recursion only in first binding before shadowing" true result


(** Let 式で最初の束縛でシャドーイングされ、その後は再帰呼び出しにならない場合 *)
let test_early_shadowing_in_let () =
  scope_counter := 0;
  let fact1 = v "fact" in
  let fact2 = v "fact" in
  let x = v "x" in
  let y = v "y" in
  let expr =
    Let ([ Var fact2, Int 100; Var x, Sym fact2; Var y, Sym fact2 ], Sym fact2)
  in
  let result = contains_rec_call fact1 expr in
  Alcotest.(check bool) "no recursion after early shadowing" false result


(** Match 式のパターンでシャドーイングされる場合 *)
let test_shadowing_by_match_pattern () =
  scope_counter := 0;
  let fact = v "fact" in
  let x = v "x" in
  let fact_shadow = v "fact" in
  let expr =
    Match
      (Sym x, [ Bind fact_shadow, Sym fact_shadow; Wildcard, FnAp [ Sym fact; Int 1 ] ])
  in
  let result = contains_rec_call fact expr in
  Alcotest.(check bool) "shadowed by match pattern in first case" true result


(** Match 式の値部分で再帰呼び出しがある場合 *)
let test_recursion_in_match_value () =
  scope_counter := 0;
  let fact = v "fact" in
  let n = v "n" in
  let expr = Match (FnAp [ Sym fact; Sym n ], [ Wildcard, Int 0 ]) in
  let result = contains_rec_call fact expr in
  Alcotest.(check bool) "recursion in match value" true result


(** Match 式のケース内で再帰呼び出しがある場合 *)
let test_recursion_in_match_case () =
  scope_counter := 0;
  let fact = v "fact" in
  let x = v "x" in
  let n = v "n" in
  let expr = Match (Sym x, [ Wildcard, FnAp [ Sym fact; Sym n ] ]) in
  let result = contains_rec_call fact expr in
  Alcotest.(check bool) "recursion in match case" true result


(** 複雑なネストでの再帰検知 *)
let test_complex_nested_recursion () =
  scope_counter := 0;
  let fact = v "fact" in
  let n = v "n" in
  let expr =
    If
      ( FnAp [ Sym (v0 "="); Sym n; Int 0 ]
      , Int 1
      , FnAp
          [ Sym (v0 "*"); Sym n; FnAp [ Sym fact; FnAp [ Sym (v0 "-"); Sym n; Int 1 ] ] ]
      )
  in
  let result = contains_rec_call fact expr in
  Alcotest.(check bool) "complex nested recursion (factorial)" true result


(** テストスイート *)
let () =
  let open Alcotest in
  run
    "Lisp AST"
    [ ( "recursion detection"
      , [ test_case "direct recursion" `Quick test_direct_recursion
        ; test_case "recursion in application" `Quick test_recursion_in_application
        ; test_case "no recursion" `Quick test_no_recursion
        ] )
    ; ( "shadowing in functions"
      , [ test_case "shadowing by function arg" `Quick test_shadowing_by_function_arg ] )
    ; ( "shadowing in let"
      , [ test_case "shadowing by let" `Quick test_shadowing_by_let
        ; test_case "recursion in let binding" `Quick test_recursion_in_let_binding
        ; test_case
            "shadowing in middle of bindings"
            `Quick
            test_shadowing_in_middle_of_bindings
        ; test_case "early shadowing in let" `Quick test_early_shadowing_in_let
        ] )
    ; ( "shadowing in match"
      , [ test_case "shadowing by match pattern" `Quick test_shadowing_by_match_pattern
        ; test_case "recursion in match value" `Quick test_recursion_in_match_value
        ; test_case "recursion in match case" `Quick test_recursion_in_match_case
        ] )
    ; ( "complex cases"
      , [ test_case "complex nested recursion" `Quick test_complex_nested_recursion ] )
    ]
