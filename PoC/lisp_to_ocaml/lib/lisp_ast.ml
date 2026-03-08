(* Lisp:
   - Expr: Expression. Lispの式を表す型。読む際の勘違い等を避けるため、exprとしている。
   - Patt: Pattern. Lispのパターンを表す型。読む際の勘違い等を避けるため、pattとしている。
   - Decl: Declaration. Lispの宣言を表す型。Strと対応する。
   - Fn: Function. Lispの関数を表す型。読む際の衝突を避けるため、fnとしている。funcでないのは、無名関数をfnで表すため。
*)

type scope_identifier = string
type var = string * scope_identifier

let top_level_scope_id = ""
let make_var s i = s, i
let top_var s = make_var s top_level_scope_id

type binding_patt =
  | Val of var
  | Fn of var * var list

type matching_patt =
  | Bind of var
  | Int of int
  | Bool of bool
  | List of matching_patt list
  | Cons of matching_patt * matching_patt
  | Wildcard

type lisp_expr =
  | Int of int
  | Bool of bool
  | Sym of var
  | Fn of var list * lisp_expr
  | FnAp of lisp_expr list
  | Let of bindings * lisp_expr
  | If of lisp_expr * lisp_expr * lisp_expr
  | List of lisp_expr list
  | Match of lisp_expr * matching_case list

and bindings = binding list
and binding = binding_patt * lisp_expr
and matching_case = matching_patt * lisp_expr

type lisp_decl = Def of binding

type lisp =
  | Decl of lisp_decl
  | Expr of lisp_expr

let extract_name (binding : binding_patt) : var =
  match binding with
  | Val name -> name
  | Fn (name, _) -> name


(* ================================ *)
(* 再帰呼び出しに関する補助関数 *)
(* ================================ *)

(** nameに対してexpr内で再帰呼び出しが現れるかを判断する。
  変数のシャドーイングについては、新たな変数が現れるたびに識別子を付与して一意な変数を作り出す仕組みとするので考慮しない。
*)
let rec contains_rec_call (name : var) (expr : lisp_expr) : bool =
  match expr with
  | Int _ | Bool _ -> false
  | Sym v -> v = name
  | Fn (_, body) -> contains_rec_call name body
  | FnAp items -> List.exists (contains_rec_call name) items
  | Let (bindings, body) ->
    let rec_in_bindings =
      List.fold_left
        (fun has_rec (_, expr) -> has_rec || contains_rec_call name expr)
        false
        bindings
    in
    rec_in_bindings || contains_rec_call name body
  | If (pred, then_expr, else_expr) ->
    contains_rec_call name pred
    || contains_rec_call name then_expr
    || contains_rec_call name else_expr
  | List elements -> List.exists (contains_rec_call name) elements
  | Match (value, cases) ->
    let in_value = contains_rec_call name value in
    let in_cases = List.exists (fun (_, expr) -> contains_rec_call name expr) cases in
    in_value || in_cases
