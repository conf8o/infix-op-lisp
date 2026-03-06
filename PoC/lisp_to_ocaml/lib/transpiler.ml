open Asttypes
open Parsetree
open Longident
open Ast_helper


(* 命名に関する注記

  OCaml:
  - Exp: Expression. OCamlの式を表す型
  - Pat: Pattern. OCamlのパターンを表す型
  - Str: Structure. OCamlの構造体（トップレベルの宣言）を表す型
  - Fun: Function. OCamlの関数を表す型

  Lisp:
  - Expr: Expression. Lispの式を表す型。衝突を避けるため、exprとしている。
  - Patt: Pattern. Lispのパターンを表す型。衝突を避けるため、pattとしている。
  - Decl: Declaration. Lispの宣言を表す型。Strと対応する。
  - Fn: Function. Lispの関数を表す型。衝突を避けるため、fnとしている。funcでないのは、無名関数をfnで表すため。
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

(* Create an identifier expression (e.g., variable reference, operator, function name) *)
let to_identifier_exp (name : string) : expression =
  Exp.ident { txt = Lident name; loc = Location.none }


(* Create an integer constant expression *)
let to_constant_int_exp (n : int) : expression = Exp.constant (Const.int n)

(* Create a boolean constant expression *)
let to_constant_bool_exp (b : bool) : expression =
  Exp.construct 
    { txt = Lident (if b then "true" else "false"); loc = Location.none } 
    None

(* Create a unit expression: () *)
let to_unit_exp () : expression =
  Exp.construct { txt = Lident "()"; loc = Location.none } None


(* Create a variable pattern *)
let to_variable_pat (name : string) : pattern =
  Pat.var { txt = name; loc = Location.none }


let fn_args_to_params (args : var list) : function_param list =
  match args with
  | [] ->
    (* No arguments: create unit parameter for fun () -> body *)
    [ { pparam_loc = Location.none
      ; pparam_desc =
          Pparam_val
            (Nolabel, None, Pat.construct { txt = Lident "()"; loc = Location.none } None)
      }
    ]
  | _ ->
    (* Map each argument to a function parameter *)
    List.map
      (fun arg ->
         { pparam_loc = Location.none
         ; pparam_desc = Pparam_val (Nolabel, None, to_variable_pat arg)
         })
      args


(* Convert Lisp AST to OCaml Parsetree expression *)
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
    let vbs = List.map binding_to_value_binding bindings in
    let body_exp = to_ocaml_exp body in
    Exp.let_ Nonrecursive vbs body_exp
  | If (pred, then_expr, else_expr) ->
    let pred_exp = to_ocaml_exp pred in
    let then_exp = to_ocaml_exp then_expr in
    let else_exp = to_ocaml_exp else_expr in
    Exp.ifthenelse pred_exp then_exp (Some else_exp)

(* Convert binding to value_binding *)
and binding_to_value_binding (b : binding) : value_binding =
  let (pat, expr) = b in
  match pat with
  | Val name -> Vb.mk (to_variable_pat name) (to_ocaml_exp expr)
  | Fn (name, args) ->
    let fn_exp = to_ocaml_exp (Fn (args, expr)) in
    Vb.mk (to_variable_pat name) fn_exp


(* Convert Lisp AST to OCaml Parsetree structure *)
let to_structure (e : lisp) : structure =
  match e with
  | Decl (Def binding) ->
    (* OCaml AST representation of: let name = value *)
    [ Str.value Nonrecursive [ binding_to_value_binding binding ] ]
  | Expr e ->
    (* Other expressions are evaluated at top level: ;;expr *)
    [ Str.eval (to_ocaml_exp e) ]


let main () =
  (* Example inputs:
     (def n 10)
     (def is_positive true)
     (def (f x) (+ n x))
     (def (test_if)
       (if is_positive 100 -100))
     (def (abs x)
       (if (< x 0)
         (- 0 x)
         x))
     (def (main) 
       (let (y 20) 
         (f y)))
  *)
  let program =
    [ Decl (Def (Val "n", Int 10))
    ; Decl (Def (Val "is_positive", Bool true))
    ; Decl (Def (Fn ("f", [ "x" ]), FnAp [ Sym "+"; Sym "n"; Sym "x" ]))
    ; Decl (Def (Fn ("test_if", []),
        If (Sym "is_positive", Int 100, Int (-100))))
    ; Decl (Def (Fn ("abs", [ "x" ]),
        If (FnAp [ Sym "<"; Sym "x"; Int 0 ], 
            FnAp [ Sym "-"; Int 0; Sym "x" ],
            Sym "x")))
    ; Decl (Def (Fn ("main", []), 
        Let ([ Val "y", Int 20 ], FnAp [ Sym "f"; Sym "y" ])))
    ]
  in

  (* Convert each Lisp expression to structure items *)
  let structures = List.concat_map to_structure program in

  (* Pretty-print OCaml structure from Parsetree *)
  let oc = open_out "bin/generated.ml" in
  let fmt = Format.formatter_of_out_channel oc in
  Pprintast.structure fmt structures;
  Format.pp_print_flush fmt ();
  close_out oc;

  Printf.printf "Wrote bin/generated.ml\n"
