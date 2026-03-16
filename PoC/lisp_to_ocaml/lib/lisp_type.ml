type type_var = string

type lisp_type =
  | Int
  | Bool
  | Arrow of lisp_type * lisp_type
  | List of lisp_type
  | Var of type_var
  | Unit
  (* 型注釈省略の型 *)
  | Abbr
