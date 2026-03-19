open Lisp_ast
module T = Lisp_type

(* ================================ *)
(* パーサーモナドの定義 *)
(* ================================ *)

type position =
  { line : int
  ; column : int
  }

type error_message = string

type 'a parse_result =
  | Success of 'a * string
  | Failure of error_message * position

type 'a parser = string -> 'a parse_result

let return (value : 'a) : 'a parser = fun input -> Success (value, input)

let fail (msg : error_message) : 'a parser =
  fun _input -> Failure (msg, { line = 0; column = 0 })


let ( >>= ) (p : 'a parser) (f : 'a -> 'b parser) : 'b parser =
  fun input ->
  match p input with
  | Success (value, rest) -> f value rest
  | Failure (msg, pos) -> Failure (msg, pos)


let map (f : 'a -> 'b) (p : 'a parser) : 'b parser = p >>= fun x -> return (f x)

module Syntax = struct
  let ( let* ) = ( >>= )
  let ( let+ ) x f = map f x
end

open Syntax

(* ================================ *)
(* 基本的なコンビネータ *)
(* ================================ *)

let choice (parsers : 'a parser list) : 'a parser =
  fun input ->
  let rec try_parsers = function
    | [] -> Failure ("No parser succeeded", { line = 0; column = 0 })
    | p :: rest ->
      (match p input with
       | Success _ as result -> result
       | Failure _ -> try_parsers rest)
  in
  try_parsers parsers


let ( <|> ) p1 p2 = choice [ p1; p2 ]

let rec many (p : 'a parser) : 'a list parser =
  fun input ->
  match p input with
  | Success (value, rest) ->
    (match many p rest with
     | Success (values, rest') -> Success (value :: values, rest')
     | Failure _ -> Success ([ value ], rest))
  | Failure _ -> Success ([], input)


let many1 (p : 'a parser) : 'a list parser =
  let* first = p in
  let* rest = many p in
  return (first :: rest)


let optional (p : 'a parser) : 'a option parser =
  (let* value = p in
   return (Some value))
  <|> return None


(* ================================ *)
(* 文字レベルの基底のパーサー *)
(* ================================ *)

(** パフォーマンスに改善の余地がありそう。部分文字列を毎回コピーしてるのが気になる *)

let satisfy (pred : char -> bool) : char parser =
  fun input ->
  if String.length input = 0 then
    Failure ("Unexpected end of input", { line = 0; column = 0 })
  else (
    let c = input.[0] in
    if pred c then
      Success (c, String.sub input 1 (String.length input - 1))
    else
      Failure
        ( Printf.sprintf "Character '%c' does not satisfy predicate" c
        , { line = 0; column = 0 } )
  )


let char (expected : char) : char parser = satisfy (fun c -> c = expected)

let string (expected : string) : string parser =
  fun input ->
  let len = String.length expected in
  if String.length input >= len && String.sub input 0 len = expected then
    Success (expected, String.sub input len (String.length input - len))
  else
    Failure (Printf.sprintf "Expected '%s'" expected, { line = 0; column = 0 })


let is_whitespace c = c = ' ' || c = '\t' || c = '\n' || c = '\r'

let whitespace : unit parser =
  let* _ = many (satisfy is_whitespace) in
  return ()


let skip_whitespace : 'a parser -> 'a parser =
  fun p ->
  let* _ = whitespace in
  p


let lexeme : 'a parser -> 'a parser =
  fun p ->
  let* value = p in
  let* _ = whitespace in
  return value


(* ================================ *)
(* トークンパーサー *)
(* ================================ *)

let digit : char parser = satisfy (fun c -> c >= '0' && c <= '9')

let letter : char parser =
  satisfy (fun c -> (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'))


let operator_char : char parser =
  satisfy (fun c ->
    c = '+'
    || c = '-'
    || c = '*'
    || c = '/'
    || c = '='
    || c = '<'
    || c = '>'
    || c = '&'
    || c = '|'
    || c = '%'
    || c = '^'
    || c = ':')


let identifier_char : char parser =
  letter <|> digit <|> operator_char <|> satisfy (fun c -> c = '_' || c = '?' || c = '!')


let integer : int parser =
  let* sign = optional (char '-') in
  let* digits = many1 digit in
  let num_str = String.of_seq (List.to_seq digits) in
  let num = int_of_string num_str in
  return
    (match sign with
     | Some _ -> -num
     | None -> num)


let identifier : string parser =
  let* first = letter <|> operator_char in
  let* rest = many identifier_char in
  return (String.of_seq (List.to_seq (first :: rest)))


let keyword (kw : string) : string parser =
  let* id = lexeme identifier in
  if id = kw then
    return id
  else
    fail (Printf.sprintf "Expected keyword '%s', got '%s'" kw id)


(* ================================ *)
(* 型パーサー *)
(* ================================ *)

let rec parse_type () : T.lisp_type parser =
  skip_whitespace
    (keyword "Int"
     >>= (fun _ -> return T.Int)
     <|> (keyword "Bool" >>= fun _ -> return T.Bool)
     <|> (keyword "Unit" >>= fun _ -> return T.Unit)
     <|> (char '_' >>= fun _ -> return T.Inferred)
     <|> parse_list_type ()
     <|> parse_arrow_type ()
     <|> (lexeme identifier >>= fun var -> return (T.Var var)))


and parse_list_type () : T.lisp_type parser =
  let* _ = lexeme (char '[') in
  let* elem_type = parse_type () in
  let* _ = lexeme (char ']') in
  return (T.List elem_type)


and parse_arrow_type () : T.lisp_type parser =
  let* _ = lexeme (char '(') in
  let rec parse_arrow_parts acc =
    let* arg_type = parse_type () in
    let* arrow_opt = optional (lexeme (string "->")) in
    match arrow_opt with
    | Some _ -> parse_arrow_parts (arg_type :: acc)
    | None ->
      let* _ = lexeme (char ')') in
      let all_types = List.rev (arg_type :: acc) in
      (match all_types with
       | [] -> fail "Empty arrow type"
       | [ single ] -> return single
       | _ ->
         return
           (List.fold_right
              (fun t1 t2 -> T.Arrow (t1, t2))
              (List.tl all_types)
              (List.hd all_types)))
  in
  parse_arrow_parts []


and parse_type_annotation () : T.lisp_type parser =
  let* _ = lexeme (char ':') in
  parse_type ()


(* ================================ *)
(* パターンパーサー *)
(* ================================ *)

let rec parse_patt () : typed_patt parser =
  skip_whitespace
    (parse_bool_patt ()
     <|> parse_int_patt ()
     <|> parse_wildcard_patt ()
     <|> parse_list_patt ()
     <|> parse_cons_patt ()
     <|> parse_bind_patt ())


and parse_bool_patt () : typed_patt parser =
  keyword "true"
  >>= (fun _ -> return (bool_patt true))
  <|> (keyword "false" >>= fun _ -> return (bool_patt false))


and parse_int_patt () : typed_patt parser =
  lexeme integer >>= fun n -> return (int_patt n)


and parse_wildcard_patt () : typed_patt parser =
  char '_' >>= fun _ -> return (wildcard_patt ())


and parse_list_patt () : typed_patt parser =
  let* _ = lexeme (char '[') in
  let* patterns = many (parse_patt ()) in
  let* _ = lexeme (char ']') in
  return (list_patt patterns)


and parse_cons_patt () : typed_patt parser =
  let* _ = lexeme (char '(') in
  let* first = parse_patt () in
  let* _ = lexeme (string "::") in
  let* second = parse_patt () in
  let* _ = lexeme (char ')') in
  return (cons_patt first second)


and parse_bind_patt () : typed_patt parser =
  let typed () =
    let* _ = lexeme (char '(') in
    let* name = lexeme identifier in
    let* ty = parse_type_annotation () in
    let* _ = lexeme (char ')') in
    return (Bind (top_var name), ty)
  in
  let simple () =
    let* name = lexeme identifier in
    return (Bind (top_var name), T.Inferred)
  in
  typed () <|> simple ()


let parse_val_binding_patt () : binding_patt parser =
  let* name = parse_patt () in
  return (Val name)


(* ================================ *)
(* 式パーサー *)
(* ================================ *)

let rec parse_expr () : lisp_expr parser =
  skip_whitespace
    (parse_bool_expr ()
     <|> parse_int_expr ()
     <|> parse_list_expr ()
     <|> parse_paren_expr ()
     <|> parse_sym_expr ())


and parse_bool_expr () : lisp_expr parser =
  keyword "true"
  >>= (fun _ -> return (Bool true))
  <|> (keyword "false" >>= fun _ -> return (Bool false))


and parse_int_expr () : lisp_expr parser = lexeme integer >>= fun n -> return (Int n)

and parse_list_expr () : lisp_expr parser =
  let* _ = lexeme (char '[') in
  let* exprs = many (parse_expr ()) in
  let* _ = lexeme (char ']') in
  return (List exprs)


and parse_sym_expr () : lisp_expr parser =
  lexeme identifier >>= fun name -> return (Sym (top_var name))


and parse_paren_expr () : lisp_expr parser =
  parse_let_form ()
  <|> parse_fn_form ()
  <|> parse_if_form ()
  <|> parse_match_form ()
  <|> parse_application ()


and parse_let_form () : lisp_expr parser =
  let* _ = lexeme (char '(') in
  let* _ = keyword "let" in
  let* _ = lexeme (char '(') in
  let* bindings = parse_let_bindings () in
  let* _ = lexeme (char ')') in
  let* body = parse_expr () in
  let* _ = lexeme (char ')') in
  return (Let (bindings, body))


and parse_let_bindings () : binding list parser = many (parse_let_binding ())

and parse_let_simple_func_binding_patt () : binding_patt parser =
  let* _ = lexeme (char '(') in
  let* name = lexeme identifier in
  let* params = many (parse_patt ()) in
  let* _ = lexeme (char ')') in
  return (Func (top_var name, params, T.Inferred))


and parse_let_typed_func_binding_patt () : binding_patt parser =
  let* _ = lexeme (char '(') in
  let* _ = lexeme (char '(') in
  let* name = lexeme identifier in
  let* params = many (parse_patt ()) in
  let* _ = lexeme (char ')') in
  let* ret_type = parse_type_annotation () in
  let* _ = lexeme (char ')') in
  return (Func (top_var name, params, ret_type))


and parse_let_binding () : binding parser =
  skip_whitespace
    (let* patt =
       parse_val_binding_patt ()
       <|> parse_let_typed_func_binding_patt ()
       <|> parse_let_simple_func_binding_patt ()
     in
     let* value = parse_expr () in
     return (patt, value))


and parse_fn_form () : lisp_expr parser =
  let* _ = lexeme (char '(') in
  let* _ = keyword "fn" in
  let* _ = lexeme (char '(') in
  let* params = many (parse_patt ()) in
  let* _ = lexeme (char ')') in
  let* type_opt = optional (parse_type_annotation ()) in
  let* body = parse_expr () in
  let* _ = lexeme (char ')') in
  let ret_type =
    match type_opt with
    | Some t -> t
    | None -> T.Inferred
  in
  return (Fn (params, ret_type, body))


and parse_if_form () : lisp_expr parser =
  let* _ = lexeme (char '(') in
  let* _ = keyword "if" in
  let* pred = parse_expr () in
  let* then_expr = parse_expr () in
  let* else_expr = parse_expr () in
  let* _ = lexeme (char ')') in
  return (If (pred, then_expr, else_expr))


and parse_match_form () : lisp_expr parser =
  let* _ = lexeme (char '(') in
  let* _ = keyword "match" in
  let* value = parse_expr () in
  let* cases = many (parse_match_case ()) in
  let* _ = lexeme (char ')') in
  return (Match (value, cases))


and parse_match_case () : matching_case parser =
  let* pattern = parse_patt () in
  let* expr = parse_expr () in
  return (pattern, expr)


and parse_application () : lisp_expr parser =
  let* _ = lexeme (char '(') in
  let* exprs = many (parse_expr ()) in
  let* _ = lexeme (char ')') in
  return (FnAp exprs)


(* ================================ *)
(* 宣言パーサー *)
(* ================================ *)

let parse_def_val_binding_patt () : binding_patt parser =
  let* patt = parse_patt () in
  let* otp_type = optional (parse_type_annotation ()) in
  match otp_type with
  | Some t ->
    (match patt with
     | p, _ -> return (Val (p, t)))
  | None -> return (Val patt)


let parse_def_func_binding_patt () : binding_patt parser =
  let* _ = lexeme (char '(') in
  let* name = lexeme identifier in
  let* params = many (parse_patt ()) in
  let* _ = lexeme (char ')') in
  let* opt_type = optional (parse_type_annotation ()) in
  let ret_type =
    match opt_type with
    | Some t -> t
    | None -> T.Inferred
  in
  return (Func (top_var name, params, ret_type))


let parse_def_binding_patt () : lisp_decl parser =
  let* binding_patt = parse_def_val_binding_patt () <|> parse_def_func_binding_patt () in
  let* value = parse_expr () in
  return (Def (binding_patt, value))


let parse_def () : lisp_decl parser =
  let* _ = lexeme (char '(') in
  let* _ = keyword "def" in
  let* def = parse_def_binding_patt () in
  let* _ = lexeme (char ')') in
  return def


(* ================================ *)
(* トップレベルパーサー *)
(* ================================ *)

let parse_lisp () : lisp parser =
  skip_whitespace
    ((let* decl = parse_def () in
      return (Decl decl))
     <|> let* expr = parse_expr () in
         return (Expr expr))


let parse (input : string) : (lisp list, string) result =
  match many (parse_lisp ()) input with
  | Success (result, _) -> Ok result
  | Failure (msg, _) -> Error msg
