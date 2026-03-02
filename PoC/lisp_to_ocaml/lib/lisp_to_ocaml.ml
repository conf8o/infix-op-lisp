(* lisp_to_ocaml.ml
   Minimal: Lisp AST (Int, (+ a b)) -> OCaml Parsetree -> print OCaml source
*)

open Asttypes
open Parsetree
open Longident
open Ast_helper

type var = string

type binding_pattern =
  | Val of var
  | Fn of var * var list

type lisp_expr =
  | Int of int
  | Sym of var
  | FnApply of lisp_expr list
  | Let of bindings * lisp_expr
  | If of lisp_expr * lisp_expr * lisp_expr

and bindings = binding list
and binding = binding_pattern * lisp_expr

type lisp_decl = Def of binding

type lisp =
  | Decl of lisp_decl
  | Expr of lisp_expr

(* Create an identifier expression (e.g., variable reference, operator, function name) *)
let to_identifier_exp (name : string) : expression =
  Exp.ident { txt = Lident name; loc = Location.none }


(* Create an integer constant expression *)
let to_constant_int_exp (n : int) : expression = Exp.constant (Const.int n)

(* Create a unit expression: () *)
let to_unit_exp () : expression =
  Exp.construct { txt = Lident "()"; loc = Location.none } None


(* Create a variable pattern *)
let to_variable_pat (name : string) : pattern =
  Pat.var { txt = name; loc = Location.none }


(* Convert Lisp AST to OCaml Parsetree expression *)
let rec to_ocaml_exp (e : lisp_expr) : expression =
  match e with
  | Int n -> to_constant_int_exp n
  | Sym name -> to_identifier_exp name
  | FnApply items ->
    (match items with
     | [] -> failwith "Empty Cons is not a valid expression"
     | [ single ] -> to_ocaml_exp single
     | fn :: args ->
       (* Convert to OCaml function application *)
       let fn_exp = to_ocaml_exp fn in
       let arg_exps = List.map (fun arg -> Nolabel, to_ocaml_exp arg) args in
       Exp.apply fn_exp arg_exps)
  | Let (_bindings, _body) -> failwith "`Let` isn't implemented"
  | If (_pred, _then_expr, _else_expr) -> failwith "`If` isn't implemented"


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


(* Convert Lisp AST to OCaml Parsetree structure *)
let to_structure (e : lisp) : structure =
  match e with
  | Decl (Def (Val name, value)) ->
    (* OCaml AST representation of: let name = value *)
    [ Str.value Nonrecursive [ Vb.mk (to_variable_pat name) (to_ocaml_exp value) ] ]
  | Decl (Def (Fn (name, args), body)) ->
    (* OCaml AST representation of: let name arg1 arg2 ... = body *)
    let params = fn_args_to_params args in
    let body_exp = to_ocaml_exp body in
    let fun_exp = Exp.function_ params None (Pfunction_body body_exp) in
    [ Str.value Nonrecursive [ Vb.mk (to_variable_pat name) fun_exp ] ]
  | Expr e ->
    (* Other expressions are evaluated at top level: ;;expr *)
    [ Str.eval (to_ocaml_exp e) ]


let main () =
  (* Example inputs:
     (def x 10)
     (def (f x) (+ n x))
     (def (main) (f 10))
  *)
  let program =
    [ Decl (Def (Val "n", Int 10))
    ; Decl (Def (Fn ("f", [ "x" ]), FnApply [ Sym "+"; Sym "n"; Sym "x" ]))
    ; Decl (Def (Fn ("main", []), FnApply [ Sym "f"; Int 10 ]))
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
