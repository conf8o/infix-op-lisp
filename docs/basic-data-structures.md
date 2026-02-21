# 基本的なデータ構造

リスト、タプル、レコードについては、特別なリテラル表現を用意し、パターンマッチングを可能にします。

## リスト

コードとしてのリストと、コレクションとしてのリストは区別します。`()` で囲われたデータはコードとしてのリストであり、`[]`で囲われたデータはコレクションとしてのリストです。

### 型宣言

```clojure
; --- 糖衣構文 ---
[Int]              ; Int のリスト型

; --- 正規形 ---
(List Int)         ; プレフィックス形式

; --- 脱糖ルール ---
; [T] ==> (List T)
```

### インスタンス化

```clojure
; --- 糖衣構文 ---
[]                 ; 空リスト
(x :: xs)          ; 中置cons(右結合)
[a b c]            ; リストリテラル(空白区切り)

; --- 正規形 ---
[]                 ; プリミティブな空リスト値
(:: x xs)          ; 正規プレフィックス形式

; --- 脱糖ルール ---
; [e1 e2 ... en]
;   ==> (e1 :: (e2 :: (... (en :: []) ...)))
;
; (x :: y)
;   ==> (:: x y)
```

### パターンマッチング

```clojure
; --- 糖衣構文でのパターンマッチング ---
[]                 ; 空リストパターン
(p1 :: p2)         ; consパターン
[p1 p2 ... pn]     ; リストリテラルパターン

; --- 脱糖ルール ---
; []          ==> []
; (p1 :: p2)  ==> (:: p1 p2)
; [p1 ... pn] ==> p1 :: (p2 :: (... (pn :: []) ...))

; --- パターンマッチングの例 ---
; 糖衣構文:
; (match list
;   [] "empty"
;   (x :: xs) "non-empty"
;   [a b] "exactly two elements")
;
; 正規形:
; (match list
;   [] "empty"
;   (:: x xs) "non-empty"
;   (:: a (:: b [])) "exactly two elements")
```

## タプル

### 型宣言

```clojure
; --- 糖衣構文 ---
{}                 ; Unit型（0要素タプル型）
{Int}              ; 1要素タプル型
{Int String}       ; 2要素タプル型
{Int String Bool}  ; 3要素タプル型

; --- 正規形 ---
(tuple)                    ; Unit型
(tuple Int)                ; 1要素タプル型
(tuple Int String)         ; 2要素タプル型
(tuple Int String Bool)    ; 3要素タプル型

; --- 脱糖ルール ---
; {}             ==> (tuple)
; {T1}           ==> (tuple T1)
; {T1 T2}        ==> (tuple T1 T2)
; {T1 T2 ... Tn} ==> (tuple T1 T2 ... Tn)
```

### インスタンス化

```clojure
; --- 糖衣構文 ---
{}                 ; 0要素タプル (Unit)
{a}                ; 1要素タプル
{a b}              ; 2要素タプル
{a b c}            ; 3要素タプル
; 空白区切りで要素を並べます

; --- 正規形 ---
(tuple)            ; 0要素タプル
(tuple a)          ; 1要素タプル
(tuple a b)        ; 2要素タプル
(tuple a b c)      ; 3要素タプル

; --- 脱糖ルール ---
; {}             ==> (tuple)
; {e1}           ==> (tuple e1)
; {e1 e2}        ==> (tuple e1 e2)
; {e1 e2 ... en} ==> (tuple e1 e2 ... en)
```

### データアクセス

```clojure
(def t {1 "a"})
(.0 t)             ; .n 記法
; == 1

(.1 t)
; == "a"
```

### パターンマッチング

```clojure
; --- 糖衣構文でのパターンマッチング ---
{}                 ; 0要素タプルパターン
{p}                ; 1要素タプルパターン
{p q}              ; 2要素タプルパターン
{p q r}            ; 3要素タプルパターン

; --- 脱糖ルール ---
; {}           ==> (tuple)
; {p}          ==> (tuple p)
; {p q}        ==> (tuple p q)
; {p q r}      ==> (tuple p q r)
; {p1 ... pn}  ==> (tuple p1 ... pn)

; --- パターンマッチングの例 ---
; 要素数が異なれば別の型なので、単一のmatch式では同じ要素数のみマッチング可能
;
; 糖衣構文:
; (match pair
;   {0 0} "origin"
;   {x y} (+ x y))
;
; 正規形:
; (match pair
;   (tuple 0 0) "origin"
;   (tuple x y) (+ x y))
```

## レコード

フィールド名はドット(.)で始まり、空白区切りでフィールドを列挙します。

### 型宣言

```clojure
; --- 糖衣構文 ---
{.x Int .y Int}         ; 2フィールドのレコード型
{.name String .age Int} ; 異なる型のフィールド

; --- 正規形 ---
(record .x Int .y Int)
(record .name String .age Int)

; --- 脱糖ルール ---
; {.f1 T1 .f2 T2 ... .fn Tn}
;   ==> (record .f1 T1 .f2 T2 ... .fn Tn)

; --- 型定義での使用例 ---
; (deftype Point (Point {.x Int .y Int}))
; (defalias Vec2 {.x Int .y Int})
; (defstruct Point {.x Int .y Int})
```

### インスタンス化

```clojure
; --- 糖衣構文 ---
{.x 10 .y 20}           ; レコードリテラル
{.name "Alice" .age 30} ; 異なる型のフィールド

; --- 正規形 ---
(record .x 10 .y 20)
(record .name "Alice" .age 30)

; --- 脱糖ルール ---
; {.f1 e1 .f2 e2 ... .fn en}
;   ==> (record .f1 e1 .f2 e2 ... .fn en)
```

### フィールドアクセス

```clojure
; --- deftype/defstruct の場合 ---
(.x record)        ; 短縮記法（型推論が必要）
(Point.x point)    ; 型名付きアクセサ（defstruct で自動生成）

; --- defalias の場合 ---
(.x record)        ; フィールド短縮記法のみ
```

### パターンマッチング

```clojure
; --- 糖衣構文でのパターンマッチング ---
{.x 0 .y 0}        ; リテラルマッチング
{.x x .y y}        ; フィールド束縛
{.x x}             ; 部分マッチング（他のフィールドは無視）

; フィールド名の順序は問いません
; 必要なフィールドのみ指定する部分マッチングが可能です

; --- 脱糖ルール ---
; {.f1 p1 .f2 p2 ... .fn pn}
;   ==> (record .f1 p1 .f2 p2 ... .fn pn)

; --- パターンマッチングの例 ---
; 糖衣構文:
; (match point
;   {.x 0 .y 0} "origin"
;   {.x x .y y} (+ x y))
;
; 正規形:
; (match point
;   (record .x 0 .y 0) "origin"
;   (record .x x .y y) (+ x y))
;
; --- deftype で定義された型を使う場合 ---
; 糖衣構文:
; (match point
;   (Point {.x 0 .y 0}) "origin"
;   (Point {.x x .y y}) (+ x y))
;
; 正規形:
; (match point
;   (Point (record .x 0 .y 0)) "origin"
;   (Point (record .x x .y y)) (+ x y))
```

## ハッシュマップ

ハッシュマップにはリテラル構文や特別なパターン構文はありません。

### インスタンス化

```clojure
; 正規形式でのみ構築可能:
(hash-map k1 v1 k2 v2 ...)
```

## 配列

配列にはリテラル構文や特別なパターン構文はありません。

### インスタンス化

```clojure
; 正規形式でのみ構築可能:
(array e1 e2 ... en)
```
