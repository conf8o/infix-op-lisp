# 型の宣言とパターンマッチング

代数的データ型（ADT）の宣言とパターンマッチングについて定義します。

## 構造体

### 型定義

```scheme
; ============================================================
; レコード型の定義
; ============================================================

; --- 基本構文 ---
(type TypeName {.field1 Type1 .field2 Type2})

; 正規形
(type TypeName (struct (.field1 : Type1) (.field2 : Type2)))

; --- 例 ---
(type Point {.x Int .y Int})
(type User {.id Int .name String .email String})
```

**構造的等価性**: 構造が同じであれば、型名が異なっても同じ型として扱われます（型エイリアス）。

```scheme
(type Point {.x Int .y Int})
(type Vec2 {.x Int .y Int})
; Point と Vec2 は同じ型（どちらも同じ構造のエイリアス）
```

### 自動生成される要素

型定義により、以下が自動生成されます：

```scheme
(type Point {.x Int .y Int})

; 生成されるもの:
;   - コンストラクタ関数: Point : Int -> Int -> Point
;   - アクセサ関数: Point.x : Point -> Int
;   - アクセサ関数: Point.y : Point -> Int
```

### 値の構築

2つの方法があります：

```scheme
; --- 方法1: コンストラクタ関数（位置引数） ---
(def p1 (Point 10 20))

; 関数合成・高階関数の文脈で使用
(map Point xs ys)
(Point 10)  ; 部分適用可能

; --- 方法2: structリテラル（型推論文脈のみ） ---
(p2 : Point)
(def p2 {.x 10 .y 20})

; 型が明示されていない場合はエラー
(def q {.x 10 .y 20})  ; エラー！型推論不可
```

**注**: `.x` のようなドット始まりの記法はstructリテラル内でフィールド名を表します。

### フィールドアクセス

```scheme
(def p (Point 10 20))

; アクセサ関数を使用
(Point.x p)  ; => 10
(Point.y p)  ; => 20

; 高階関数での使用
(map Point.x points)  ; すべてのpointsのx座標を取得
```

**将来の拡張**: 型推論が十分に機能すれば、`(.x p)` のような短縮記法も検討します。

### 設計上の注意点

- **無名struct型は採用しない**: すべてのレコード型は名前を持つ必要があります
- **構造的等価性の帰結**: 同じ構造なら同じ型として扱われるため、`Point` と `Vec2` が同じ構造なら、`Point.x` と `Vec2.x` は同じアクセサ関数を指します
- **コンストラクタ関数の用途**: 関数合成、部分適用、高階関数への受け渡しなど。異なる型名のコンストラクタ（例：`Point` と `Vec2`）は構造が同じなら相互に使用可能
- **structリテラルの用途**: フィールド名を明示的に示したい場合、型推論が効く文脈

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
