module Result = struct
  let sequence (results : ('a, 'b) result list) : ('a list, 'b) result =
    List.fold_right
      (fun r acc -> Result.product r acc |> Result.map (fun (r0, r1) -> r0 :: r1))
      results
      (Ok [])
end
