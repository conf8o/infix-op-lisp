open Lisp_type

type scope_identifier = string
type var = string * scope_identifier

let top_level_scope_id = ""
let make_var s i = s, i
let top_var s = make_var s top_level_scope_id

type matching_patt =
  | Bind of var
  | TypedBind of var * lisp_type
  | Int of int
  | Bool of bool
  | List of matching_patt list
  | Cons of matching_patt * matching_patt
  | Wildcard

type binding_patt =
  | Val of matching_patt
  | Func of var * matching_patt list * lisp_type

type lisp_expr =
  | Int of int
  | Bool of bool
  | Sym of var
  | Fn of matching_patt list * lisp_type * lisp_expr
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
  | Fn (_, _, body) -> contains_rec_call name body
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


let rec match_patt_to_type (patt : matching_patt) : (lisp_type, lisp_type list) result =
  match patt with
  | Bind _ -> Ok (Lisp_type.Inferred)
  | TypedBind (_, ty) -> Ok ty
  | Int _ -> Ok Lisp_type.Int
  | Bool _ -> Ok Lisp_type.Bool
  | Wildcard -> Ok Lisp_type.Inferred
  | List [] -> Ok Lisp_type.(List Inferred)
  | List (hd :: tl) ->
    let open Result.Syntax in
    let open Extra.Result in
    let* hd_type = match_patt_to_type hd in
    let* elem_types = List.map match_patt_to_type tl |> sequence in
    let all_elem_type_same = List.for_all (type_eq hd_type) elem_types in
    if all_elem_type_same then
      Ok (Lisp_type.List hd_type)
    else
      Error elem_types
  | Cons (hd_patt, List []) ->
    match_patt_to_type hd_patt
    |> Result.map (fun hd_type -> Lisp_type.(List hd_type))
  | Cons (hd_patt, tl_patt) ->
    let open Result.Syntax in
    let* hd_type = match_patt_to_type hd_patt in
    match match_patt_to_type tl_patt with
    | Ok (Lisp_type.List elem_type) ->
      if type_eq hd_type elem_type then
        Ok (Lisp_type.(List hd_type))
      else
        Error [ hd_type; elem_type ]
    | Ok other_type -> Error [ hd_type; other_type ]
    | Error tl_types -> Error (hd_type :: tl_types)
