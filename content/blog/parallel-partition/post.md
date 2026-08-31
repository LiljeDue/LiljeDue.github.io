Partition is an operation which splits a container into two containers where if
elements satisfy the predicate they get moved to the first and if they do not
they get moved to the other container. Implementing it efficiently on a GPU
requires more thought than one might expect, and there is no single best
implementation. Each comes with different trade-offs in memory usage, element
ordering, and flexibility. This post walks through several implementations in
Futhark, a data-parallel functional language that compiles to GPU code.

If we consider how partition is implemented in the language Haskell, here the
first-class container is lists and you would implement it using recursion where
you first recursively call partition and then prepend the element to either list
depending on if it satisfies the predicate or not.

```
partition :: (a -> Bool) -> [a] -> ([a], [a])
partition _ [] = ([], [])
partition p (x:xs)
  | p x       = (x:yes, no)
  | otherwise = (yes, x:no)
  where (yes, no) = partition p xs
```

In the functional language Futhark we too can express partition arguably not as
elegant as in a general-purpose language like Haskell. The advantage with
Futhark is it produces data-parallel executables. The approach to creating a
partition in Futhark is to compute the predicate of every element and its
negated value, this tells us which elements we want to move to the first array
and the second array. Furthermore, if we convert `true` to `1` and `false` to
`0` then computing two inclusive prefix sums of these tupled integers (a scan
with tuple-addition) then we get the position of where true elements belong and
where false elements belong. We have to do a slight change to the indices, if
they should not be written to the array we use the `-1` index to discard it and
subtract one from elements being written to get the index position of the
element. Using `scatter` we can give it a destination array, the indices of each
element and the elements. Lastly, we get how many elements are in the true
elements array from the last scan and then we truncate each array. Here we use a
scratch attribute to an array which have not yet been populated with data so it
is filled with junk, which is unsafe but we know how many and where we write
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

This is an okay implementation in Futhark, it produces a single kernel but it
does have the mistake which is it will write all offsets to global memory. The
reason for this is Futhark does not have an optimization for when just taking
the last element of an array like `offsets`. Because Futhark cannot fuse away
the scan when only the last element is used, we must extract it explicitly with
a scatter to avoid writing the full offsets array to global memory.

```
  ...
  let lst =
    scatter [(0, 0)]
            (map (\i -> if i != n - 1 then -1 else 0) (iota n))
            offsets
  let (k, _) = lst[0]
  ...
```

Another variant is to have the caller pass in the destination arrays, with the
constraint that they are both of size `n`. We can then also pass two functions
to map each element to a different type.

```
def partition [n] 'a 'b 'c
              (t_dest: *[n]b)
              (f_dest: *[n]c)
              (g: a -> b)
              (h: a -> c)
              (p: a -> bool)
              (as: [n]a) : ([n]a, [n]a) =
  ...
```

The rationale behind this is when we truncate the array in the previous design
then we are no longer able to map the elements of the array and have it fused
away into the scatter that puts the elements in their correct position. So in
the new design we must map the function over each element of the array before
scattering it, where we sometimes use the scratch attribute to avoid the
computation.

```
  ...
  let t_res =
    scatter t_dest
            t_idxs
            (map2 (\f a -> if f then g a else #[scratch] g a)
                  t_flags
                  as)
  let f_res =
    scatter f_dest
            f_idxs
            (map2 (\f a -> if f then #[scratch] h a else h a)
                  t_flags
                  as)
  ...
  in (t_res, f_res)
```

Using this partition is awkwardly expressed but it is nice that you get the
ability to permute into different arrays and map the elements before they get
put in their correct position while the partition is a single kernel. This makes
it well suited for cases where you want to simultaneously partition and
transform elements into a different type in a single pass.

However, both of these designs allocate `2n` elements for the destination
arrays, when ideally we only need `n`. The caveat here is this constraint does
make it so we cannot map the partitioned value to different types before writing
them at their destination. But with this added constraint we can reduce the
memory usage by writing true elements to the start of a single destination array
and false elements to the end, letting them meet in the middle.

```
  ...
  let to_index f (o0, o1) = if f then o0 - 1i64 else n - o1
  ...
```

At the end we get an implementation of partition like so:

```
def partition [n] 'a
              (p: a -> bool)
              (as: [n]a) : ?[k].([k]a, [n - k]a) =
  let to_index f (o0, o1) = if f then o0 - 1i64 else n - o1
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
  let idxs = map2 to_index t_flags offsets
  let dest = #[scratch] copy as
  let res = scatter dest idxs as
  let lst =
    scatter [(0, 0)]
            (map (\i -> if i != n - 1 then -1 else 0) (iota n))
            offsets
  let (k, _) = lst[0]
  in (take k res, drop k res)
```

It is nice implementation in the sense that we only read the input once and
write it once, and it is a streamable implementation so we do not need to know
the full input from the beginning, we would just need to know the size of it.
This is the same implementation (structurally) that is used in CUB, a library by
NVIDIA with highly optimized GPU primitives written in CUDA. A problem with this
implementation is that you do not get the false elements in the relative order,
you get them in reverse relative order. This is still a valid partition, you do
get the elements split up in true and false elements but they end up being
unordered. One might expect that an unordered partition is less usefule, but we
can work around the reversed false elements with an auxiliary function
`unreverse`. This ends up being a good trade in certain cases since it only adds
a cheap index transformation, while the underlying partition benefits from fewer
memory accesses. We can simply create a auxiliary function which reads all
elements in correct order till we get to false elements then and read from the
array in reverse.

```
def unreverse [n] 't
              (m: i64)
              (xs: [n]t) : [n]t =
  let is = tabulate n (\i -> if i < m then i else n - 1 - i + m)
  in map (\i -> xs[i]) is

```

This `unreverse` together with the unordered `partition` can be used for use
cases that typically require an ordered partition, such as radix sort. We can
start by defining the computation of a single step.

```
def radix_sort_step [n] 't
                    (m: i64)
                    (xs: [n]t)
                    (get_bit: i32 -> t -> i32)
                    (digit_n: i32) : (i64, [n]t) =
  let (zeros, ones) = partition (\x -> get_bit digit_n x == 0) (unreverse m xs)
  in (length zeros, zeros ++ ones :> [n]t)
```

We then loop over the number of bits, but we have to keep in mind that at the
end still some elements are in reverse relative order so we have to unreverse
these elements.

```
def radix_sort [n] 't
               (num_bits: i32)
               (get_bit: i32 -> t -> i32)
               (xs: [n]t) : [n]t =
  let m = n
  let (m, xs) =
    loop (m, xs) for i < num_bits do
      radix_sort_step m xs get_bit i
  in unreverse m xs
```

This `partition` does seem worth it if you have multiple partitions in a loop or
do not care about order. But if you care about order and do not do many
partitions or you just find unreversing of elements tedious then there is a way
around it. You can create a single kernel partition which does `3n` reads and
writes and gives you the elements in relative order. The idea is that if we scan
the false elements in reverse, their offsets count down from the end of the
destination array. This means the false element that belongs last gets written
to the last position, and so on, giving us false elements in correct relative
order. The cost is that we must read the input twice, once forward for true
elements and once in reverse for false elements. The implementation ends up
being a bit annoying and is found in Futhark's prelude.

```
def partition [n] 'a
              (p: a -> bool)
              (as: [n]a) : ?[k].([k]a, [n - k]a) =
  let to_index_t f (o0, _o1) = if f then o0 - 1 else -1
  let to_index_f f (_o0, o1) = if f then n - o1 else -1
  let add2 (a0, b0) (a1, b1) = (a0 + a1, b0 + b1)
  let t_flags = map p as
  let rev_as = reverse as
  let f_flags = map (\x -> !x) (map p rev_as)
  let flags =
    map2 (\x y ->
            ( i64.bool x
            , i64.bool y
            ))
         t_flags
         f_flags
  let offsets = scan add2 (0, 0) flags
  let idxs_t = map2 to_index_t t_flags offsets
  let idxs_f = map2 to_index_f f_flags offsets
  let idxs = idxs_t ++ idxs_f
  let dest = #[scratch] copy as
  let res = scatter dest idxs (as ++ rev_as)
  let lst =
    scatter [(0, 0)]
            (map (\j -> if j == n - 1 then 0 else -1) (0..1..<n))
            offsets
  let (k, _) = lst[0]
  in (take k res, drop k res)
```

This approach is quite nice, I do not think you can avoid `3n` reads and writes
for an ordered partition where you do not overallocate. Since a problem you run
into is you have to know somehow where the elements must be separated in the
destination array. So if you were to only read from one side of the input array
you are left with the problem that you do not know how many true elements there
are. So another approach to this could also just be to go all the way back to
the partition which uses two different destination arrays. Here you could
compute how many true elements there are using a reduce and then use this as an
offset for an ordered partition. This would still give `3n` reads and writes but
two kernels instead. Maybe this approach might still be useful since the reduce
could get fused with something else in a bigger program.

In summary, the right partition depends on your needs. The single-array
unordered version is the most memory-efficient, doing only `n` reads and writes,
and is a good fit when order does not matter or can be corrected cheaply with
`unreverse`. When order is required, the `3n` single-kernel version avoids the
reversal problem at the cost of reading the input twice. The
two-destination-array version is the most general, allowing you to map elements
to different types in a single kernel, at the cost of allocating `2n` elements.