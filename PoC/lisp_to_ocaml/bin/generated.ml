let rec filter (pred : int -> bool) (lst1 : int list) =
  match lst1 with
  | [] -> []
  | x2::xs2 -> if pred x2 then x2 :: (filter pred xs2) else filter pred xs2
let rec append (lst1_3 : int list) (lst2_3 : int list) =
  match lst1_3 with | [] -> lst2_3 | x4::xs4 -> x4 :: (append xs4 lst2_3)
let rec quicksort (lst5 : int list) =
  match lst5 with
  | [] -> []
  | pivot::rest ->
      let smaller = filter (fun (x7 : int) -> x7 < pivot) rest in
      let greater = filter (fun (x8 : int) -> x8 >= pivot) rest in
      append (append (quicksort smaller) [pivot]) (quicksort greater)
let unsorted = [3; 1; 4; 1; 5; 9; 2; 6]
let sorted = quicksort unsorted