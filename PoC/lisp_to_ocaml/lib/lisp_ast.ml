open Lisp_type

type scope_identifier = string
type var = string * scope_identifier

let top_level_scope_id = ""
let make_var s i = s, i
let top_var s = make_var s top_level_scope_id

(* 型注釈について再考すべき。現状、パターンの一つとして「型注釈つき束縛」を用意したが、
それをパターンから外し、パターンを型注釈で囲う「型注釈つきパターン」を考える必要性があるかもしれない *)
type patt =
  | Bind of var
  | Int of int
  | Bool of bool
  | List of typed_patt list
  | Cons of typed_patt * typed_patt
  | Wildcard
and typed_patt = patt * lisp_type

let bind_patt var ty = (Bind var, ty)
let int_patt n = (Int n, Inferred)
let bool_patt b = (Bool b, Inferred)
let list_patt patts = (List patts, Inferred)
let cons_patt hd tl = (Cons (hd, tl), Inferred)
let wildcard_patt () = (Wildcard, Inferred)

type binding_patt =
  | Val of typed_patt
  | Func of var * typed_patt list * lisp_type

type lisp_expr =
  | Int of int
  | Bool of bool
  | Sym of var
  | Fn of typed_patt list * lisp_type * lisp_expr
  | FnAp of lisp_expr list
  | Let of binding list * lisp_expr
  | If of lisp_expr * lisp_expr * lisp_expr
  | List of lisp_expr list
  | Match of lisp_expr * matching_case list

and binding = binding_patt * lisp_expr
and matching_case = typed_patt * lisp_expr

type lisp_decl = Def of binding

type lisp =
  | Decl of lisp_decl
  | Expr of lisp_expr

(* ================================ *)
(* 再帰呼び出しに関する補助関数 *)
(* ================================ *)

(** 変数に対してexpr内で再帰呼び出しが現れるかを判断する。
  このLispにおいては、recフラグは設けず自動検知する方針としている。
*)
let rec contains_rec_call (var : var) (expr : lisp_expr) : bool =
  match expr with
  | Int _ | Bool _ -> false
  | Sym v -> v = var
  | Fn (_, _, body) -> contains_rec_call var body
  | FnAp items -> List.exists (contains_rec_call var) items
  | Let (bindings, body) ->
    let rec_in_bindings =
      List.fold_left
        (fun has_rec (_, expr) -> has_rec || contains_rec_call var expr)
        false
        bindings
    in
    rec_in_bindings || contains_rec_call var body
  | If (pred, then_expr, else_expr) ->
    contains_rec_call var pred
    || contains_rec_call var then_expr
    || contains_rec_call var else_expr
  | List elements -> List.exists (contains_rec_call var) elements
  | Match (value, cases) ->
    let in_value = contains_rec_call var value in
    let in_cases = List.exists (fun (_, expr) -> contains_rec_call var expr) cases in
    in_value || in_cases


let rec lisp_to_string (lisp : lisp) : string =
  match lisp with
  | Decl (Def (Val patt, expr)) ->
    Printf.sprintf "(def %s %s)" (patt_to_string patt) (to_string_expr expr)
  | Decl (Def (Func (var, params, ret_ty), body)) ->
    let params_str = params |> List.map patt_to_string |> String.concat " " in
    Printf.sprintf
      "(def %s (%s) %s %s)"
      (var_to_string var)
      params_str
      (lisp_type_to_string ret_ty)
      (to_string_expr body)
  | Expr expr -> to_string_expr expr


and patt_to_string (patt, _) =
  match patt with
  | Bind var -> var_to_string var
  | Int n -> string_of_int n
  | Bool b -> string_of_bool b
  | List patts ->
    let patts_str = List.map patt_to_string patts |> String.concat " " in
    Printf.sprintf "[%s]" patts_str
  | Cons (hd, tl) -> Printf.sprintf "(%s :: %s)" (patt_to_string hd) (patt_to_string tl)
  | Wildcard -> "_"


and binding_patt_to_string = function
  | Val patt -> Printf.sprintf "(val %s)" (patt_to_string patt)
  | Func (var, params, ret_ty) ->
    let params_str = params |> List.map patt_to_string |> String.concat " " in
    Printf.sprintf
      "(func %s (%s) %s)"
      (var_to_string var)
      params_str
      (lisp_type_to_string ret_ty)


and var_to_string (name, scope) =
  if scope = top_level_scope_id then
    name
  else
    Printf.sprintf "%s__%s" name scope


and lisp_type_to_string = function
  | Int -> "int"
  | Bool -> "bool"
  | Unit -> "unit"
  | Var v -> v
  | List elem_type -> Printf.sprintf "list(%s)" (Lisp_type.to_string elem_type)
  | Arrow (arg_type, ret_type) ->
    Printf.sprintf
      "(%s -> %s)"
      (lisp_type_to_string arg_type)
      (lisp_type_to_string ret_type)
  | Inferred -> "_"


and to_string_expr = function
  | Int n -> string_of_int n
  | Bool b -> string_of_bool b
  | Sym var -> var_to_string var
  | Fn (params, ret_ty, body) ->
    let params_str = params |> List.map patt_to_string |> String.concat " " in
    Printf.sprintf
      "(fn (%s) %s %s)"
      params_str
      (lisp_type_to_string ret_ty)
      (to_string_expr body)
  | FnAp items ->
    let items_str = List.map to_string_expr items |> String.concat " " in
    Printf.sprintf "(%s)" items_str
  | Let (bindings, body) ->
    let bindings_str =
      bindings
      |> List.map (fun (binding_patt, expr) ->
        Printf.sprintf
          "(%s %s)"
          (binding_patt_to_string binding_patt)
          (to_string_expr expr))
      |> String.concat " "
    in
    Printf.sprintf "(let (%s) %s)" bindings_str (to_string_expr body)
  | If (pred, then_expr, else_expr) ->
    Printf.sprintf
      "(if %s %s %s)"
      (to_string_expr pred)
      (to_string_expr then_expr)
      (to_string_expr else_expr)
  | List elements ->
    let elements_str = List.map to_string_expr elements |> String.concat " " in
    Printf.sprintf "[%s]" elements_str
  | Match (value, cases) ->
    let cases_str =
      cases
      |> List.map (fun (patt, expr) ->
        Printf.sprintf "(%s %s)" (patt_to_string patt) (to_string_expr expr))
      |> String.concat " "
    in
    Printf.sprintf "(match %s %s)" (to_string_expr value) cases_str


(* ================================ *)
(* AST構造をそのまま出力する関数 (デバッグ用) *)
(* ================================ *)

let rec inspect_lisp (lisp : lisp) : string =
  match lisp with
  | Decl decl -> Printf.sprintf "Decl (%s)" (inspect_decl decl)
  | Expr expr -> Printf.sprintf "Expr (%s)" (inspect_expr expr)


and inspect_decl = function
  | Def (binding_patt, expr) ->
    Printf.sprintf "Def (%s, %s)" (inspect_binding_patt binding_patt) (inspect_expr expr)


and inspect_binding_patt = function
  | Val patt -> Printf.sprintf "Val (%s)" (inspect_patt patt)
  | Func (var, params, ret_ty) ->
    let params_str = params |> List.map inspect_patt |> String.concat "; " in
    Printf.sprintf
      "Func (%s, [%s], %s)"
      (inspect_var var)
      params_str
      (inspect_type ret_ty)


and inspect_patt (patt, _) =
  match patt with
  | Bind var -> Printf.sprintf "Bind %s" (inspect_var var)
  | Int n -> Printf.sprintf "Int %d" n
  | Bool b -> Printf.sprintf "Bool %b" b
  | List patts ->
    let patts_str = List.map inspect_patt patts |> String.concat "; " in
    Printf.sprintf "List [%s]" patts_str
  | Cons (hd, tl) -> Printf.sprintf "Cons (%s, %s)" (inspect_patt hd) (inspect_patt tl)
  | Wildcard -> "Wildcard"


and inspect_var (name, scope) =
  if scope = top_level_scope_id then
    Printf.sprintf "(\"%s\", \"\")" name
  else
    Printf.sprintf "(\"%s\", \"%s\")" name scope


and inspect_type = function
  | Int -> "Int"
  | Bool -> "Bool"
  | Unit -> "Unit"
  | Var v -> Printf.sprintf "Var \"%s\"" v
  | List elem_type -> Printf.sprintf "List (%s)" (inspect_type elem_type)
  | Arrow (arg_type, ret_type) ->
    Printf.sprintf "Arrow (%s, %s)" (inspect_type arg_type) (inspect_type ret_type)
  | Inferred -> "Inferred"


and inspect_expr = function
  | Int n -> Printf.sprintf "Int %d" n
  | Bool b -> Printf.sprintf "Bool %b" b
  | Sym var -> Printf.sprintf "Sym %s" (inspect_var var)
  | Fn (params, ret_ty, body) ->
    let params_str = params |> List.map inspect_patt |> String.concat "; " in
    Printf.sprintf
      "Fn ([%s], %s, %s)"
      params_str
      (inspect_type ret_ty)
      (inspect_expr body)
  | FnAp items ->
    let items_str = List.map inspect_expr items |> String.concat "; " in
    Printf.sprintf "FnAp [%s]" items_str
  | Let (bindings, body) ->
    let bindings_str =
      bindings
      |> List.map (fun (binding_patt, expr) ->
        Printf.sprintf "(%s, %s)" (inspect_binding_patt binding_patt) (inspect_expr expr))
      |> String.concat "; "
    in
    Printf.sprintf "Let ([%s], %s)" bindings_str (inspect_expr body)
  | If (pred, then_expr, else_expr) ->
    Printf.sprintf
      "If (%s, %s, %s)"
      (inspect_expr pred)
      (inspect_expr then_expr)
      (inspect_expr else_expr)
  | List elements ->
    let elements_str = List.map inspect_expr elements |> String.concat "; " in
    Printf.sprintf "List [%s]" elements_str
  | Match (value, cases) ->
    let cases_str =
      cases
      |> List.map (fun (patt, expr) ->
        Printf.sprintf "(%s, %s)" (inspect_patt patt) (inspect_expr expr))
      |> String.concat "; "
    in
    Printf.sprintf "Match (%s, [%s])" (inspect_expr value) cases_str
