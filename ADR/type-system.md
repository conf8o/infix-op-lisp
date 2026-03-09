# 型システム

## ステータス

IN DISCUSSION

## 実装の方向性

型システムの導入については、「型環境と基底の型をもとに、式の型を判断する」という方向性の型付け判断を行う。

型検査のアルゴリズムを構築するうえでの基本的なアプローチは下記

- 一旦単純な型から考える。int, bool, function, listから始める。
- 型環境はタプル(変数, 型)のリストとし、スコープについてはいったん考えない。あとで考える
- 初期値の型環境を考える(`+`, `<`など)
- 初期値の型環境をもとに、単純な式について、その束縛先の変数の型を導く
- 関数はカリー化。例えば、 `+` は次のような型である
  - `("+", Fn (Int, Fn (Int, Int)))`

## 型宣言

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
(let ((: x Int) 10      ; 型宣言の値束縛
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
letがfn適用の糖衣構文だとすると相性がよい。

```clojure
((fn ((: x Int) (: y Int)) (+ x y)) 10 20)
(let ((: x Int) 10
      (: y Int) 20)
  (+ x y))
; 上記は等価と考えても良い
```

関数の変数の型宣言は許す？

```clojure
(let ((: (f x y) (-> Int (-> Int Int))) (+ x y)
      (: (g (: x Int) (: y Int)) Int) (+ x y))
  (f x 10))
```

それか `(let ((f x y) ...))` を許さないか。。これ許さない方がいいかもしれん

```clojure
(let ((: x Int) 10
      (: f (-> Int (-> Int Int))) (fn (x y) (+ x y)))
  (f x 10))
```

じゃあdefどうする？

```clojure
(def (f x y) (+ x y)) ; これを許すか否か
```

許して良さそう。

```clojure
(let ((: x Int) 10
      (: f (-> Int (-> Int Int))) (fn (x y) (+ x y)))
  (f x 10))
```

これは **型宣言&束縛** をしている。

defは、**評価の形の宣言&定義**。型宣言とは別の機構。
```clojure
(: x Int)
(def x 10)

(: f (-> Int (-> Int Int)))
(def (f x y) (+ x y))
```

## まとめ

- letやfnは、**型宣言&束縛**を行う。

```clojure
(let ((: x Int) 10
      (: f (-> Int (-> Int Int))) (fn (x y) (+ x y)))
  (f x 10))
```

```clojure
(fn ((: x Int) (: y Int)) (+ x y))
```

- defは、**評価の形の宣言&定義**を行う。型宣言は別とする。
```clojure
(: x Int)
(def x 10)

(: f (-> Int (-> Int Int)))
(def (f x y) (+ x y))
```
