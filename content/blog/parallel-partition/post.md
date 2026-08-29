Partition is an operation which splits an container into two containers where if
elements satisfy the predicate they get moved to the first and if they do not
they get moved to the other container. In the language Haskell the first-class
container is lists and you would implement it using recursion where you first
recursively call partition and then prepend the element the element to either
list depending on if it satisfy the predicate or not.

```
partition :: (a -> Bool) -> [a] -> ([a], [a])
partition _ [] = ([], [])
partition p (x:xs)
  | p x       = (x:yes, no)
  | otherwise = (yes, x:no)
  where (yes, no) = partition p xs
```

In the functional language Futhark we too can express partition arguably not as
elegant as a in a general-purpose like Haskell. The advantage with Futhark is it
produces data-parallel executables. The approach to creating a partition in
Futhark is to compute predicate of every element and its negated value, this
tells us which elements we want to move to the first array and the second array.
Furthermore, if we convert `true` to `1` and `false` to `0` then computing two
inclusive prefix sum of these tupled integers (a scan with tuple-addition) then
we get the position of where true element elements belong and where false
elements belong. We have to do a slight change to the indices, if they should
not be written to the array we use the `-1` index to discard it and subtract one
from elements being written to get the index position of the element. Using
`scatter` we can give it an destination array, the indices of each element and
the elements. Lastly, we get how many elements are in the true elements array
from the last scan and then we truncate each array. Here we use a scratch
attribute to an array which have not yet been populated with date so it is
filled with junk, which is unsafe but we know how many and where we write
elements so `partition` ends up being perfectly safe.

```
def partition [n] 'a
              (p: a -> bool)
              (as: [n]a) : ?[k].([k]a, [n - k]a) =
  let to_index_t f (o, _) = if f then o - 1i64 else -1i64
  let to_index_f f (_, o) = if f then -1i64 else o - 1i64
  let add2 (a0, b0) (a1, b1) = (a0 + a1, b0 + b1)
  let t_flags = map p as
  let f_flags = map (\x -> !x) t_flags
  let flags =
    map2 (\x y ->
            ( i64.bool x
            , i64.bool y
            ))
         t_flags
         f_flags
  let offsets = scan add2 (0, 0) flags
  let t_idxs = map2 to_index_t t_flags offsets
  let f_idxs = map2 to_index_f t_flags offsets
  let t_dest = #[scratch] copy as
  let f_dest = #[scratch] copy as
  let t_res = scatter t_dest t_idxs as
  let f_res = scatter f_dest f_idxs as
  let (k, _) = if n == 0 then (0, 0) else last offsets
  in (take k t_res, take (n - k) f_res)
```

