open Lisp_type

type scope_identifier = string
type var = string * scope_identifier

let top_level_scope_id = ""
let make_var s i = s, i
let top_var s = make_var s top_level_scope_id

type patt =
  | Bind of var
  | TypedBind of var * lisp_type
  | Int of int
  | Bool of bool
  | List of patt list
  | Cons of patt * patt
  | Wildcard

let bind_patt var = Bind var
let typed_bind_patt var ty = TypedBind (var, ty)
let int_patt n = Int n
let bool_patt b = Bool b
let list_patt patts = List patts
let cons_patt hd tl = Cons (hd, tl)
let wildcard_patt () = Wildcard

type binding_patt =
  | Val of patt
  | Func of var * patt list * lisp_type

type lisp_expr =
  | Int of int
  | Bool of bool
  | Sym of var
  | Fn of patt list * lisp_type * lisp_expr
  | FnAp of lisp_expr list
  | Let of binding list * lisp_expr
  | If of lisp_expr * lisp_expr * lisp_expr
  | List of lisp_expr list
  | Match of lisp_expr * matching_case list

and binding = binding_patt * lisp_expr
and matching_case = patt * lisp_expr

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
