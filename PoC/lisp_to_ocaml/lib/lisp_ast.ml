(* Lisp:
   - Expr: Expression. Lispの式を表す型。読む際の勘違い等を避けるため、exprとしている。
   - Patt: Pattern. Lispのパターンを表す型。読む際の勘違い等を避けるため、pattとしている。
   - Decl: Declaration. Lispの宣言を表す型。Strと対応する。
   - Fn: Function. Lispの関数を表す型。読む際の衝突を避けるため、fnとしている。funcでないのは、無名関数をfnで表すため。
*)
type var = string

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

(** nameに対してexpr内で再帰呼び出しが現れるかを判断する *)
let rec contains_rec_call (name : var) (expr : lisp_expr) : bool =
  match expr with
  | Int _ | Bool _ -> false
  | Sym v -> v = name
  | Fn (args, body) ->
    (* 引数に同じ名前があればシャドーイングされているので再帰ではない *)
    if List.mem name args then
      false
    else
      contains_rec_call name body
  | FnAp items -> List.exists (contains_rec_call name) items
  | Let (bindings, body) ->
    let rec_in_bindings, shadowed =
      List.fold_left
        (fun (has_rec, shadowed) (pat, expr) ->
           if shadowed then
             has_rec, true
           else (
             let rec_in_expr = contains_rec_call name expr in
             let shadows = name = extract_name pat in
             has_rec || rec_in_expr, shadows
           ))
        (false, false)
        bindings
    in
    if shadowed then
      rec_in_bindings
    else
      rec_in_bindings || contains_rec_call name body
  | If (pred, then_expr, else_expr) ->
    contains_rec_call name pred
    || contains_rec_call name then_expr
    || contains_rec_call name else_expr
  | List elements -> List.exists (contains_rec_call name) elements
  | Match (value, cases) ->
    let in_value = contains_rec_call name value in
    let in_cases =
      List.exists
        (fun (patt, expr) ->
           (* パターンで束縛される変数を考慮 *)
           let bound_vars = collect_patt_vars patt in
           if List.mem name bound_vars then
             (* パターンでシャドーイングされる *)
             false
           else
             contains_rec_call name expr)
        cases
    in
    in_value || in_cases


(** パターンから束縛される変数名を収集する *)
and collect_patt_vars (p : matching_patt) : var list =
  match p with
  | Bind v -> [ v ]
  | Int _ | Bool _ | Wildcard -> []
  | List patterns -> List.concat_map collect_patt_vars patterns
  | Cons (hd, tl) -> collect_patt_vars hd @ collect_patt_vars tl
