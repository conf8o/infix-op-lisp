open Lisp_ast
open Lisp_type
open Type_system


(** result型のbind操作 *)
let ( let* ) = Result.bind

(** 式の型を判定する *)
let rec judge_type (env : lisp_type_env) (expr : lisp_expr)
  : (lisp_type, type_check_error) result
  =
  match expr with
  | Int _ -> Ok Int
  | Bool _ -> Ok Bool
  | Sym name -> lookup_type env name
  | Fn (args, body) -> judge_fn_type env args body
  | FnAp items -> judge_fnap_type env items
  | Let (bindings, body) -> judge_let_type env bindings body
  | If (pred, then_expr, else_expr) -> judge_if_type env pred then_expr else_expr
  | List elements -> judge_list_type env elements
  | Match (value, cases) -> judge_match_type env value cases


(** 関数の型を判定する *)
and judge_fn_type (env : lisp_type_env) (args : var list) (body : lisp_expr)
  : (lisp_type, type_check_error) result
  =
  match args with
  | [] ->
    (* 引数なしの関数は一旦扱わない *)
    let* body_type = judge_type env body in
    Ok body_type
  | _ ->
    (* 引数の型を推定できないため、エラーを返す *)
    Error CannotInferFunctionType


(** 関数適用の型を判定する *)
and judge_fnap_type (env : lisp_type_env) (items : lisp_expr list)
  : (lisp_type, type_check_error) result
  =
  match items with
  | [] -> Error EmptyList
  | [ single ] -> judge_type env single
  | fn :: args ->
    let* fn_type = judge_type env fn in
    judge_apply_type env fn_type args


(** 関数型に引数を適用した結果の型を判定する *)
and judge_apply_type (env : lisp_type_env) (fn_type : lisp_type) (args : lisp_expr list)
  : (lisp_type, type_check_error) result
  =
  match args with
  | [] -> Ok fn_type
  | arg :: rest ->
    (match fn_type with
     | Fn (arg_type, result_type) ->
       let* actual_arg_type = judge_type env arg in
       if actual_arg_type = arg_type then
         judge_apply_type env result_type rest
       else
         Error (TypeMismatch (arg_type, actual_arg_type))
     | _ -> Error (NotAFunction fn_type))


(** let式の型を判定する *)
and judge_let_type (env : lisp_type_env) (bindings : bindings) (body : lisp_expr)
  : (lisp_type, type_check_error) result
  =
  let rec process_bindings env = function
    | [] -> judge_type env body
    | (pat, expr) :: rest ->
      let* expr_type = judge_type env expr in
      (match pat with
       | Lisp_ast.Var name ->
         (match expr with
          | Fn (_args, _body) ->
            (* 関数定義の場合、引数の型が不明なため一旦スキップ *)
            process_bindings env rest
          | _ ->
             let new_env = extend_type_env env name expr_type in
             process_bindings new_env rest))
  in
  process_bindings env bindings


(** if式の型を判定する *)
and judge_if_type
      (env : lisp_type_env)
      (pred : lisp_expr)
      (then_expr : lisp_expr)
      (else_expr : lisp_expr)
  : (lisp_type, type_check_error) result
  =
  let* pred_type = judge_type env pred in
  if pred_type <> Bool then
    Error (ConditionNotBool pred_type)
  else
    let* then_type = judge_type env then_expr in
    let* else_type = judge_type env else_expr in
    if then_type = else_type then
      Ok then_type
    else
      Error (BranchTypeMismatch (then_type, else_type))


(** リストの型を判定する *)
and judge_list_type (env : lisp_type_env) (elements : lisp_expr list)
  : (lisp_type, type_check_error) result
  =
  match elements with
  | [] -> Error EmptyList
  | hd :: tl ->
    let* hd_type = judge_type env hd in
    let rec check_uniform ty = function
      | [] -> Ok (List ty)
      | elem :: rest ->
        let* elem_type = judge_type env elem in
        if elem_type = ty then
          check_uniform ty rest
        else
          Error ListElementTypeMismatch
    in
    check_uniform hd_type tl


(** match式の型を判定する *)
and judge_match_type
      (env : lisp_type_env)
      (value : lisp_expr)
      (cases : matching_case list)
  : (lisp_type, type_check_error) result
  =
  let* _value_type = judge_type env value in
  match cases with
  | [] -> Error EmptyMatch
  | (patt, expr) :: rest ->
    let patt_env = extend_env_with_pattern env patt in
    let* first_type = judge_type patt_env expr in
    let rec check_uniform ty = function
      | [] -> Ok ty
      | (patt, expr) :: rest ->
        let patt_env = extend_env_with_pattern env patt in
        let* case_type = judge_type patt_env expr in
        if case_type = ty then
          check_uniform ty rest
        else
          Error (BranchTypeMismatch (ty, case_type))
    in
    check_uniform first_type rest


(** パターンから束縛される変数を型環境に追加する *)
and extend_env_with_pattern (env : lisp_type_env) (_patt : matching_patt) : lisp_type_env =
  (* 一旦、パターンの型推論は行わず、環境をそのまま返す *)
  env
