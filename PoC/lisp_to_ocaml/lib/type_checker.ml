open Lisp_ast
open Lisp_type

(* ================================ *)
(* 型検査まわり *)
(* ================================ *)

type type_check_error =
  | UnboundVariable of var
  | TypeMismatch of lisp_type * lisp_type
  | ConditionNotBool of lisp_type
  | BranchTypeMismatch of lisp_type * lisp_type list
  | NotAFunction of lisp_type
  | EmptyList
  | ListElementTypeMismatch
  | EmptyMatch
  | CannotInferFunctionType
  | TooManyArguments
  | NotImplemented of string

type lisp_type_env = (var * lisp_type) list

let init_type_env () : lisp_type_env =
  [ top_var "+", Arrow (Int, Arrow (Int, Int))
  ; top_var "-", Arrow (Int, Arrow (Int, Int))
  ; top_var "*", Arrow (Int, Arrow (Int, Int))
  ; top_var "<", Arrow (Int, Arrow (Int, Bool))
  ; top_var ">", Arrow (Int, Arrow (Int, Bool))
  ; top_var "=", Arrow (Int, Arrow (Int, Bool))
  ; top_var "<=", Arrow (Int, Arrow (Int, Bool))
  ; top_var ">=", Arrow (Int, Arrow (Int, Bool))
  ; top_var "::", Arrow (Var "T", Arrow (List (Var "T"), List (Var "T")))
  ]


(** Reader + Validation モナドとしての型検査器。型環境(lisp_type_env)文脈の関数を適用するための操作を提供する  *)
module TypeChecker = struct
  type 'a type_check_result = ('a, type_check_error) Validation.validation
  type 'a type_checker = TypeChecker of (lisp_type_env -> 'a type_check_result)

  let succeed x = TypeChecker (fun _ -> Validation.succeed x)
  let fail errs = TypeChecker (fun _ -> Validation.fail errs)

  let from_result (v : 'a type_check_result) : 'a type_checker =
    match v with
    | Validation.Success x -> succeed x
    | Validation.Failure errs -> fail errs


  let map f (TypeChecker check) = TypeChecker (fun env -> Validation.map f (check env))

  let ( <*> ) (TypeChecker check_f) (TypeChecker check_x) =
    TypeChecker (fun env -> Validation.(check_f env <*> check_x env))


  (** fは型検査文脈の値を返す関数。例えば、環境から値を取ってくる関数など。*)
  let ( >>= ) (TypeChecker check) f =
    TypeChecker
      (fun env ->
        let open Validation.Syntax in
        let* x = check env in
        let (TypeChecker check_after_f) = f x in
        check_after_f env)


  (** 現在の型環境を取ってくる *)
  let ask = TypeChecker (fun env -> Validation.succeed env)

  (** 現在の環境を引数とする関数を適用して戻り値を得る関数。 *)
  let asks f = ask >>= fun env -> succeed (f env)

  (** ローカルに更新される型環境で検査を実行する *)
  let local update (TypeChecker check) = TypeChecker (fun env -> check (update env))

  let lift2 f c1 c2 = map f c1 <*> c2
  let product c1 c2 = lift2 (fun x y -> x, y) c1 c2

  module Syntax = struct
    let ( let* ) = ( >>= )
    let ( let+ ) x f = map f x
    let ( and+ ) = product
  end

  let sequence (checkers : 'a type_checker list) : 'a list type_checker =
    List.fold_right
      (fun checker acc_checker ->
         product checker acc_checker |> map (fun (x, xs) -> x :: xs))
      checkers
      (succeed [])
end

open TypeChecker
open TypeChecker.Syntax

let lookup (name : var) (env : lisp_type_env) : lisp_type option = List.assoc_opt name env

let extend (name : var) (ty : lisp_type) (env : lisp_type_env) : lisp_type_env =
  (name, ty) :: env


let judge_name_type (name : var) : lisp_type type_checker =
  let* env = ask in
  match lookup name env with
  | Some ty -> succeed ty
  | None -> fail [ UnboundVariable name ]


let rec judge_type (expr : lisp) : lisp_type type_checker =
  match expr with
  | Expr (Int _) -> succeed Int
  | Expr (Bool _) -> succeed Bool
  | Expr (Sym name) -> judge_name_type name
  | Expr (Lamb (args, return_type, body)) -> judge_lamb_type args (body, return_type)
  | Expr (FnAp items) -> judge_fnap_type items
  | Expr (Let (bindings, body)) -> judge_let_type bindings body
  | Expr (If (pred, then_expr, else_expr)) -> judge_if_type pred then_expr else_expr
  | Expr (List elements) -> judge_list_type elements
  | Expr (Match (value, cases)) -> judge_match_type value cases
  | _ -> fail [ NotImplemented "" ]


and judge_lamb_type (args : bound_var list) ((body, ty) : lisp_expr * lisp_type)
  : lisp_type type_checker
  =
  let append_arg_types env = args @ env in
  let open Syntax in
  let* body_type = local append_arg_types (judge_type (Expr body)) in
  if body_type = ty then (
    let fn_type =
      List.fold_right (fun (_, arg_type) acc -> Arrow (arg_type, acc)) args ty
    in
    succeed fn_type
  ) else
    fail [ TypeMismatch (body_type, ty) ]


and judge_fnap_type (items : lisp_expr list) : lisp_type type_checker =
  match items with
  | [] -> succeed Unit
  | [ single ] -> judge_type (Expr single)
  | fn :: args ->
    let* fn_type = judge_type (Expr fn) in
    judge_apply_type fn_type args


and judge_apply_type (fn_type : lisp_type) (args : lisp_expr list)
  : lisp_type type_checker
  =
  match args with
  | [] -> succeed fn_type
  | arg :: rest ->
    (match fn_type with
     | Arrow (arg_type, result_type) ->
       let* actual_arg_type = judge_type (Expr arg) in
       if actual_arg_type = arg_type then (
         match result_type with
         | Arrow _ -> judge_apply_type result_type rest
         | ty -> succeed ty
       ) else
         fail [ TypeMismatch (arg_type, actual_arg_type) ]
     | _ -> fail [ NotAFunction fn_type ])


and judge_let_type (bindings : bindings) (body : lisp_expr) : lisp_type type_checker =
  let rec process_bindings bindings' =
    match bindings' with
    | [] -> judge_type (Expr body)
    | (binding_patt, expr) :: rest ->
      let* expr_type = judge_type (Expr expr) in
      (match binding_patt with
       | Val (name, expected_type) ->
         if expr_type = expected_type then
           local (extend name expr_type) (process_bindings rest)
         else
           fail [ TypeMismatch (expected_type, expr_type) ]
       | Fn (name, args, return_type) ->
         let* lamb_type = judge_lamb_type args (expr, return_type) in
         local (extend name lamb_type) (process_bindings rest))
  in
  process_bindings bindings


and judge_if_type (pred : lisp_expr) (then_expr : lisp_expr) (else_expr : lisp_expr)
  : lisp_type type_checker
  =
  let* _bool = jugde_if_pred_type pred
  and+ then_type = judge_type (Expr then_expr)
  and+ else_type = judge_type (Expr else_expr) in
  if then_type = else_type then
    succeed then_type
  else
    fail [ BranchTypeMismatch (then_type, [ else_type ]) ]


and jugde_if_pred_type (pred : lisp_expr) : lisp_type type_checker =
  let* pred_type = judge_type (Expr pred) in
  if pred_type = Bool then
    succeed Bool
  else
    fail [ ConditionNotBool pred_type ]


and judge_list_type (elements : lisp_expr list) : lisp_type type_checker =
  match elements with
  | [] -> fail [ EmptyList ]
  | hd :: tl ->
    let* hd_type = judge_type (Expr hd) in
    let* rest_types =
      List.map (fun tl_expr -> judge_type (Expr tl_expr)) tl |> sequence
    in
    if List.for_all (fun rest_type -> hd_type = rest_type) rest_types then
      succeed (List hd_type)
    else
      fail [ ListElementTypeMismatch ]


and judge_match_type (value : lisp_expr) (cases : matching_case list)
  : lisp_type type_checker
  =
  let* value_type = judge_type (Expr value) in
  match cases with
  | [] -> fail [ EmptyMatch ]
  | (patt, expr) :: rest ->
    let* first_type =
      local (extend_env_with_pattern patt value_type) (judge_type (Expr expr))
    in
    let* rest_types =
      rest
      |> List.map (fun (patt', expr') ->
        local (extend_env_with_pattern patt' value_type) (judge_type (Expr expr')))
      |> sequence
    in
    if List.for_all (fun rest_type -> first_type = rest_type) rest_types then
      succeed first_type
    else
      fail [ BranchTypeMismatch (first_type, rest_types) ]


and extend_env_with_pattern
      (patt : matching_patt)
      (value_type : lisp_type)
      (env : lisp_type_env)
  : lisp_type_env
  =
  match patt, value_type with
  | Bind var, ty -> extend var ty env
  | (Int _ | Bool _ | Wildcard), _ -> env
  | List patts, List elem_ty ->
    List.fold_right (fun p acc -> extend_env_with_pattern p elem_ty acc) patts env
  | Cons (hd_patt, tl_patt), List elem_ty ->
    extend_env_with_pattern hd_patt elem_ty env
    |> extend_env_with_pattern tl_patt value_type
  | (List _ | Cons _), _ -> env
