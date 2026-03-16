let rec (list_sum__1 : int list -> int) =
  fun (lst__2 : int list) : int->
    match lst__2 with
    | [] -> 0
    | (x__3 : _)::(xs__4 : _) -> x__3 + (list_sum__1 xs__4)