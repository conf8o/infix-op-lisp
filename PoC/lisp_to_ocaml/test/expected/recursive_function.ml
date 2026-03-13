let rec fact__1 (n__2 : int) =
  if n__2 = 0 then 1 else n__2 * (fact__1 (n__2 - 1))