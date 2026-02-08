# infix-op-lisp

## 基本構文

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
; a op b op c op ...

; fold form
; (op a b c ...)

; examples
; a * b * c
; (* a b c)
; x |> f |> g


; ============================================================
; Effect / Monad
; ============================================================

(do
  (a <- ma)
  (n := x)
  expr)


; ============================================================
; Applicative
; ============================================================

(let+ (a aa
       b ab
       c ac)
  (f a b c))

```

## 中置演算子のルールと例

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
; 1 + 2 + 3 + 4           ==> (+ 1 2 3 4)
; (+)                     ==> 0
; a && b && c             ==> (&& a b c)
; (<>)                    ==> ""

; --- chainable: binary nesting normal form (assoc-directed) ---
; Int -> Int -> Int       ==> (-> Int (-> Int Int))
; x |> f |> (g a)         ==> (|> (|> x f) (g a))       ; assoc-left
; f << g << h             ==> (<< f (<< g h))           ; assoc-right
; x :: xs :: []           ==> (:: x (:: xs []))         ; assoc-right (may be type error, OK)

; --- plain infix: binary only, no chaining ---
; a = b                   ==> (= a b)
; a = b = c               ==> error
; x : Int                 ==> (: x Int)
```
