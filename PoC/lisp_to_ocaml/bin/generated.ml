let rec filter pred lst =
  match lst with
  | [] -> []
  | x::xs -> if pred x then x :: (filter pred xs) else filter pred xs
let rec append lst1 lst2 =
  match lst1 with | [] -> lst2 | x::xs -> x :: (append xs lst2)
let rec quicksort lst =
  match lst with
  | [] -> []
  | pivot::rest ->
      let smaller = filter (fun x -> x < pivot) rest in
      let greater = filter (fun x -> x >= pivot) rest in
      append (append (quicksort smaller) [pivot]) (quicksort greater)
let unsorted = [3; 1; 4; 1; 5; 9; 2; 6]
let sorted = quicksort unsorted