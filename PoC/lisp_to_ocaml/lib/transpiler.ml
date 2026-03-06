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

type lisp_expr =
  | Int of int
  | Bool of bool
  | Sym of var
  | Fn of var list * lisp_expr
  | FnAp of lisp_expr list
  | Let of bindings * lisp_expr
  | If of lisp_expr * lisp_expr * lisp_expr

and bindings = binding list
and binding = binding_patt * lisp_expr

type lisp_decl = Def of binding

type lisp =
  | Decl of lisp_decl
  | Expr of lisp_expr

(* 識別子式を作成する（例: 変数参照、演算子、関数名） *)
let to_identifier_exp (name : string) : expression =
  Exp.ident { txt = Lident name; loc = Location.none }


(* 整数定数式を作成する *)
let to_constant_int_exp (n : int) : expression = Exp.constant (Const.int n)

(* 真偽値定数式を作成する *)
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


(* unit式を作成する: `()` *)
let to_unit_exp () : expression =
  Exp.construct { txt = Lident "()"; loc = Location.none } None


(* 変数パターンを作成する *)
let to_variable_pat (name : string) : pattern =
  Pat.var { txt = name; loc = Location.none }


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


(* 指定された変数名が式の中に現れるかを判断し、再帰フラグを返す *)
let rec judge_rec (name : var) (expr : lisp_expr) : rec_flag =
  match expr with
  | Int _ | Bool _ -> Nonrecursive
  | Sym v ->
    if v = name then
      Recursive
    else
      Nonrecursive
  | Fn (args, body) ->
    (* 引数に同じ名前があればシャドーイングされているので再帰ではない *)
    if List.mem name args then
      Nonrecursive
    else
      judge_rec name body
  | FnAp items ->
    if List.exists (fun e -> judge_rec name e = Recursive) items then
      Recursive
    else
      Nonrecursive
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
    let in_bindings = List.exists (fun (_, e) -> judge_rec name e = Recursive) bindings in
    let contains =
      if shadowed then
        in_bindings
      else
        in_bindings || judge_rec name body = Recursive
    in
    if contains then
      Recursive
    else
      Nonrecursive
  | If (pred, then_expr, else_expr) ->
    if
      judge_rec name pred = Recursive
      || judge_rec name then_expr = Recursive
      || judge_rec name else_expr = Recursive
    then
      Recursive
    else
      Nonrecursive


(* LispのASTをOCamlのParsetree式に変換する *)
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


(* bindingをvalue_bindingに変換する（再帰フラグも返す） *)
and binding_to_value_binding (b : binding) : value_binding * rec_flag =
  let pat, expr = b in
  match pat with
  | Val name -> Vb.mk (to_variable_pat name) (to_ocaml_exp expr), Nonrecursive
  | Fn (name, args) ->
    let rec_flag = judge_rec name expr in
    let fn_exp = to_ocaml_exp (Fn (args, expr)) in
    Vb.mk (to_variable_pat name) fn_exp, rec_flag


(* LispのASTをOCamlのParsetree構造に変換する *)
let to_structure (e : lisp) : structure =
  match e with
  | Decl (Def binding) ->
    let vb, rec_flag = binding_to_value_binding binding in
    (* OCamlのAST表現: let name = value または let rec name = value *)
    [ Str.value rec_flag [ vb ] ]
  | Expr e ->
    (* その他の式はトップレベルで評価される: ;;expr *)
    [ Str.eval (to_ocaml_exp e) ]


let main () =
  (* 入力例:
     (def n 10)
     (def is_positive true)
     (def (f x) (+ n x))
     (def (test_if)
       (if is_positive 100 -100))
     (def (abs x)
       (if (< x 0) (- 0 x) x))
     (def (fact n)
       (if (= n 0)
         1
         (* n (fact (- n 1)))))
     (def (main)
       (let (y 20
             z (+ y 100))
         (f y)))
  *)*)
  let program =
    [ Decl (Def (Val "n", Int 10))
    ; Decl (Def (Val "is_positive", Bool true))
    ; Decl (Def (Fn ("f", [ "x" ]), FnAp [ Sym "+"; Sym "n"; Sym "x" ]))
    ; Decl (Def (Fn ("test_if", []), If (Sym "is_positive", Int 100, Int (-100))))
    ; Decl
        (Def
           ( Fn ("abs", [ "x" ])
           , If
               ( FnAp [ Sym "<"; Sym "x"; Int 0 ]
               , FnAp [ Sym "-"; Int 0; Sym "x" ]
               , Sym "x" ) ))
    ; (* 再帰関数の例: 階乗 *)
      Decl
        (Def
           ( Fn ("fact", [ "n" ])
           , If
               ( FnAp [ Sym "="; Sym "n"; Int 0 ]
               , Int 1
               , FnAp
                   [ Sym "*"
                   ; Sym "n"
                   ; FnAp [ Sym "fact"; FnAp [ Sym "-"; Sym "n"; Int 1 ] ]
                   ] ) ))
    ; Decl
        (Def
           ( Fn ("main", [])
           , Let
               ( [ Val "y", Int 20; Val "z", FnAp [ Sym "+"; Sym "y"; Int 100 ] ]
               , FnAp [ Sym "f"; Sym "z" ] ) ))
    ]
  in

  (* 各Lisp式を構造項目に変換する *)
  let structures = List.concat_map to_structure program in

  (* ParsetreeからOCaml構造を整形して出力する *)
  let oc = open_out "bin/generated.ml" in
  let fmt = Format.formatter_of_out_channel oc in
  Pprintast.structure fmt structures;
  Format.pp_print_flush fmt ();
  close_out oc;

  Printf.printf "Wrote bin/generated.ml\n"
