let rec list_sum__1 (lst__2 : int list) : int=
  match lst__2 with | [] -> 0 | x__3::xs__4 -> x__3 + (list_sum__1 xs__4)