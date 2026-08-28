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

In the language futhark we too can express 