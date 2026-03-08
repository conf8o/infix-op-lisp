open Lisp_to_ocaml.Lisp_ast
open Lisp_to_ocaml.Transpiler

let v name = make_var name ""

let () =
  print_endline "start";
  (* クイックソート
     (def (filter pred lst)
       (match lst
         [] []
         (:: x xs) (if (pred x)
                     (:: x (filter pred xs))
                     (filter pred xs))))
     
     (def (append lst1 lst2)
       (match lst1
         [] lst2
         (:: x xs) (:: x (append xs lst2))))
     
     (def (quicksort lst)
       (match lst
         [] []
         (:: pivot rest)
           (let (smaller (filter (fn (x) (< x pivot)) rest)
                 greater (filter (fn (x) (>= x pivot)) rest))
             (append (append (quicksort smaller) (:: pivot []))
                     (quicksort greater)))))
     
     (def unsorted [3 1 4 1 5 9 2 6])
     (def sorted (quicksort unsorted))
  *)
  let program =
    [ Decl
        (Def
           ( Fn (v "filter", [ v "pred"; v "lst1" ])
           , Match
               ( Sym (v "lst1")
               , [ List [], List []
                 ; ( Cons (Bind (v "x2"), Bind (v "xs2"))
                   , If
                       ( FnAp [ Sym (v "pred"); Sym (v "x2") ]
                       , FnAp
                           [ Sym (v "::")
                           ; Sym (v "x2")
                           ; FnAp [ Sym (v "filter"); Sym (v "pred"); Sym (v "xs2") ]
                           ]
                       , FnAp [ Sym (v "filter"); Sym (v "pred"); Sym (v "xs2") ] ) )
                 ] ) ))
    ; Decl
        (Def
           ( Fn (v "append", [ v "lst1_3"; v "lst2_3" ])
           , Match
               ( Sym (v "lst1_3")
               , [ List [], Sym (v "lst2_3")
                 ; ( Cons (Bind (v "x4"), Bind (v "xs4"))
                   , FnAp
                       [ Sym (v "::")
                       ; Sym (v "x4")
                       ; FnAp [ Sym (v "append"); Sym (v "xs4"); Sym (v "lst2_3") ]
                       ] )
                 ] ) ))
    ; Decl
        (Def
           ( Fn (v "quicksort", [ v "lst5" ])
           , Match
               ( Sym (v "lst5")
               , [ List [], List []
                 ; ( Cons (Bind (v "pivot"), Bind (v "rest"))
                   , Let
                       ( [ ( Val (v "smaller")
                           , FnAp
                               [ Sym (v "filter")
                               ; Fn
                                   ( [ v "x7" ]
                                   , FnAp [ Sym (v "<"); Sym (v "x7"); Sym (v "pivot") ]
                                   )
                               ; Sym (v "rest")
                               ] )
                         ; ( Val (v "greater")
                           , FnAp
                               [ Sym (v "filter")
                               ; Fn
                                   ( [ v "x8" ]
                                   , FnAp [ Sym (v ">="); Sym (v "x8"); Sym (v "pivot") ]
                                   )
                               ; Sym (v "rest")
                               ] )
                         ]
                       , FnAp
                           [ Sym (v "append")
                           ; FnAp
                               [ Sym (v "append")
                               ; FnAp [ Sym (v "quicksort"); Sym (v "smaller") ]
                               ; List [ Sym (v "pivot") ]
                               ]
                           ; FnAp [ Sym (v "quicksort"); Sym (v "greater") ]
                           ] ) )
                 ] ) ))
    ; Decl
        (Def
           ( Val (v "unsorted")
           , List [ Int 3; Int 1; Int 4; Int 1; Int 5; Int 9; Int 2; Int 6 ] ))
    ; Decl (Def (Val (v "sorted"), FnAp [ Sym (v "quicksort"); Sym (v "unsorted") ]))
    ]
  in
  let structures = List.concat_map to_structure program in
  let oc = open_out "bin/generated.ml" in
  let fmt = Format.formatter_of_out_channel oc in
  Pprintast.structure fmt structures;
  Format.pp_print_flush fmt ();
  close_out oc;
  Printf.printf "Wrote bin/generated.ml\n";
  print_endline "end"
