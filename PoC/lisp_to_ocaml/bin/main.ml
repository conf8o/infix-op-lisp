open Lisp_to_ocaml.Transpiler

let () =
  print_endline "start";
  (* クイックソートの実装例
     
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
           ( Fn ("filter", [ "pred"; "lst" ])
           , Match
               ( Sym "lst"
               , [ List [], List []
                 ; ( Cons (Bind "x", Bind "xs")
                   , If
                       ( FnAp [ Sym "pred"; Sym "x" ]
                       , FnAp
                           [ Sym "::"
                           ; Sym "x"
                           ; FnAp [ Sym "filter"; Sym "pred"; Sym "xs" ]
                           ]
                       , FnAp [ Sym "filter"; Sym "pred"; Sym "xs" ] ) )
                 ] ) ))
    ; Decl
        (Def
           ( Fn ("append", [ "lst1"; "lst2" ])
           , Match
               ( Sym "lst1"
               , [ List [], Sym "lst2"
                 ; ( Cons (Bind "x", Bind "xs")
                   , FnAp
                       [ Sym "::"; Sym "x"; FnAp [ Sym "append"; Sym "xs"; Sym "lst2" ] ]
                   )
                 ] ) ))
    ; Decl
        (Def
           ( Fn ("quicksort", [ "lst" ])
           , Match
               ( Sym "lst"
               , [ List [], List []
                 ; ( Cons (Bind "pivot", Bind "rest")
                   , Let
                       ( [ ( Val "smaller"
                           , FnAp
                               [ Sym "filter"
                               ; Fn ([ "x" ], FnAp [ Sym "<"; Sym "x"; Sym "pivot" ])
                               ; Sym "rest"
                               ] )
                         ; ( Val "greater"
                           , FnAp
                               [ Sym "filter"
                               ; Fn ([ "x" ], FnAp [ Sym ">="; Sym "x"; Sym "pivot" ])
                               ; Sym "rest"
                               ] )
                         ]
                       , FnAp
                           [ Sym "append"
                           ; FnAp
                               [ Sym "append"
                               ; FnAp [ Sym "quicksort"; Sym "smaller" ]
                               ; List [ Sym "pivot" ]
                               ]
                           ; FnAp [ Sym "quicksort"; Sym "greater" ]
                           ] ) )
                 ] ) ))
    ; Decl
        (Def
           ( Val "unsorted"
           , List [ Int 3; Int 1; Int 4; Int 1; Int 5; Int 9; Int 2; Int 6 ] ))
    ; Decl (Def (Val "sorted", FnAp [ Sym "quicksort"; Sym "unsorted" ]))
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
