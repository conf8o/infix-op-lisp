# 型定義

## 代数的データ型

### deftype

直積型や直和型、ラッパー型を定義します。

- 直積型

```clojure
(deftype Point (Point {.x Int .y Int}))
; 正規形
(deftype Point (Point (record .x Int .y Int)))

(deftype Vec2 (Vec2 {Int Int}))
; 正規形
(deftype Vec2 (Vec2 (tuple Int Int)))
```

- 直和型

```clojure
(deftype Shape
  (Rectangle Int Int)
  (Circle Int)
  (Triangle Int Int Int))
```

- ラッパー型

```clojure
(deftype Email (Email String))
```

### defstruct

直積型(レコード, タプル)に特化したdeftypeの糖衣構文です。コンストラクタやアクセサを自動生成します。

```clojure
(defstruct Point {.x Int .y Int})
; 正規形
(deftype Point (Point (record .x Int .y Int)))

(defstruct Vec2 {Int Int})
; 正規形
(deftype Vec2 (Vec2 (tuple Int Int)))
```

### defalias

型エイリアスを定義します。

```clojure
(defalias Point {.x Int .y Int})
(defalias UserName String)
```

構造が同じであれば、型名が異なっても同じ型として扱われます。

```clojure
(defalias Point {.x Int .y Int})
(defalias Vec2 {.x Int .y Int})
; Point と Vec2 は同じ型
```

## 生成される関数

```clojure
(deftype Point (Point {.x Int .y Int}))
(deftype Email (Email String))
; 生成:
;   - Point : {.x Int .y Int} -> Point
;
;   - Email : String -> Email

(deftype Shape
  (Rectangle Int Int)
  (Circle Int)
  (Triangle Int Int Int))
; 生成:
;   - Rectangle : Int -> Int -> Shape
;   - Circle : Int -> Shape
;   - Triangle : Int -> Int -> Int -> Shape

(defstruct Point {.x Int .y Int})
(defstruct Vec2 {Int Int})
; 生成:
;   - Point : {.x Int .y Int} -> Point
;   - Point.make : Int -> Int -> Point
;   - Point.x : Point -> Int
;   - Point.y : Point -> Int
;
;   - Vec2 : {Int Int} -> Vec2
;   - Vec2.make : Int -> Int -> Vec2
;   - Vec2.0 : Vec2 -> Int
;   - Vec2.1 : Vec2 -> Int


(defalias Vec2 {.x Int .y Int})
; ただの別名なので、何も生成されない
```

## 値の構築

### deftype/defstruct の場合

```clojure
(deftype Point (Point {.x Int .y Int}))
; または
(defstruct Point {.x Int .y Int})

(def p (Point {.x 10 .y 20}))

; 正規形
(Point (record .x 10 .y 20))
```

**コンストラクタ**（defstructのみ）：

```clojure
(defstruct Point {.x Int .y Int})

(def p (Point.make 10 20))

; 例
(map2 Point.make xs ys)
```

### defalias の場合

```clojure
(defalias Vec2 {.x Int .y Int})

(v : Vec2)
(def v {.x 10 .y 20})

; 正規形
(record .x 10 .y 20)
```

高階関数で使いたい場合は補助関数を定義：

```clojure
(def (make-vec2 x y) {.x x .y y})
(map2 make-vec2 xs ys)
```

## フィールドアクセス

### deftype/defstruct の場合

```clojure
(defstruct Point {.x Int .y Int})

(def p (Point {.x 10 .y 20}))

(Point.x p)  ; => 10
(Point.y p)  ; => 20

; 例
(map Point.x points)
```

**注**: アクセサ（`Point.x`, `Point.y`）は defstruct で自動生成されます。deftype の場合は手動で定義する必要があります。

### defalias の場合

型名付きアクセサ（`Vec2.x`）は存在しません。
フィールド短縮記法（`.x`）を使います：

```clojure
(defalias Vec2 {.x Int .y Int})

(v : Vec2)
(def v {.x 10 .y 20})

(.x v)  ; => 10
(.y v)  ; => 20
```

変数の型からレコードの定義を参照し、フィールドの存在を確認します。

## パターンマッチング

### deftype/defstruct の場合

```clojure
(deftype Point (Point {.x Int .y Int}))
; または
(defstruct Point {.x Int .y Int})

; 構築
(def p (Point {.x 10 .y 20}))

; マッチング
(match p
  (Point {.x 0 .y 0}) "origin"
  (Point {.x x .y y}) (x + y))
```

直和型（列挙型）の場合：

```clojure
(deftype Shape
  (Rectangle Int Int)
  (Circle Int)
  (Triangle Int Int Int))

; 構築
(def s1 (Rectangle 10 20))
(def s2 (Circle 5))
(def s3 (Triangle 3 4 5))

; マッチング
(area : (Shape -> Float))
(def (area shape)
  (match shape
    (Rectangle w h) (w * h)
    (Circle r) (3.14 * r * r)
    (Triangle a b c) 
      ; ヘロンの公式
      (let (s ((a + b + c) / 2))
        (sqrt (s * (s - a) * (s - b) * (s - c))))))
```

**注**: コンストラクタ関数（`Point.make`）はマッチングで使えません。マッチングには型構成子（`Point`, `Rectangle`, `Circle` など）を使います。

### defalias の場合

```clojure
(defalias Vec2 {.x Int .y Int})

; 構築
(v : Vec2)
(def v {.x 10 .y 20})

; マッチング
(match v
  {.x 0 .y 0} "origin"
  {.x x .y y} (x + y))
```
