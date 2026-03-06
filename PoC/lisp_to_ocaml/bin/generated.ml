let n = 10
let is_positive = true
let f x = n + x
let test_if () = if is_positive then 100 else (-100)
let abs x = if x < 0 then 0 - x else x
let rec fact n = if n = 0 then 1 else n * (fact (n - 1))
let main () = let y = 20 in let z = y + 100 in f z