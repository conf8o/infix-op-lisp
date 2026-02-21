# 基本構文

## 特殊形式

```clojure
; 定義
(def name value)

; 関数定義
(def (fname arg1 arg2 ...)
  expr)

; 束縛
(let (name1 expr1
      name2 expr2
      ...)
  body)

; パターンマッチング
(match value
  pattern1 expr1
  pattern2 expr2
  ...)

; if式
(if pred
  then-expr
  else-epxr)

; 条件分岐
(cond
  pred1 expr1
  pred2 expr2
  ...
  else  exprN)

; 無名関数
(fn (arg1 arg2 ...)
  body)

; 非モナディックな逐次実行
(begin
  expr1
  expr2
  ...
  result)
```

## 演算子の糖衣構文

```clojure
; 連鎖
; (a op b op c op ...)

; 例
(a * b * c)
(x |> f |> g)
```

## モナドスタイル

- モナドの逐次処理（ある文脈における逐次的な処理の合成）を表現するための構文です。
- Haskellのdo記法をほぼそのまま輸入しています。

```clojure
(do
  (a <- ma)
  (n = x)
  expr)
```

## アプリカティブファンクタスタイル

- アプリカティブファンクタの関数適用（ある文脈において独立したいくつかの処理に対する関数適用）を表現するための構文です。
- OCamlのlet+を参考にしています。
- letとは違い逐次的な束縛ではないので、前の束縛を次の束縛のために使うことはできません(下記において、 `a`を`b`や`c`の計算処理に使うことはできません)。

```clojure
(with (a aa
       b ab
       c ac)
  (f a b c))
```
