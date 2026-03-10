type ('a, 'b) validate = ('a, 'b list) result

let succeed x = Ok x
let fail errs = Error errs
let map f v = Result.map f v
let map_error f v = Result.map_error f v

let ( <*> ) f x =
  match f, x with
  | Ok f', Ok x' -> Ok (f' x')
  | Error errs_f, Ok _ -> Error errs_f
  | Ok _, Error errs_x -> Error errs_x
  | Error errs_f, Error errs_x -> Error (errs_f @ errs_x)


let ( >>= ) x f =
  match x with
  | Ok v -> f v
  | Error errs -> Error errs


let lift2 f d1 d2 = map f d1 <*> d2
let product v1 v2 = lift2 (fun x y -> x, y) v1 v2

module Syntax = struct
  let ( let* ) = ( >>= )
  let ( let+ ) x f = map f x
  let ( and+ ) = product
end
