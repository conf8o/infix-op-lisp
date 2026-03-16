type type_var = string

type lisp_type =
  | Int
  | Bool
  | Arrow of lisp_type * lisp_type
  | List of lisp_type
  | Var of type_var
  | Unit
  (* 型注釈省略の型 *)
  | Inferred

let rec type_eq ty1 ty2 =
  match ty1, ty2 with
  | Int, Int -> true
  | Bool, Bool -> true
  | Unit, Unit -> true
  | Var v1, Var v2 -> v1 = v2
  | List t1, List t2 -> type_eq t1 t2
  | Arrow (arg1, ret1), Arrow (arg2, ret2) -> type_eq arg1 arg2 && type_eq ret1 ret2
  | Inferred, _ | _, Inferred -> true
  | _ -> false


let rec to_string = function
  | Int -> "int"
  | Bool -> "bool"
  | Unit -> "unit"
  | Var v -> v
  | List elem_type -> Printf.sprintf "list(%s)" (to_string elem_type)
  | Arrow (arg_type, ret_type) ->
    Printf.sprintf "(%s -> %s)" (to_string arg_type) (to_string ret_type)
  | Inferred -> "_"
