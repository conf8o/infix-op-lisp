open Lisp_to_ocaml.Lisp_ast
open Lisp_to_ocaml.Transpiler

let v0 name = make_var name ""

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
           ( Fn (v0 "filter", [ v0 "pred"; v0 "lst1" ])
           , Match
               ( Sym (v0 "lst1")
               , [ List [], List []
                 ; ( Cons (Bind (v0 "x2"), Bind (v0 "xs2"))
                   , If
                       ( FnAp [ Sym (v0 "pred"); Sym (v0 "x2") ]
                       , FnAp
                           [ Sym (v0 "::")
                           ; Sym (v0 "x2")
                           ; FnAp [ Sym (v0 "filter"); Sym (v0 "pred"); Sym (v0 "xs2") ]
                           ]
                       , FnAp [ Sym (v0 "filter"); Sym (v0 "pred"); Sym (v0 "x2") ] ) )
                 ] ) ))
    ; Decl
        (Def
           ( Fn (v0 "append", [ v0 "lst1_3"; v0 "lst2_3" ])
           , Match
               ( Sym (v0 "lst1_3")
               , [ List [], Sym (v0 "lst2_3")
                 ; ( Cons (Bind (v0 "x4"), Bind (v0 "xs4"))
                   , FnAp
                       [ Sym (v0 "::")
                       ; Sym (v0 "x4")
                       ; FnAp [ Sym (v0 "append"); Sym (v0 "xs4"); Sym (v0 "lst2_3") ]
                       ] )
                 ] ) ))
    ; Decl
        (Def
           ( Fn (v0 "quicksort", [ v0 "lst5" ])
           , Match
               ( Sym (v0 "lst5")
               , [ List [], List []
                 ; ( Cons (Bind (v0 "pivot"), Bind (v0 "rest"))
                   , Let
                       ( [ ( Val (v0 "smaller")
                           , FnAp
                               [ Sym (v0 "filter")
                               ; Fn
                                   ( [ v0 "x7" ]
                                   , FnAp
                                       [ Sym (v0 "<"); Sym (v0 "x7"); Sym (v0 "pivot") ]
                                   )
                               ; Sym (v0 "rest")
                               ] )
                         ; ( Val (v0 "greater")
                           , FnAp
                               [ Sym (v0 "filter")
                               ; Fn
                                   ( [ v0 "x8" ]
                                   , FnAp
                                       [ Sym (v0 ">="); Sym (v0 "x8"); Sym (v0 "pivot") ]
                                   )
                               ; Sym (v0 "rest")
                               ] )
                         ]
                       , FnAp
                           [ Sym (v0 "append")
                           ; FnAp
                               [ Sym (v0 "append")
                               ; FnAp [ Sym (v0 "quicksort"); Sym (v0 "smaller") ]
                               ; List [ Sym (v0 "pivot") ]
                               ]
                           ; FnAp [ Sym (v0 "quicksort"); Sym (v0 "greater") ]
                           ] ) )
                 ] ) ))
    ; Decl
        (Def
           ( Val (v0 "unsorted")
           , List [ Int 3; Int 1; Int 4; Int 1; Int 5; Int 9; Int 2; Int 6 ] ))
    ; Decl (Def (Val (v0 "sorted"), FnAp [ Sym (v0 "quicksort"); Sym (v0 "unsorted") ]))
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
