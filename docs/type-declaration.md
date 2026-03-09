# 型宣言・型注釈

`:` も型宣言・型注釈を行うための演算子ととらえ、前置スタイル、中置スタイルで型宣言できます。

```clojure
; --- 前置スタイル ---
(: x Int)
(: f (Int -> Int))
(: +  (Int -> Int -> Int))

; --- 中置スタイル(同じ情報、異なる糖衣構文) ---
(x : Int)
(f : (Int -> Int))
(+ : (Int -> Int -> Int))
```

## 型宣言の利用例

- letやfnでの、型注釈&束縛

```clojure
(let ((x : Int) 10
      ((f x y) : (Int -> Int -> Int)) (+ x y)
      (g : (Int -> Int -> Int))) (fn (x y) (* x y)))
  (g (f x 10) 20)
```

- lambdaでの変数の型注釈

```clojure  
(fn ((x : Int) (y : Int)) (+ x y))
```

- defでの変数の型宣言

```clojure
(def (x : Int) 10)
(def ((f x y) : (-> Int (-> Int Int))) (+ x y))
; 下記は冗長ではあるが可能
(def ((f (x : Int) (y : Int)) : (-> Int (-> Int Int))) (+ x y))
```

- トップレベルにおける型宣言は分離することが可能

```clojure
(x : Int)
(def x 10)

(f : (-> Int (-> Int Int)))
(def (f x y) (+ x y))
```
