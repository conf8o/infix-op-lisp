# 中置演算子Lisp系関数型言語の設計

## 基本構文の決定事項

ドキュメント `docs` 配下のファイルを参照してください。

- `docs/basic-data-structures.md`
- `docs/basic-syntax.md`
- `docs/def-types.md`
- `docs/infix-operators.md`
- `docs/type-declaration.md`

## 構文の正誤についての特筆事項

- 関数定義

```clojure
; 正しい
(def (f arg1 arg2 ...)
  body)

; 誤り
(def f (arg1 arg2 ...)
  body)
```

- 演算子

```clojure
; 正しい
(+ a b)
(a + b)
(a + b + c)

; 誤り
(+ a b c)
(a + b + c * d) ; 演算子の優先順位はないため、明示的な括弧が必要
```
