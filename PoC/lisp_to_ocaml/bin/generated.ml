let n = 10
let is_positive = true
let f x = n + x

let test_if () =
  if is_positive then
    100
  else
    -100


let abs x =
  if x < 0 then
    0 - x
  else
    x


let rec fact n =
  if n = 0 then
    1
  else
    n * fact (n - 1)


let main () =
  let y = 20 in
  let z = y + 100 in
  f z


let empty_list = []
let nums = [ 1; 2; 3 ]

let rec list_sum lst =
  match lst with
  | [] -> 0
  | x :: xs -> x + list_sum xs


let rec list_length lst =
  match lst with
  | [] -> 0
  | _ :: xs -> 1 + list_length xs
