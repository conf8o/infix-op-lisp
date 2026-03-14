type type_var = string

type lisp_type =
  | Int
  | Bool
  | Fn of lisp_type * lisp_type
  | List of lisp_type
  | Var of type_var
  | Unit
  | Abbr
