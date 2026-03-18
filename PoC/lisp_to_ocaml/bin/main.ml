open Lisp_to_ocaml
open Lisp_to_ocaml.Transpiler

let () =
  print_endline "start";
  (* クイックソート *)
  let program = {|
(def (filter pred lst)
  (match lst
    [] []
    (x :: xs) (if (pred x)
                (:: x (filter pred xs))
                (filter pred xs))))

(def (append lst1 lst2)
  (match lst1
    [] lst2
    (x :: xs) (:: x (append xs lst2))))

(def (quicksort lst)
  (match lst
    [] []
    (pivot :: rest)
      (let (smaller (filter (fn (x) (< x pivot)) rest)
            greater (filter (fn (x) (>= x pivot)) rest))
        (append (append (quicksort smaller) (:: pivot []))
                (quicksort greater)))))

(def unsorted [3 1 4 1 5 9 2 6])
(def sorted (quicksort unsorted))
|}
  in
  let parsed_program = Parser.parse program in
  let structures = List.concat_map to_structure parsed_program in
  let oc = open_out "bin/generated.ml" in
  let fmt = Format.formatter_of_out_channel oc in
  Pprintast.structure fmt structures;
  Format.pp_print_flush fmt ();
  close_out oc;
  Printf.printf "Wrote bin/generated.ml\n";
  print_endline "end"
