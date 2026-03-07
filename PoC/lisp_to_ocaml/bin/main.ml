open Lisp_to_ocaml.Transpiler

let () =
  print_endline "start";
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
     ; リストのテスト
     (def empty_list [])
     (def nums [1 2 3])
     (def (list_sum lst)
       (match lst
         [] 0
         (:: x xs) (+ x (list_sum xs))))
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
    ; (* リストのテスト *)
      Decl (Def (Val "empty_list", List []))
    ; Decl (Def (Val "nums", List [ Int 1; Int 2; Int 3 ]))
    ; (* match式のテスト: リストの合計 *)
      Decl
        (Def
           ( Fn ("list_sum", [ "lst" ])
           , Match
               ( Sym "lst"
               , [ List [], Int 0
                 ; ( Cons (Bind "x", Bind "xs")
                   , FnAp [ Sym "+"; Sym "x"; FnAp [ Sym "list_sum"; Sym "xs" ] ] )
                 ] ) ))
    ; (* match式のテスト: リストの長さ *)
      Decl
        (Def
           ( Fn ("list_length", [ "lst" ])
           , Match
               ( Sym "lst"
               , [ List [], Int 0
                 ; ( Cons (Wildcard, Bind "xs")
                   , FnAp [ Sym "+"; Int 1; FnAp [ Sym "list_length"; Sym "xs" ] ] )
                 ] ) ))
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
  Printf.printf "Wrote bin/generated.ml\n";
  print_endline "end"
