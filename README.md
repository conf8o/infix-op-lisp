# infix-op-lisp

## 基本構文

Clojure, Haskell, OCamlをベースにシンプルな形の構文を用意する。

```
; ============================================================
; Core Forms (naming + surface shape)
; ============================================================

; local binding
(let (name1 expr1
      name2 expr2
      ...)
  body)

; pattern matching
(match value
  pattern1 expr1
  pattern2 expr2
  ...)

; conditional (predicate-based)
(cond
  pred1 expr1
  pred2 expr2
  ...
  else  exprN)

; non-monadic sequencing
(begin
  expr1
  expr2
  ...
  result)

; anonymous function
(fn (args...)
  body)


; ============================================================
; Operator Surface Policy
; ============================================================

; chain form
; (a op b op c op ...)

; fold form
; (op a b c ...)

; examples
; (a * b * c)
; (* a b c)
; (x |> f |> g)


; ============================================================
; Effect / Monad
; ============================================================

(do
  (a <- ma)
  (n := x)
  expr)


; ============================================================
; Applicative functor
; ============================================================

(let+ (a aa
       b ab
       c ac)
  (f a b c))

```

## 中置演算子のルールと例

演算の優先順位は従来のLisp同様 **存在しない**。ただし、同じ演算子での連鎖は可能とする。型と演算がモノイドを成す場合は、n項の畳み込み演算として適用可能。

```
; ============================================================
; Infix Declarations (infix first)
; ============================================================

; --- foldable infix ---
; Requires: Monoid on the given set/type (associativity + identity).
; Surface: allows chaining and prefix n-ary (including 0-arg).
; Normal form: n-ary application, e.g. a + b + c => (+ a b c), (+) => identity.
(infix-foldable (+)  Int    0)
(infix-foldable (*)  Int    1)
(infix-foldable (&&) Bool   true)
(infix-foldable (||) Bool   false)
(infix-foldable (<>) String "")

; --- chainable infix ---
; Requires: binary operator + associativity direction only (no algebraic laws).
; Surface: allows chaining via assoc-left/right.
; Normal form: binary nesting (no prefix n-ary).
(infix-chainable (->) assoc-right)
(infix-chainable (::) assoc-right)
(infix-chainable (|>) assoc-left)
(infix-chainable (<<) assoc-right)   ; function composition

; --- plain infix ---
; Surface: binary only, no chaining.
(infix (=))
(infix (:))
(infix (<))
(infix (>))

; ============================================================
; Type Declarations
; ============================================================

; --- prefix style ---
(: (+)  (Int -> Int -> Int))
(: (*)  (Int -> Int -> Int))
(: (&&) (Bool -> Bool -> Bool))
(: (||) (Bool -> Bool -> Bool))
(: (<>) (String -> String -> String))

(: (->) (Type -> Type -> Type))
(: (::) (T -> (List T) -> (List T)))
(: (|>) (A -> (A -> B) -> B))
(: (<<) ((B -> C) -> (A -> B) -> (A -> C)))

(: (=) (T -> T -> Bool))
(: (:) (Symbol -> Type -> Decl))
(: (<) (Int -> Int -> Bool))
(: (>) (Int -> Int -> Bool))

; --- infix style (same info, different surface form) ---
((+)  : (Int -> Int -> Int))
((*)  : (Int -> Int -> Int))
((&&) : (Bool -> Bool -> Bool))
((||) : (Bool -> Bool -> Bool))
((<>) : (String -> String -> String))

((->) : (Type -> Type -> Type))
((::) : (T -> (List T) -> (List T)))
((|>) : (A -> (A -> B) -> B))
((<<) : ((B -> C) -> (A -> B) -> (A -> C)))

((=)  : (T -> T -> Bool))
((:)  : (Symbol -> Type -> Decl))
((<)  : (Int -> Int -> Bool))
((>)  : (Int -> Int -> Bool))

; ============================================================
; Notes / Examples (for codex context)
; ============================================================

; --- foldable: n-ary normal form + 0-arg identity ---
; (1 + 2 + 3 + 4)         ==> (+ 1 2 3 4)
; (+)                     ==> 0
; (a && b && c)           ==> (&& a b c)
; (<>)                    ==> ""

; --- chainable: binary nesting normal form (assoc-directed) ---
; (Int -> Int -> Int)     ==> (-> Int (-> Int Int))
; (x |> f |> (g a))       ==> (|> (|> x f) (g a))       ; assoc-left
; (f << g << h)           ==> (<< f (<< g h))           ; assoc-right
; (x :: xs :: [])         ==> (:: x (:: xs []))         ; assoc-right (may be type error, OK)

; --- plain infix: binary only, no chaining ---
; (a = b)                 ==> (= a b)
; (a = b = c)             ==> error
; (x : Int)               ==> (: x Int)
```

## リスト・タプル

リストとタプルについては、特別なリテラル表現を用意し、パターンマッチを可能にする

; ============================================================
; Collection & Tuple Specification (Draft v0)
; ============================================================
; - Canonical AST is S-expression.
; - Surface literals always desugar to canonical forms.
; - Patterns never evaluate.
; - hash-map and array have no literal syntax (v0).
; ============================================================


; ============================================================
; 1. LIST
; ============================================================

; ------------------------------------------------------------
; Surface (expression)
; ------------------------------------------------------------

[]                 ; empty list
(x :: xs)          ; infix cons (right-associative)
[a b c]            ; list literal (whitespace-separated)


; ------------------------------------------------------------
; Canonical (expression)
; ------------------------------------------------------------

[]                 ; primitive empty list value
(:: x xs)          ; canonical prefix form

; Desugar rules:
; [e1 e2 ... en]
;   -> (e1 :: (e2 :: (... (en :: []) ...)))
;
; (x :: y)
;   -> (:: x y)


; ------------------------------------------------------------
; Types
; ------------------------------------------------------------

; List : Type -> Type
; [] : (List a)
; (::) : a -> (List a) -> (List a)


; ------------------------------------------------------------
; Pattern Matching (List)
; ------------------------------------------------------------

; Surface patterns:
[]                 ; empty list pattern
(p1 :: p2)         ; cons pattern
[p1 p2 ... pn]     ; list literal pattern

; Desugar (pattern):
; []               -> []
; (p1 :: p2)       -> (:: p1 p2)
; [p1 ... pn]      -> p1 :: (p2 :: (... (pn :: []) ...))

; Semantics:
; - No evaluation occurs in pattern position.
; - (::) in patterns performs structural decomposition.
; - (::) is right-associative.
; - List patterns are for structural binding, not function calls.


; ============================================================
; 2. TUPLE
; ============================================================

; ------------------------------------------------------------
; Arity Mapping
; ------------------------------------------------------------

; Tuple0 = Unit
; Tuple1 = Solo
; Tuple2
; Tuple3
; ...


; ------------------------------------------------------------
; Surface (expression)
; ------------------------------------------------------------

{}                 ; Unit (Tuple0)
{a}                ; Solo a (Tuple1)
{a b}              ; Tuple2
{a b c}            ; Tuple3
; whitespace-separated elements
; comma is NOT an operator


; ------------------------------------------------------------
; Canonical (expression)
; ------------------------------------------------------------

{}         -> (Unit)
{a}        -> (Solo a)
{a b}      -> (Tuple2 a b)
{a b c}    -> (Tuple3 a b c)
; ...

; TupleN constructors are ordinary constructors.
; They are used via standard function application in canonical form.


; ------------------------------------------------------------
; Types
; ------------------------------------------------------------

; Unit   : Type
; Solo   : Type -> Type
; Tuple2 : Type -> Type -> Type
; Tuple3 : Type -> Type -> Type -> Type
; ...

; Example:
; 1      : Int
; {1}    : (Solo Int)
; 1 != {1}


; ------------------------------------------------------------
; Pattern Matching (Tuple)
; ------------------------------------------------------------

; Surface patterns:
{}                 ; Unit
{p}                ; Solo
{p q}              ; Tuple2
{p q r}            ; Tuple3

; Desugar (pattern):
; {}        -> (Unit)
; {p}       -> (Solo p)
; {p q}     -> (Tuple2 p q)
; {p q r}   -> (Tuple3 p q r)
; ...

; Semantics:
; - Tuple patterns perform structural decomposition only.
; - No evaluation occurs in pattern position.
; - Arity is fixed by the static type of the scrutinee.
; - Matching the same scrutinee with multiple tuple arities
;   is a static type error.


; ============================================================
; 3. HASH-MAP (v0)
; ============================================================

; - No literal syntax.
; - Constructed via canonical form only:
;   (hash-map ...)
; - No special pattern syntax.


; ============================================================
; 4. ARRAY (v0)
; ============================================================

; - No literal syntax.
; - Constructed via canonical form only:
;   (array ...)
; - No special pattern syntax.
