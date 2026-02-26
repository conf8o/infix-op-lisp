(* lisp_to_ocaml.ml
   Minimal: Lisp AST (Int, (+ a b)) -> OCaml Parsetree -> print OCaml source
*)

open Asttypes
open Parsetree
open Longident

module H = Ast_helper

(* ----- Lisp-side minimal AST ----- *)
type lisp_expr =
  | Int of int
  | Add of lisp_expr * lisp_expr

(* Helper: create a located identifier expression, with Location.none. *)
let evar (name : string) : expression =
  H.Exp.ident { txt = Lident name; loc = Location.none }

let eint (n : int) : Parsetree.expression =
  H.Exp.constant (H.Const.int n)

(* Lisp AST -> OCaml Parsetree.expression *)
let rec to_ocaml_expr (e : lisp_expr) : expression =
  match e with
  | Int n -> eint n
  | Add (a, b) ->
      (* OCaml AST representation of: a + b
         In Parsetree, operators are just identifiers applied to arguments.
      *)
      H.Exp.apply
        (evar "+")
        [ (Nolabel, to_ocaml_expr a); (Nolabel, to_ocaml_expr b) ]

(* Build a toplevel structure that prints the result, like:
   let () =
     print_int (1 + 2);
     print_newline ()
*)
let program_structure (expr : expression) : structure =
  let print_int_call =
    H.Exp.apply (evar "print_int") [ (Nolabel, expr) ]
  in
  let print_newline_call =
    H.Exp.apply (evar "print_newline") [ (Nolabel, H.Exp.construct { txt = Lident "()"; loc = Location.none } None) ]
    (* ↑ "print_newline ()" の () を明示したいので Unit 構築。
       もっと簡単にしたければ `H.Exp.construct {txt=Lident "()"; loc=...} None` を使わず、
       print_endline を使う等でもOK。
    *)
  in
  let seq = H.Exp.sequence print_int_call print_newline_call in
  (* let () = <seq> *)
  let vb =
    H.Vb.mk
      (H.Pat.construct { txt = Lident "()"; loc = Location.none } None)
      seq
  in
  [ H.Str.value Nonrecursive [ vb ] ]

let main () =
  (* Example input: (+ 1 2) *)
  let lisp = Add (Int 1, Int 2) in
  let ocaml_expr = to_ocaml_expr lisp in
  let st = program_structure ocaml_expr in

  (* Pretty-print OCaml source from Parsetree *)
  let oc = open_out "generated.ml" in
  let fmt = Format.formatter_of_out_channel oc in
  Pprintast.structure fmt st;
  Format.pp_print_flush fmt ();
  close_out oc;

  Printf.printf "Wrote generated.ml\n"