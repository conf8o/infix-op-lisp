let rec (fact__1 : int -> int) =
  fun (n__2 : int) : int->
    if n__2 = 0 then 1 else n__2 * (fact__1 (n__2 - 1))