# パターンマッチング束縛

## ステータス

IN DISCUSSION

- 2026-03-15 開始

## 概要

`let`や`def`での束縛において、単純な変数名だけでなく、パターンマッチングによる束縛を可能にする。

```clojure
; リストのパターン
(let ((x :: xs) lst)
  ...)

; タプルのパターン
(let ({a b} pair)
  ...)
```

### 参考

- Haskellでのlet束縛系

https://chatgpt.com/share/69b6beaf-e5e4-8010-96fc-1359628977ff

## 構文の選択肢

### オプション1: パターンを直接書く（Simple Pattern）

現在の`let`構文を自然に拡張する形。

```clojure
; 変数束縛（現状）
(let (x 10
      y 20)
  body)

; パターン束縛（拡張）
(let ((x :: xs) [1 2 3]
      {a b} {10 20})
  body)
```

**メリット**:
- 記法が簡潔
- 他の関数型言語（OCaml、Haskell等）と似た見た目
- 変数束縛との統一感

**デメリット**:
- 関数束縛の糖衣構文との区別が曖昧になる可能性
  ```clojure
  ; これは関数束縛
  (let ((f x) (+ x 1)) ...)
  
  ; これはパターン束縛？ それとも関数束縛？
  (let ((x :: xs) lst) ...)
  ```

### オプション2: キーワードで明示（Explicit Pattern）

パターンマッチングであることを明示的に示す。

```clojure
(let ((:match (x :: xs) [1 2 3])
      (:match {a b} {10 20}))
  body)

; または
(let ((pattern (x :: xs) [1 2 3])
      (pattern {a b} {10 20}))
  body)
```

**メリット**:
- 意図が明確
- 関数束縛との区別が容易

**デメリット**:
- 冗長
- 他言語との見た目の違い

### オプション3: match式への脱糖を前提（Desugar to Match）

構文レベルでは特別扱いせず、内部的に`match`式へ変換する前提で設計。

```clojure
; 書き方は オプション1 と同じ
(let ((x :: xs) lst) body)

; 内部的には以下に脱糖
(match lst
  (x :: xs) body
  _ (error "pattern match failed"))
```

**メリット**:
- 実装がシンプル
- 意味論が明確（matchの意味論を再利用）

**デメリット**:
- 非全域パターンでもコンパイルできてしまう（実行時エラー）
- エラーハンドリングの方針が必要

## 既存構文との関係

### 関数束縛との区別

現在の`let`には関数束縛の糖衣構文がある：

```clojure
(let ((fname arg1 arg2) body)
  ...)

; これは下記の糖衣構文
(let (fname (fn (arg1 arg2) body))
  ...)
```

パターンマッチング束縛を導入する場合、以下のような区別が必要：

**区別の方針案**:

1. **構文解析時に判定**
   - パターン開始記号（`::`、`{}`など）が出現したらパターン束縛
   - それ以外で`(name args...) expr`の形なら関数束縛
   - シンプルな`name expr`なら変数束縛

2. **位置で判定**
   - 左辺が2要素なら関数束縛: `(fname arg1 arg2) body`
   - 左辺が1要素なら変数またはパターン束縛: `(x :: xs) lst`

3. **型情報で判定**（型検査後）
   - 右辺が関数型なら関数束縛として扱う
   - ただし、これは脱糖前に行うのが難しい

**暫定方針**: 
構文的な特徴（`::`、`{}`、`[]`などのパターン固有記号）で判定し、それ以外は既存の規則に従う。

### defでの扱い

`def`でもパターンマッチング束縛を許すか？

```clojure
; 許す場合
(def (x :: xs) some-list)

; 許さない場合
; defは常にトップレベルの名前を定義するもの
```

**暫定方針**: 
まずは`let`のみで導入し、`def`での必要性は後で検討。

## マッチ失敗時の挙動

非全域パターンに対する方針：

### 選択肢A: 実行時エラー（Partial Pattern）

```clojure
(let ((x :: xs) [])  ; 実行時にエラー
  ...)
```

- OCamlやHaskellのletと同じ挙動
- 実装はシンプル（matchへの脱糖で済む）
- デメリット: 安全性が低い

### 選択肢B: コンパイル時エラー（Exhaustiveness Check）

```clojure
(let ((x :: xs) lst)  ; コンパイルエラー: 非全域パターン
  ...)
```

- 安全性が高い
- デメリット: 実装が複雑（全域性チェックが必要）

### 選択肢C: 全域パターンのみ許可（Total Pattern Only）

リテラルパターンを禁止し、束縛可能なパターンのみ許可：

```clojure
; OK: 全域パターン
(let ((x :: xs) lst)  ; 常にマッチする（空リストの場合はxsが[]になる）
  ...)

; NG: リテラルパターン
(let ([] lst)  ; 禁止
  ...)
```

- **注意**: consパターン `(x :: xs)` は実際には非全域（空リストにマッチしない）

### 選択肢D: match式の使用を推奨（No Special Syntax）

パターンマッチング束縛は導入せず、既存の`match`式を使ってもらう：

```clojure
; これを使う
(match lst
  [] (...)
  (x :: xs) (...))
```

**暫定方針**: 
選択肢A（実行時エラー）で開始。将来的に選択肢Bへ移行を検討。
これにより、まず構文と意味論を確立し、安全性は段階的に向上させる。

## 型システムとの整合性

### 型推論

パターンから型制約を導出：

```clojure
(let ((x :: xs) lst)
  ...)

; lstの型: パターンから [α] と推論
; xの型: α
; xsの型: [α]
```

疑似コード:
```
infer_pattern_type(x :: xs) =
  let elem_type = fresh_type_var() in
  let list_type = List(elem_type) in
  constraints: [
    (x, elem_type),
    (xs, List(elem_type))
  ]
  return (list_type, constraints)
```

### 型注釈

パターン全体に型注釈を付ける方針：

```clojure
; 型注釈あり
(let (((x :: xs) : [Int]) lst)
  ...)

; 型注釈なし（推論）
(let ((x :: xs) lst)
  ...)
```

パターン内の個別の変数への注釈は、今は考えない（将来的な拡張）。

## 大まかな実装方向性

### フェーズ1: パース・脱糖

```
構文:
  (let (pattern expr) body)

脱糖:
  (let (pattern expr) body)
  ↓
  (match expr
    pattern body
    _ (error "pattern match failed"))
```

利点: 既存のmatch式の実装を再利用できる

### フェーズ2: 型検査

```
型検査:
  1. パターンから型制約を抽出
  2. 式の型を推論
  3. パターンと式の型を単一化
  4. bodyの型を、パターンから得られた変数の型環境で検査
```

疑似コード:
```
typecheck(Let(pattern, expr, body)) =
  expr_type <- typecheck(expr)
  (pattern_type, bindings) <- infer_pattern(pattern)
  unify(expr_type, pattern_type)
  extend_env(bindings)
  typecheck(body)
```

### フェーズ3: トランスパイル

OCamlへの変換オプション:

**オプションA: let束縛として変換**
```ocaml
(* Lisp: (let ((x :: xs) lst) body) *)
let (x :: xs) = lst in body
```

**オプションB: match式として変換**
```ocaml
(* Lisp: (let ((x :: xs) lst) body) *)
match lst with
| x :: xs -> body
| _ -> failwith "pattern match failed"
```

どちらもOCamlとして正しいが、エラーメッセージの質などを考慮して選択する。

**暫定方針**: オプションAで開始（OCamlのlet束縛に直接マッピング）

## スコープ管理

パターンから得られる各変数に、個別のスコープ識別子を割り当てる：

```clojure
(let ((x :: xs) lst)
  ...)

; 内部表現（疑似コード）:
; x: ("x", "__1")
; xs: ("xs", "__2")
```

既存のスコープ管理の仕組みをそのまま適用できる。

## 複数束縛の扱い

現在のletは複数の束縛を逐次的に処理：

```clojure
(let (x 10
      y (+ x 1))  ; xが使える
  ...)
```

パターン束縛も同様に扱う：

```clojure
(let ((x :: xs) lst
      y (+ x 1))  ; パターンから得られたxが使える
  ...)
```

これは脱糖によって自然に実現される：

```
(let ((x :: xs) lst
      y (+ x 1))
  body)
  ↓
(match lst
  (x :: xs) (let (y (+ x 1)) body)
  _ error)
```

## 段階的な導入計画

### Phase 1（最小限）
- letでのリストパターン（consパターン）のみ
- 実行時エラー方式
- 型推論の基本実装

### Phase 2（拡張）
- タプルパターンのサポート
- ネストしたパターンのサポート
- 型注釈のサポート

### Phase 3（高度な機能）
- 全域性チェック（コンパイル時エラー）
- defでのパターン束縛
- より複雑なパターン

## 未決定事項

- [ ] 具体的な構文の確定（オプション1 vs 2 vs 3）
- [ ] defでのパターン束縛を許すか
- [ ] ワイルドカードパターンの扱い
- [ ] 全域性チェックの実装タイミング
- [ ] エラーメッセージの設計

## 次のステップ

1. 構文の選択肢を決定（オプション1を推奨）
2. Phase 1の実装範囲を確定
3. パーサーの拡張を検討
4. 型検査器への影響を分析
