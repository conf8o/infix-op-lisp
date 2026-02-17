# 型の宣言とパターンマッチング

代数的データ型（ADT）の宣言とパターンマッチングについて定義します。

## レコード型（確定仕様）

### 型定義

```scheme
; ============================================================
; レコード型の定義
; ============================================================

; --- 基本構文 ---
(type TypeName {(field1 : Type1) (field2 : Type2) ...})

; --- 例 ---
(type Point {(x : Int) (y : Int)})
(type User {(id : Int) (name : String) (email : String)})
```

**名前的等価性**: 構造が同じでも、型名が異なれば別の型として扱われます。

```scheme
(type Point {(x : Int) (y : Int)})
(type Vec2 {(x : Int) (y : Int)})
; Point と Vec2 は別の型
```

### 自動生成される要素

型定義により、以下が自動生成されます：

```scheme
(type Point {(x : Int) (y : Int)})

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
(def p2 {(x = 10) (y = 20)})

; 型が明示されていない場合はエラー
(def q {(x = 10) (y = 20)})  ; エラー！型推論不可
```

**注**: `=` はstructリテラル専用の特殊構文です。

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
- **フィールド名の衝突**: 異なる型で同じフィールド名を使用しても問題ありません（`Point.x` と `Vec2.x` は別の関数）
- **コンストラクタ関数の用途**: 関数合成、部分適用、高階関数への受け渡しなど
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
  ...)

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
