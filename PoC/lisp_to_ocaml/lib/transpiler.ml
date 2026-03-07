open Asttypes
open Parsetree
open Longident
open Ast_helper

(* 命名に関する注記 OCaml:
   - Exp: Expression. OCamlの式を表す型
   - Pat: Pattern. OCamlのパターンを表す型
   - Str: Structure. OCamlの構造体（トップレベルの宣言）を表す型
   - Fun: Function. OCamlの関数を表す型

   Lisp:
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

(* ================================ *)
(* === 式に関する補助関数 === *)
(* ================================ *)

(** 識別子式を作成する（例: 変数参照、演算子、関数名） *)
let to_identifier_exp (name : string) : expression =
  Exp.ident { txt = Lident name; loc = Location.none }


(** 整数定数式を作成する *)
let to_constant_int_exp (n : int) : expression = Exp.constant (Const.int n)

(** 真偽値定数式を作成する *)
let to_constant_bool_exp (b : bool) : expression =
  Exp.construct
    { txt =
        Lident
          (if b then
             "true"
           else
             "false")
    ; loc = Location.none
    }
    None


(** unit式を作成する: `()` *)
let to_unit_exp () : expression =
  Exp.construct { txt = Lident "()"; loc = Location.none } None


(** 空リスト式を作成する: `[]` *)
let to_empty_list_exp () : expression =
  Exp.construct { txt = Lident "[]"; loc = Location.none } None


(* ================================ *)
(* === パターンマッチングに関する補助関数 === *)
(* ================================ *)

(** 変数パターンを作成する *)
let to_variable_pat (name : string) : pattern =
  Pat.var { txt = name; loc = Location.none }


(** 空リストパターンを作成する: `[]` *)
let to_empty_list_pat () : pattern =
  Pat.construct { txt = Lident "[]"; loc = Location.none } None


(** ワイルドカードパターンを作成する: `_` *)
let to_wildcard_pat () : pattern = Pat.any ()

(* ================================ *)
(* === 再帰呼び出しに関する補助関数 === *)
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
    (* letの束縛でシャドーイングされる可能性をチェック *)
    let shadowed =
      List.exists
        (fun (pat, _) ->
           match pat with
           | Val v -> v = name
           | Fn (v, _) -> v = name)
        bindings
    in
    (* bindingの右辺には現れうる *)
    let in_bindings = List.exists (fun (_, e) -> contains_rec_call name e) bindings in
    if shadowed then
      in_bindings
    else
      in_bindings || contains_rec_call name body
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


(** 変数名が式の中に現れるかを判断し、再帰フラグを返す *)
let judge_rec (name : var) (expr : lisp_expr) : rec_flag =
  if contains_rec_call name expr then
    Recursive
  else
    Nonrecursive


(* ================================ *)
(* === OCaml parsetree への変換まわり === *)
(* ================================ *)
let fn_args_to_params (args : var list) : function_param list =
  match args with
  | [] ->
    (* 引数なし: fun () -> body のためのunitパラメータを作成 *)
    [ { pparam_loc = Location.none
      ; pparam_desc =
          Pparam_val
            (Nolabel, None, Pat.construct { txt = Lident "()"; loc = Location.none } None)
      }
    ]
  | _ ->
    (* 各引数を関数パラメータにマップ *)
    List.map
      (fun arg ->
         { pparam_loc = Location.none
         ; pparam_desc = Pparam_val (Nolabel, None, to_variable_pat arg)
         })
      args


(** LispのASTをOCamlのParsetree式に変換する *)
let rec to_ocaml_exp (e : lisp_expr) : expression =
  match e with
  | Int n -> to_constant_int_exp n
  | Bool b -> to_constant_bool_exp b
  | Sym name -> to_identifier_exp name
  | Fn (args, body) ->
    let params = fn_args_to_params args in
    let body_exp = to_ocaml_exp body in
    Exp.function_ params None (Pfunction_body body_exp)
  | FnAp items ->
    (match items with
     | [] -> to_unit_exp ()
     | [ single ] -> to_ocaml_exp single
     | fn :: args ->
       let fun_exp = to_ocaml_exp fn in
       let arg_exps = List.map (fun arg -> Nolabel, to_ocaml_exp arg) args in
       Exp.apply fun_exp arg_exps)
  | Let (bindings, body) ->
    let body_exp = to_ocaml_exp body in
    List.fold_right
      (fun binding acc ->
         let vb, rec_flag = binding_to_value_binding binding in
         Exp.let_ rec_flag [ vb ] acc)
      bindings
      body_exp
  | If (pred, then_expr, else_expr) ->
    let pred_exp = to_ocaml_exp pred in
    let then_exp = to_ocaml_exp then_expr in
    let else_exp = to_ocaml_exp else_expr in
    Exp.ifthenelse pred_exp then_exp (Some else_exp)
  | List elements -> to_list_exp elements
  | Match (value, cases) ->
    let value_exp = to_ocaml_exp value in
    let ocaml_cases = List.map to_match_case cases in
    Exp.match_ value_exp ocaml_cases


(** リスト式をOCamlのリスト構築式に変換する *)
and to_list_exp (elements : lisp_expr list) : expression =
  match elements with
  | [] -> to_empty_list_exp ()
  | hd :: tl ->
    let hd_exp = to_ocaml_exp hd in
    let tl_exp = to_list_exp tl in
    Exp.construct
      { txt = Lident "::"; loc = Location.none }
      (Some (Exp.tuple [ hd_exp; tl_exp ]))


(** matching_pattをOCamlのパターンに変換する *)
and to_ocaml_pat (p : matching_patt) : pattern =
  match p with
  | Bind name -> to_variable_pat name
  | Int n -> Pat.constant (Const.int n)
  | Bool b ->
    Pat.construct
      { txt =
          Lident
            (if b then
               "true"
             else
               "false")
      ; loc = Location.none
      }
      None
  | List patterns -> to_list_pat patterns
  | Cons (hd, tl) ->
    let hd_pat = to_ocaml_pat hd in
    let tl_pat = to_ocaml_pat tl in
    Pat.construct
      { txt = Lident "::"; loc = Location.none }
      (Some ([], Pat.tuple [ hd_pat; tl_pat ]))
  | Wildcard -> to_wildcard_pat ()


(** リストパターンをOCamlのリストパターンに変換する *)
and to_list_pat (patterns : matching_patt list) : pattern =
  match patterns with
  | [] -> to_empty_list_pat ()
  | hd :: tl ->
    let hd_pat = to_ocaml_pat hd in
    let tl_pat = to_list_pat tl in
    Pat.construct
      { txt = Lident "::"; loc = Location.none }
      (Some ([], Pat.tuple [ hd_pat; tl_pat ]))


(** match_caseをOCamlのcaseに変換する *)
and to_match_case (case : matching_case) : case =
  let patt, expr = case in
  let ocaml_patt = to_ocaml_pat patt in
  let ocaml_expr = to_ocaml_exp expr in
  { pc_lhs = ocaml_patt; pc_guard = None; pc_rhs = ocaml_expr }


(** bindingをvalue_bindingに変換する（再帰フラグも返す） *)
and binding_to_value_binding (b : binding) : value_binding * rec_flag =
  let pat, expr = b in
  match pat with
  | Val name -> Vb.mk (to_variable_pat name) (to_ocaml_exp expr), Nonrecursive
  | Fn (name, args) ->
    let rec_flag = judge_rec name expr in
    let fn_exp = to_ocaml_exp (Fn (args, expr)) in
    Vb.mk (to_variable_pat name) fn_exp, rec_flag


(** LispのASTをOCamlのParsetree構造に変換する *)
let to_structure (e : lisp) : structure =
  match e with
  | Decl (Def binding) ->
    let vb, rec_flag = binding_to_value_binding binding in
    (* OCamlのAST表現: let name = value または let rec name = value *)
    [ Str.value rec_flag [ vb ] ]
  | Expr e ->
    (* その他の式はトップレベルで評価される: ;;expr *)
    [ Str.eval (to_ocaml_exp e) ]
