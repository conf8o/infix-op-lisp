(* lisp_to_ocaml.ml
   Minimal: Lisp AST (Int, (+ a b)) -> OCaml Parsetree -> print OCaml source
*)

open Asttypes
open Parsetree
open Longident
open Ast_helper

type def_pattern =
  | Var of string
  | Fn of string * (string list)

type lisp =
  | Int of int
  | Var of string
  | List of lisp list
  | Special of special

and special =
  Def of def_pattern * lisp


(* Create an identifier expression (e.g., variable reference, operator, function name) *)
let to_identifier_exp (name : string) : expression =
  Exp.ident { txt = Lident name; loc = Location.none }

(* Create an integer constant expression *)
let to_constant_int_exp (n : int) : expression =
  Exp.constant (Const.int n)

(* Create a unit expression: () *)
let to_unit_exp () : expression =
  Exp.construct { txt = Lident "()"; loc = Location.none } None

(* Create a variable pattern *)
let to_variable_pat (name : string) : pattern =
  Pat.var { txt = name; loc = Location.none }

(* Convert Lisp AST to OCaml Parsetree expression *)
let rec to_ocaml_exp (e : lisp) : expression =
  match e with
  | Int n -> to_constant_int_exp n
  | Var name -> to_identifier_exp name
  | List items ->
      (* Function application: (f arg1 arg2 ...) *)
      (match items with
      | [] -> failwith "Empty Cons is not a valid expression"
      | [single] -> to_ocaml_exp single
      | fn :: args ->
          (* Convert to OCaml function application *)
          let fn_exp = to_ocaml_exp fn in
          let arg_exps = List.map (fun arg -> (Nolabel, to_ocaml_exp arg)) args in
          Exp.apply fn_exp arg_exps)
  | Special (Def _) ->
      (* Def should be converted to structure, not expression *)
      failwith "Def cannot be converted to expression; use to_structure instead"

(* Convert Lisp AST to OCaml Parsetree structure *)
let to_structure (e : lisp) : structure =
  match e with
  | Special (Def (Var name, value)) ->
      (* OCaml AST representation of: let name = value *)
      [ Str.value Nonrecursive [ Vb.mk (to_variable_pat name) (to_ocaml_exp value) ] ]
  | Special (Def (Fn (_name, _args), _body)) ->
      (* TODO: implement function definition *)
      failwith "Function definition not yet implemented"
  | _ ->
      (* Other expressions are evaluated at top level: ;;expr *)
      [ Str.eval (to_ocaml_exp e) ]

let main () =
  (* Example inputs: (def x 10) and (+ x 1) *)
  let program = [
    Special (Def (Var "x", Int 10));  (* (def x 10) *)
    List [Var "+"; Var "x"; Int 1]    (* (+ x 1) *)
  ] in
  
  (* Convert each Lisp expression to structure items *)
  let structures = List.concat_map to_structure program in

  (* Pretty-print OCaml structure from Parsetree *)
  let oc = open_out "bin/generated.ml" in
  let fmt = Format.formatter_of_out_channel oc in
  Pprintast.structure fmt structures;
  Format.pp_print_flush fmt ();
  close_out oc;

  Printf.printf "Wrote bin/generated.ml\n"