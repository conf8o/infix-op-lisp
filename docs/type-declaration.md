# 型宣言・型注釈

- defでの変数の型宣言

```clojure
(def x : Int 10)
(def (f x y) : Int (+ x y))
(def (f (x : Int) (y : Int)) : Int (+ x y))
```

```clojure
(def (f x y) : Int (+ x y))
; (f x y) という形で適用した結果 Int になるという意味合いになるのでこの形式を採用
; (+ x y) という式がIntであることもこの形式の根拠となっている
```

- トップレベルにおける型宣言は分離することが可能

```clojure
(x : Int)
(def x 10)

(f : (Int -> Int -> Int))
(def (f x y) (+ x y))
```

- letでの型注釈&束縛

```clojure
(let ((x : Int) 10
      ((f x y) : Int) (+ x y)
      (g : (Int -> Int -> Int))) (fn (x y) (* x y))
  (g (f x 10) 20))
```

- `fn`での型注釈

```clojure
(fn ((x : Int) (y : Int)) (+ x y))
(fn (x y) : Int (+ x y))
(fn ((x : Int) (y : Int)) : Int (+ x y))
```
