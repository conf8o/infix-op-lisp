# 型の宣言とパターンマッチング

代数的データ型（ADT）の宣言とパターンマッチングについて定義します。

## 構造体

### 型定義

```scheme
; ============================================================
; レコード型の定義
; ============================================================

; --- 構造体 ---
(type TypeName {.field1 Type1 .field2 Type2})

; 正規形
(type TypeName (struct (.field1 : Type1) (.field2 : Type2)))

; --- 例 ---
(type User {.id Int .name String .email String})

; --- エイリアス ---
(type-alias TypeName {.field1 Type1 .field2 Type2})

(type-alias TypeName (struct (.field1 : Type1) (.field2 : Type2)))

; --- 例 ---
(type-alias Point {.x Int .y Int})
```

**名前等価性**: `type`の場合、構造が同じでも、名前が異なっていれば別の型として扱われます。

```scheme
(type User {.name String .age Int})
(type Admin {.name String .age Int})
```

**構造的等価性**: `type-alias` の場合、構造が同じであれば、名前が異なっても同じ型として扱われます。

```scheme
(type-alias Point {.x Int .y Int})
(type-alias Vec2 {.x Int .y Int})
; Point と Vec2 は同じ型（どちらも同じ構造のエイリアス）
```

### 自動生成される要素

#### type（名前的等価性）の場合

```scheme
(type Point {.x Int .y Int})

; 生成されるもの:
;   - 位置引数コンストラクタ: Point.new : Int -> Int -> Point
;   - アクセサ関数: Point.x : Point -> Int
;   - アクセサ関数: Point.y : Point -> Int
```

#### type-alias（構造的等価性）の場合

```scheme
(type-alias Vec2 {.x Int .y Int})

; 生成されるもの:
;   - なし（ただの型の別名）
```

```scheme
(type-alias Email String)

; 生成されるもの:
;   - なし（ただの型の別名）
```

**注**: type-alias は「型の別名」なので、何も生成されません。既存の型に別の名前を付けるだけです。

### 値の構築

構築方法は型定義の種類によって異なります。

#### type（名前的等価性）の場合

**方法1: 型構成子（パターンマッチ可能）**

```scheme
(type Point {.x Int .y Int})

; --- 基本構文 ---
(def p (Point {.x 10 .y 20}))

; 正規形
(Point (struct (.x 10) (.y 20)))

; パターンマッチング
(match p
  (Point {.x 0 .y 0}) "origin"
  (Point {.x x .y y}) ...)
```

**方法2: コンストラクタ関数（部分適用・高階関数で使用）**

```scheme
; --- 位置引数コンストラクタ ---
(def p (Point.new 10 20))

; 関数合成・高階関数の文脈で使用
(map Point.new xs ys)
(Point.new 10)  ; 部分適用可能

; パターンマッチングでは使えない（関数であって型構成子ではない）
(match p
  (Point.new 0 0) ...)  ; エラー！
```

型名でラップすることで、どの型を構築しているか明示的になります。

#### type-alias（構造的等価性）の場合

```scheme
(type-alias Point {.x Int .y Int})
(type-alias Vec2 {.x Int .y Int})

; --- 構造リテラルで構築 ---
(p : Point)
(def p {.x 10 .y 20})

(v : Vec2)
(def v {.x 10 .y 20})

; 構造的等価性により、p と v は同じ型
; Point と Vec2 は同じ構造体型の別名

; 正規形
(struct (.x 10) (.y 20))
```

**プリミティブ型の別名の場合**

```scheme
(type-alias Email String)
(type-alias UserId Int)

; そのまま値を使う
(email : Email)
(def email "test@example.com")  ; 通常の String

(id : UserId)
(def id 42)  ; 通常の Int
```

**高階関数で使いたい場合**

必要なら自分で補助関数を定義します：

```scheme
(type-alias Vec2 {.x Int .y Int})

; 補助関数を定義
(def make-vec2 (x y) {.x x .y y})

; 高階関数で使用
(map make-vec2 xs ys)
```

type-alias は単なる型の別名なので、コンストラクタ関数は生成されません。

#### パターンマッチングとの対称性

型構成子による構築とパターンマッチングは対称的です：

```scheme
; --- type の場合 ---
; 型構成子による構築
(Point {.x 10 .y 20})
; マッチング
(match p
  (Point {.x 0 .y 0}) "origin"
  (Point {.x x .y y}) ...)

; --- type-alias の場合 ---
; 構造リテラル（型推論文脈が必要）
(v : Vec2)
(def v {.x 10 .y 20})
; マッチング
(match v
  {.x 0 .y 0} "origin"
  {.x x .y y} ...)
```

**注**: 
- `.x` のようなドット始まりの記法はstructリテラル内でフィールド名を表します
- コンストラクタ関数（`Point.new`）はパターンマッチングでは使えません（関数であって型構成子ではないため）

### フィールドアクセス

#### type（名前的等価性）の場合

```scheme
(def p (Point {.x 10 .y 20}))

; 型名付きアクセサ関数を使用
(Point.x p)  ; => 10
(Point.y p)  ; => 20

; 高階関数での使用
(map Point.x points)  ; すべてのpointsのx座標を取得
```

#### type-alias（構造的等価性）の場合

```scheme
(type-alias Vec2 {.x Int .y Int})
(v : Vec2)
(def v {.x 10 .y 20})

; 型名付きアクセサは存在しない（alias なので）
; Vec2.x は使えない

; フィールド短縮記法
(.x v)  ; => 10
(.y v)  ; => 20
```

**プリミティブ型の場合**

```scheme
(type-alias Email String)
(email : Email)
(def email "test@example.com")

; String のメソッドをそのまま使える
; 特別なアクセサは存在しない
```

**注**: type-alias は構造体の別名なので、型名に紐づく要素（`Type.field`）は持ちません。

**将来の拡張**: 型推論が十分に機能すれば、type でも `(.x p)` のような短縮記法を使えるようにすることを検討します。

### 設計上の注意点

#### type（名前的等価性）

- **型の区別**: 構造が同じでも、型名が異なれば別の型として扱われます
  ```scheme
  (type User {.name String .age Int})
  (type Admin {.name String .age Int})
  ; User と Admin は異なる型
  ```
- **型安全性**: 意図しない型の混同を防げます
  ```scheme
  (type UserId Int)
  (type PostId Int)
  ; 明確に区別される
  ```
- **アクセサ関数**: 型ごとに専用のアクセサが生成されます
  ```scheme
  User.name : User -> String
  Admin.name : Admin -> String
  ; これらは異なる関数
  ```

#### type-alias（構造的等価性）

- **型の同一視**: 構造が同じなら、型名が異なっても同じ型として扱われます
  ```scheme
  (type-alias Point {.x Int .y Int})
  (type-alias Vec2 {.x Int .y Int})
  ; Point と Vec2 は同じ型
  ```
- **ただの別名**: 何も生成されません。既存の型に別の名前を付けるだけです
  ```scheme
  (type-alias Email String)
  ; Email は String の別名
  ; 特別なコンストラクタやアクセサは生成されない
  ```
- **多相性**: 特定の構造を持つあらゆる型で動作する関数を書けます
  ```scheme
  (def distance (p : {.x Int .y Int}) ...)
  ; Point として定義された値でも Vec2 として定義された値でも使える
  ```
- **型名付きアクセサは存在しない**: alias なので、`Type.field` 形式のアクセサは生成されません
  ```scheme
  (v : Vec2)
  (def v {.x 10 .y 20})
  ; Vec2.x は存在しない
  ; 将来的には (.x v) のような短縮記法を使う
  ```

#### 無名struct型は採用しない

すべてのレコード型は `type` または `type-alias` で名前を持つ必要があります。

#### 使い分けの指針

- **type を使うべき場合**: 型の区別が重要な場合（User vs Admin、UserId vs PostId など）
- **type-alias を使うべき場合**: 構造的な互換性が重要な場合（Point と Vec2 など）

## 直和型（TODO）

```scheme
; TODO: 直和型の定義
(type Maybe a
  Nothing
  (Just a))
```

## パターンマッチング（TODO）

```scheme
; TODO: レコード型のパターンマッチング
(match point
  {.x 0 .y 0}     ; 原点にマッチ
    "origin"
  {.x x .y y}     ; 任意の点（変数束縛）
    (x + y))

; TODO: 直和型のパターンマッチング
(match maybe-value
  Nothing ...
  (Just x) ...)
```

## レコードの更新（TODO）

```scheme
; TODO: immutableな更新構文
```

## ガード条件（TODO）

```scheme
; TODO: パターンマッチングでの条件分岐
```
