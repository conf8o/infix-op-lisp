# 型宣言

`:` も型宣言を行うための演算子ととらえ、前置スタイル、中置スタイルで型宣言できます。

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

- letやfnでは、型宣言&束縛が可能
```clojure
(let ((x : Int) 10
      (g : (-> Int (-> Int Int))) (fn (x y) (* x y)))
  (f x 10))
```

```clojure  
(fn ((x : Int) (y : Int)) (+ x y))
```

- defは、評価形の宣言&評価の定義を行うための構文で、型宣言とは別であると考える

```clojure
(x : Int)
(def x 10)

(f : (-> Int (-> Int Int)))
(def (f x y) (+ x y))

; 下記の形では宣言&定義できない
; (def (x : Int) 10)
; (def ((f x y) : (-> Int (-> Int Int))) (+ x y))
; (def ((f (x : Int) (y :Int)) : Int) (+ x y))
```
