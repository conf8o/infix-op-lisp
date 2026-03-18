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
  | ListElementTypeMismatch of lisp_type * lisp_type list
  | EmptyMatch
  | NotImplemented of string

type lisp_type_env = (var * lisp_type) list
type 'a type_check_result = ('a, type_check_error) Validation.validation

(** Reader + Validation モナドとしての型検査器。型環境(lisp_type_env)文脈の関数を適用するための操作を提供する  *)
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


let run (TypeChecker check : 'a type_checker) (env : lisp_type_env) : 'a type_check_result
  =
  check env


open Syntax

let lookup (var : var) (env : lisp_type_env) : lisp_type option = List.assoc_opt var env

let extend (var : var) (ty : lisp_type) (env : lisp_type_env) : lisp_type_env =
  (var, ty) :: env


let judge_variable_type (var : var) : lisp_type type_checker =
  let* env = ask in
  match lookup var env with
  | Some ty -> succeed ty
  | None -> fail [ UnboundVariable var ]


let rec judge_type (expr : lisp) : lisp_type type_checker =
  match expr with
  | Expr (Int _) -> succeed Int
  | Expr (Bool _) -> succeed Bool
  | Expr (Sym v) -> judge_variable_type v
  | Expr (Fn (args, return_type, body)) -> judge_fn_type args return_type body
  | Expr (FnAp items) -> judge_fnap_type items
  | Expr (Let (bindings, body)) -> judge_let_type bindings body
  | Expr (If (pred, then_expr, else_expr)) -> judge_if_type pred then_expr else_expr
  | Expr (List elements) -> judge_list_type elements
  | Expr (Match (value, cases)) -> judge_match_type value cases
  | _ -> fail [ NotImplemented "" ]


and judge_fn_type (args : patt list) (fn_return_type : lisp_type) (body : lisp_expr)
  : lisp_type type_checker
  =
  let append_arg_types env =
    List.fold_right (fun p acc -> extend_env_with_pattern p acc) args env
  in
  let* arg_types = sequence (List.map judge_match_patt_type args)
  and+ body_type = local append_arg_types (judge_type (Expr body)) in
  if type_eq body_type fn_return_type then
    succeed
      (List.fold_right
         (fun arg_type acc -> Arrow (arg_type, acc))
         arg_types
         fn_return_type)
  else
    fail [ TypeMismatch (body_type, fn_return_type) ]


and judge_fnap_type (items : lisp_expr list) : lisp_type type_checker =
  match items with
  | [] -> succeed Unit
  | [ single ] -> judge_type (Expr single)
  | fn :: args ->
    let* fn_type = judge_type (Expr fn) in
    judge_fnap_return_type fn_type args


and judge_fnap_return_type (fn_type : lisp_type) (args : lisp_expr list)
  : lisp_type type_checker
  =
  match args with
  | [] -> succeed fn_type
  | arg :: rest ->
    (match fn_type with
     | Arrow (dom, codom) ->
       let* actual_arg_type = judge_type (Expr arg) in
       if type_eq actual_arg_type dom then (
         match codom with
         | Arrow _ -> judge_fnap_return_type codom rest
         | ty -> succeed ty
       ) else
         fail [ TypeMismatch (dom, actual_arg_type) ]
     | _ -> fail [ NotAFunction fn_type ])


and judge_let_type (bindings : binding list) (body : lisp_expr) : lisp_type type_checker =
  bindings
  |> List.fold_left
       (fun acc_checker (binding_patt, expr) ->
          let* expr_type = judge_type (Expr expr) in
          match binding_patt with
          | Val matching ->
            let* expected_type = judge_match_patt_type matching in
            if type_eq expr_type expected_type then
              local (extend_env_with_pattern matching) acc_checker
            else
              fail [ TypeMismatch (expected_type, expr_type) ]
          | Func (name, args, return_type) ->
            let* lamb_type = judge_fn_type args return_type expr in
            local (extend name lamb_type) acc_checker)
       (judge_type (Expr body))


and judge_if_type (pred : lisp_expr) (then_expr : lisp_expr) (else_expr : lisp_expr)
  : lisp_type type_checker
  =
  let* _bool = jugde_if_pred_type pred
  and+ then_type = judge_type (Expr then_expr)
  and+ else_type = judge_type (Expr else_expr) in
  if type_eq then_type else_type then
    succeed then_type
  else
    fail [ BranchTypeMismatch (then_type, [ else_type ]) ]


and jugde_if_pred_type (pred : lisp_expr) : lisp_type type_checker =
  let* pred_type = judge_type (Expr pred) in
  if type_eq pred_type Bool then
    succeed Bool
  else
    fail [ ConditionNotBool pred_type ]


and judge_list_type (elements : lisp_expr list) : lisp_type type_checker =
  match elements with
  | [] -> fail [ EmptyList ]
  | hd :: tl ->
    let* hd_type = judge_type (Expr hd) in
    let rest_checkers = List.map (fun tl_expr -> judge_type (Expr tl_expr)) tl in
    judge_common_type rest_checkers hd_type (fun (ty, seq_types) ->
      ListElementTypeMismatch (ty, seq_types))


and judge_match_type (value : lisp_expr) (cases : matching_case list)
  : lisp_type type_checker
  =
  match cases with
  | [] -> fail [ EmptyMatch ]
  | (patt, expr) :: rest ->
    let* value_type = judge_type (Expr value)
    and+ patt_type = judge_match_patt_type patt in
    let* _ =
      if type_eq value_type patt_type then
        succeed ()
      else
        fail [ TypeMismatch (patt_type, value_type) ]
    in
    let* first_expr_type =
      local (extend_env_with_pattern patt) (judge_type (Expr expr))
    in
    let rest_checkers =
      rest
      |> List.map (fun (patt', expr') ->
        local (extend_env_with_pattern patt') (judge_type (Expr expr')))
    in
    judge_common_type rest_checkers first_expr_type (fun (ty, seq_types) ->
      BranchTypeMismatch (ty, seq_types))


and judge_match_patt_type (patt : patt) : lisp_type type_checker =
  match patt with
  | Bind _ -> succeed Inferred
  | TypedBind (_, ty) -> succeed ty
  | Int _ -> succeed Int
  | Bool _ -> succeed Bool
  | Wildcard -> succeed Inferred
  | List [] -> succeed (List Inferred)
  | List (hd :: tl) ->
    let* hd_type = judge_match_patt_type hd
    and+ elem_types = sequence (List.map judge_match_patt_type tl) in
    if List.for_all (type_eq hd_type) elem_types then
      succeed (List hd_type)
    else
      fail [ ListElementTypeMismatch (hd_type, elem_types) ]
  | Cons (hd_patt, List []) ->
    let+ hd_type = judge_match_patt_type hd_patt in
    List hd_type
  | Cons (hd_patt, tl_patt) ->
    let* hd_type = judge_match_patt_type hd_patt
    and+ tl_type = judge_match_patt_type tl_patt in
    (match tl_type with
     | List elem_type ->
       if type_eq hd_type elem_type then
         succeed (List hd_type)
       else
         fail [ ListElementTypeMismatch (hd_type, [ elem_type ]) ]
     | other_type -> fail [ ListElementTypeMismatch (hd_type, [ other_type ]) ])


and judge_common_type
      (checker_seq : lisp_type type_checker list)
      (expected_type : lisp_type)
      (error : lisp_type * lisp_type list -> type_check_error)
  : lisp_type type_checker
  =
  let* seq_types = sequence checker_seq in
  if List.for_all (fun ty -> type_eq expected_type ty) seq_types then
    succeed expected_type
  else
    fail [ error (expected_type, seq_types) ]


and extend_env_with_pattern (patt : patt) (env : lisp_type_env) : lisp_type_env =
  match patt with
  | Bind var -> extend var Inferred env
  | TypedBind (var, ty) -> extend var ty env
  | Int _ | Bool _ | Wildcard -> env
  | List patts -> List.fold_right (fun p acc -> extend_env_with_pattern p acc) patts env
  | Cons (hd_patt, tl_patt) ->
    extend_env_with_pattern hd_patt env |> extend_env_with_pattern tl_patt


(* ================================ *)
(* その他の補助関数 *)
(* ================================ *)

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
