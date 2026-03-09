# 型宣言

## ステータス

IN DISCUSSION

- 2026-03-09 ARCHIVED. `docs/type-declaration.md`にまとめた。
- 2026-03-09 back to IN DISCUSSION。再考中

## 型宣言の形式

```clojure
; 前 vs 中
(: x Int)
(def x 10)
; vs
(def (: x Int) 10)

(: f (-> Int (-> Int Int)))
(def (f x y) (+ x y))
; vs
(def (: (f x y) (-> Int (-> Int Int))) (+ x y))

(let ((: x Int)
      x 10
      
      (: f (-> Int (-> Int Int)))
      (f x y) (+ x y))
  (f x 10))
; vs
(let ((: x Int) 10
      (: (f x y) (-> Int (-> Int Int))) (+ x y))
  (f x 10))
```

中スタイルは、型推論を入れたときの記法と相性が悪い？

```clojure
(let ((x : Int) 10      ; 型宣言の値束縛
      (f x y) (+ x y))  ; 型推論の関数束縛
  (f x 10))
```

結局型宣言と関数定義の記法がかぶる。中置と絶望的に相性がわるそう

```clojure
(let ((f : (-> Int (-> Int Int)))
      (f x y) (+ x y))
  (f x 10))
```

つまり中が良さそう

```clojure
(let ((: x Int) 10
      (: (f x y) (-> Int (-> Int Int))) (+ x y))
  (f x 10))
```

無名関数はどうするか
```clojure
(fn ((: x Int) (: y Int)) (+ x y))
```
letがfn適用の糖衣構文という考えとは相性がよい。

```clojure
((fn ((: x Int) (: y Int)) (+ x y)) 10 20)
(let ((: x Int) 10
      (: y Int) 20)
  (+ x y))
; 上記は等価と考えても良い
```

そう考えると、関数束縛の記法は理が通らないかも

```clojure
(let ((: x Int) 10
      (: (f x y) (-> Int (-> Int Int))) (+ x y))
  (f x 10))
; これは下記だとすると無理がある？

((fn ((: x Int) (: f (-> Int (-> Int Int)))) (f x 10)) 10 (fn (x y) (+ x y)))
```

下記ならOK。

```clojure
(let ((: x Int) 10
      (: f (-> Int (-> Int Int))) (fn (x y) (+ x y)))
  (f x 10))
```

```clojure
(: x Int)
(def x 10)

(: f (-> Int (-> Int Int)))
(def (f x y) (+ x y))
```

前置 `:` は教育的じゃないし見にくいので、いきなり中置でいい気がする。

## まとめ

```clojure
(let ((x : Int) 10
      (g : (-> Int (-> Int Int))) (fn (x y) (* x y)))
  (f x 10))
```

```clojure  
(fn ((x : Int) (y : Int)) (+ x y))
```

```clojure
(x : Int)
(def x 10)

(f : (-> Int (-> Int Int)))
(def (f x y) (+ x y))

;; 下記は不採用
;; (def (x : Int) 10)
;; (def ((f x y) : (-> Int (-> Int Int))) (+ x y))
;; (def ((f (x : Int) (y :Int)) : Int) (+ x y))
```
