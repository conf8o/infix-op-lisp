# 構造体（Struct）

構造体はフィールドを持つレコード型です。

## 型定義

### type（名前的等価性）

```scheme
(type Point {.x Int .y Int})

; 正規形
(type Point (struct .x Int .y Int))

構造が同じでも、型名が異なれば別の型として扱われます。
```

```scheme
(type Point {.x Int .y Int})
(type Vec2 {.x Int .y Int})
; Point と Vec2 は異なる型
```

### type-alias（構造的等価性）

```scheme
(type-alias Point {.x Int .y Int})

; 正規形
(type-alias Point (struct .x Int .y Int))
```

構造が同じであれば、型名が異なっても同じ型として扱われます。

```scheme
(type-alias Point {.x Int .y Int})
(type-alias Vec2 {.x Int .y Int})
; Point と Vec2 は同じ型
```

## 自動生成される要素

### type の場合

```scheme
(type Point {.x Int .y Int})

; 生成:
;   - Point.new : Int -> Int -> Point
;   - Point.x : Point -> Int
;   - Point.y : Point -> Int
```

### type-alias の場合

```scheme
(type-alias Vec2 {.x Int .y Int})

; 何も生成されない（ただの別名）
```

## 値の構築

### type の場合

**型構成子**（パターンマッチ可能）：

```scheme
(type Point {.x Int .y Int})

(def p (Point {.x 10 .y 20}))

; 正規形
(Point (struct .x 10 .y 20))
```

**コンストラクタ関数**（高階関数で使用）：

```scheme
(def p (Point.new 10 20))

; 部分適用・高階関数
(map Point.new xs ys)
```

### type-alias の場合

構造リテラルのみ（型推論文脈が必要）：

```scheme
(type-alias Vec2 {.x Int .y Int})

(v : Vec2)
(def v {.x 10 .y 20})

; 正規形
(struct .x 10 .y 20)
```

高階関数で使いたい場合は補助関数を定義：

```scheme
(def (make-vec2 x y) {.x x .y y})
(map make-vec2 xs ys)
```

## フィールドアクセス

### type の場合

```scheme
(def p (Point {.x 10 .y 20}))

(Point.x p)  ; => 10
(Point.y p)  ; => 20

; 高階関数で使用
(map Point.x points)

; 型推論が機能すれば、短縮記法も実装予定
(map .x points)
```

### type-alias の場合

型名付きアクセサ（`Vec2.x`）は存在しません。
フィールド短縮記法（`.x`）を使います：

```scheme
(v : Vec2)
(def v {.x 10 .y 20})

(.x v)  ; => 10
(.y v)  ; => 20
```

変数の型から構造体定義を参照し、フィールドの存在を確認します。

## パターンマッチング

### type の場合

型構成子による構築とマッチングは対称的：

```scheme
; 構築
(Point {.x 10 .y 20})

; マッチング
(match p
  (Point {.x 0 .y 0}) "origin"
  (Point {.x x .y y}) (+ x y))
```

コンストラクタ関数（`Point.new`）はマッチングで使えません。

### type-alias の場合

構造リテラルでマッチング：

```scheme
; 構築
(v : Vec2)
(def v {.x 10 .y 20})

; マッチング
(match v
  {.x 0 .y 0} "origin"
  {.x x .y y} (+ x y))
```
