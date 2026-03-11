type ('a, 'b) validation =
  | Success of 'a
  | Failure of 'b list

let succeed x = Success x
let fail errs = Failure errs
let fail_one errs = Failure [ errs ]

let map f = function
  | Success x -> Success (f x)
  | Failure errs -> Failure errs


let map_failure f = function
  | Success x -> Success x
  | Failure errs -> Failure (List.map f errs)


let ( <*> ) f x =
  match f, x with
  | Success f', Success x' -> Success (f' x')
  | Failure errs_f, Success _ -> Failure errs_f
  | Success _, Failure errs_x -> Failure errs_x
  | Failure errs_f, Failure errs_x -> Failure (errs_f @ errs_x)


let ( >>= ) x f =
  match x with
  | Success v -> f v
  | Failure errs -> Failure errs


let lift2 f d1 d2 = map f d1 <*> d2
let product v1 v2 = lift2 (fun x y -> x, y) v1 v2

module Syntax = struct
  let ( let* ) = ( >>= )
  let ( let+ ) x f = map f x
  let ( and+ ) = product
end
