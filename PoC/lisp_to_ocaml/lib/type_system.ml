open Lisp_ast
open Lisp_type

(* ================================ *)
(* 型システムまわり *)
(* ================================ *)

type lisp_type_env = (var * lisp_type) list

type type_check_error =
  | UnboundVariable of var
  | TypeMismatch of lisp_type * lisp_type
  | ConditionNotBool of lisp_type
  | BranchTypeMismatch of lisp_type * lisp_type
  | NotAFunction of lisp_type
  | EmptyList
  | ListElementTypeMismatch
  | EmptyMatch
  | CannotInferFunctionType
  | TooManyArguments

let init_type_env () : lisp_type_env =
  [ top_var "+", Fn (Int, Fn (Int, Int))
  ; top_var "-", Fn (Int, Fn (Int, Int))
  ; top_var "*", Fn (Int, Fn (Int, Int))
  ; top_var "<", Fn (Int, Fn (Int, Bool))
  ; top_var ">", Fn (Int, Fn (Int, Bool))
  ; top_var "=", Fn (Int, Fn (Int, Bool))
  ; top_var "<=", Fn (Int, Fn (Int, Bool))
  ; top_var ">=", Fn (Int, Fn (Int, Bool))
  ; top_var "::", Fn (Var "T", Fn (List (Var "T"), List (Var "T")))
  ]


(** 型環境から変数の型を検索する *)
let lookup_type (env : lisp_type_env) (name : var) : (lisp_type, type_check_error) result =
  match List.assoc_opt name env with
  | Some ty -> Ok ty
  | None -> Error (UnboundVariable name)


(** 型環境に変数の型を追加する *)
let extend_type_env (env : lisp_type_env) (name : var) (ty : lisp_type) : lisp_type_env =
  (name, ty) :: env

