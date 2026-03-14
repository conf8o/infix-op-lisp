open Lisp_to_ocaml
open Lisp_to_ocaml.Lisp_ast
open Lisp_to_ocaml.Transpiler

let v = top_var

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
           (let (smaller (filter ((\ x) (< x pivot)) rest)
                 greater (filter ((\ x) (>= x pivot)) rest))
             (append (append (quicksort smaller) (:: pivot []))
                     (quicksort greater)))))
     
     (def unsorted [3 1 4 1 5 9 2 6])
     (def sorted (quicksort unsorted))
  *)
  let program =
    [ Decl
        (Def
           ( Fn
               ( v "filter"
               , [ (v "pred", Lisp_type.(Arrow (Int, Bool)))
                 ; (v "lst1", Lisp_type.(List Int))
                 ]
               , Lisp_type.(List Int) )
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
           ( Fn
               ( v "append"
               , [ (v "lst1_3", Lisp_type.(List Int))
                 ; (v "lst2_3", Lisp_type.(List Int))
                 ]
               , Lisp_type.(List Int) )
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
           ( Fn (v "quicksort", [ (v "lst5", Lisp_type.(List Int)) ], Lisp_type.(List Int))
           , Match
               ( Sym (v "lst5")
               , [ List [], List []
                 ; ( Cons (Bind (v "pivot"), Bind (v "rest"))
                   , Let
                       ( [ ( Val (v "smaller", Lisp_type.(List Int))
                           , FnAp
                               [ Sym (v "filter")
                               ; Lamb
                                   ( [ v "x7", Lisp_type.Int ]
                                   , Lisp_type.Bool
                                   , FnAp [ Sym (v "<"); Sym (v "x7"); Sym (v "pivot") ]
                                   )
                               ; Sym (v "rest")
                               ] )
                         ; ( Val (v "greater", Lisp_type.(List Int))
                           , FnAp
                               [ Sym (v "filter")
                               ; Lamb
                                   ( [ v "x8", Lisp_type.Int ]
                                   , Lisp_type.Bool
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
           ( Val (v "unsorted", Lisp_type.(List Int))
           , List [ Int 3; Int 1; Int 4; Int 1; Int 5; Int 9; Int 2; Int 6 ] ))
    ; Decl
        (Def
           ( Val (v "sorted", Lisp_type.(List Int))
           , FnAp [ Sym (v "quicksort"); Sym (v "unsorted") ] ))
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
