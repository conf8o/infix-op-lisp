open Asttypes
open Parsetree
open Longident
open Ast_helper
open Lisp_ast

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

(* ================================ *)
(* 式に関する補助関数 *)
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
(* パターンマッチングに関する補助関数 *)
(* ================================ *)

let to_unique_var (v : var) : string =
  let name, id = v in
  Printf.sprintf "%s%s" name id


(** 変数パターンを作成する *)
let to_variable_pat (v : var) : pattern =
  let name = to_unique_var v in
  Pat.var { txt = name; loc = Location.none }


(** 空リストパターンを作成する: `[]` *)
let to_empty_list_pat () : pattern =
  Pat.construct { txt = Lident "[]"; loc = Location.none } None


(** ワイルドカードパターンを作成する: `_` *)
let to_wildcard_pat () : pattern = Pat.any ()

(* ================================ *)
(* OCaml parsetree への変換まわり *)
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
    List.map
      (fun arg ->
         { pparam_loc = Location.none
         ; pparam_desc = Pparam_val (Nolabel, None, to_variable_pat arg)
         })
      args


(** 変数名が式の中に現れるかを判断し、再帰フラグを返す *)
let judge_rec (name : var) (expr : lisp_expr) : rec_flag =
  if contains_rec_call name expr then
    Recursive
  else
    Nonrecursive


(** LispのASTをOCamlのParsetree式に変換する *)
let rec to_ocaml_exp (e : lisp_expr) : expression =
  match e with
  | Int n -> to_constant_int_exp n
  | Bool b -> to_constant_bool_exp b
  | Sym name -> to_identifier_exp (to_unique_var name)
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
      (Some (Exp.tuple [ None, hd_exp; None, tl_exp ]))


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
      (Some ([], Pat.tuple [ None, hd_pat; None, tl_pat ] Closed))
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
      (Some ([], Pat.tuple [ None, hd_pat; None, tl_pat ] Closed))


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
  | Var name ->
    (match expr with
     | Fn (args, expr) ->
       let rec_flag = judge_rec name expr in
       let fn_exp = to_ocaml_exp (Fn (args, expr)) in
       Vb.mk (to_variable_pat name) fn_exp, rec_flag
     | _ -> Vb.mk (to_variable_pat name) (to_ocaml_exp expr), Nonrecursive)


(** LispのASTをOCamlのParsetree構造に変換する *)
let to_structure (e : lisp) : structure =
  match e with
  | Decl (Def binding) ->
    let vb, rec_flag = binding_to_value_binding binding in
    [ Str.value rec_flag [ vb ] ]
  | Expr e -> [ Str.eval (to_ocaml_exp e) ]
