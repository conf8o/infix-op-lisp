## 構文の正誤についての特筆事項

common lispやschemeなど伝統的なlispとは違う構文を採用しているので、注意すること。
関数定義はschemeだが、let等はClojureを参考にしている。

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

- let式

```clojure
; 正しい
(let (x 10
      y 20)
  (+ x y))

; 誤り
(let ((x 10)
      (y 20))
  (+ x y))

```

- match式

```clojure
; 正しい
(match lst
  [] 0
  (x :: xs) (+ x (sum xs)))

; 誤り
(match lst
  ([] 0)
  ((x :: xs) (+ x (sum xs))))
```