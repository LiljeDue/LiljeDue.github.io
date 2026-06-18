I realized from my previous post that it is possible to use monoid composition
to turn an inclusive scan into an exclusive scan. I assume that the resulting
operation must somebody else have derived beforehand but this blog post uses the
first monoid composition rule and some rewriting insigt to derive it. The
initial idea is if we consider an arbitrary non-commutative semiring $(A, +,
\cdot, e_+, e_\cdot)$. Then if we compute the scan of a scan for the
$i\text{th}$ element in the array we would get:

$$
b_1 + (a_1 \cdot b_2) + (a_1 \cdot a_2 \cdot b_3) +~\cdots~+ (a_1 \cdot a_2 \cdot~ \cdots~\cdot b_i)
$$

Now if we let $b_j = e_+$ then we get the following result:

$$
e_+ + a_1 + (a_1 \cdot a_2) +~\cdots~+ (a_1 \cdot a_2 \cdot~ \cdots~\cdot a_{i - 1})
$$

If it is possible for us to just select the last sum to the right then we would
be able to compute the exclusive prefix sum of the $i\text{th}$ element:

$$
a_1 \cdot a_2 \cdot~ \cdots~\cdot a_{i - 1}
$$

There is an operation which always picks the right most element I will call take
right.

$$
a \oplus b = b
$$

This operation is associative:

$$
a \oplus (b \oplus c) = a \oplus c = c = b \oplus c = (a \oplus b) \oplus c
$$

It also supports distributivity for any operation, since applying the operation
to both elements and taking the right element is the same as taking the right
element and then applying the operation.

$$
\begin{aligned}
a \cdot (b \oplus c) = (a \cdot b) \oplus (a \cdot c) = a \cdot c \\
(b \oplus c) \cdot a = (b \cdot a) \oplus (c \cdot a) = c \cdot a \\
\end{aligned}
$$

Now the trouble is annihilation and having an identity element. But as discussed
in last blog post we really only need two semigroups which support
distributivity, then we can add some identity element afterwards. So for any
semigroup $(A, \cdot)$ we can define an associative operation:

$$
(a_1, b_1) \star (a_2, b_2) = (a_1 \cdot a_2, b_1 \oplus (a_1 \cdot b_2))
$$

We can implement this in Futhark by defining the take right operation and the
exlcusive operation construction:

```
def take_right 't (_: t) (a: t) : t = a

def exclusive_op 't (op: t -> t -> t) (a1: t, b1: t) (a2: t, b2: t) : (t, t) =
  (a1 `op` a2, take_right b1 (a1 `op` b2))
```

But we also need to add an identity element so we have a monoid that can be used
in Futharks scan.

```
type with_neutral 't =
    #neutral
  | #val t

def f_with_neutral 't (f: t -> t -> t)
                      (x: with_neutral t)
                      (y: with_neutral t)
                      : with_neutral t =
  match (x, y)
  case (#val x, #val y) -> #val (f x y)
  case (#neutral, _) -> y
  case (_, #neutral) -> x
```

Now all that remains is to map the incoming element such that we have $b_j$ is
the identity element $b_j = e_\cdot$. And the ability to retrieve the second
tuple component to get the exclusive scan in the end.

```
def gen 't (ne: t) (t: t) : with_neutral (t, t) =
  #val (t, ne)

def obs 't (ne: t) (t: with_neutral (t, t)) : t =
  match t
  case #neutral -> ne
  case (#val (_, r)) -> r
```

Now we can just combine every function to get our exclusive scan.

```
def exscan [n] 't (op: t -> t -> t) (ne: t) (xs: [n]t) : [n]t =
  map (gen ne) xs
  |> scan (f_with_neutral (exclusive_op op)) (#neutral :> with_neutral (t, t))
  |> map (obs ne)
```

Back in the day when Futhark did not have [scan-scatter
fusion](https://futhark-lang.org/blog/2026-03-24-scan-scatter-fusion.html) this
would had been very nice. The problem was futhark did not fuse scan and scatter
together so you may not have different problems with fusion depending on the
exlcusive scan implementation. The current exclusive scan implementation does
allow for the ability to fuse maps before or after the scan:

```
def exscan [n] 'a (op: a -> a -> a) (ne: a) (as: [n]a) : *[n]a =
  scatter (replicate n ne)
          (map (+ 1) (0..1..<n))
          (scan op ne as)
```

But you can not feed the exclusive scan result directly into a scatter. So using
this exclusive scan we have derived it can lead to better fusion. But as it
stand currently it will be a 3-tuple in the futhark compiler and may be slower.
Luckily I have a very smart PhD advisor by the name of [Troels
Henriksen](https://hjemmesider.diku.dk/~athas/) which I showed my work to. He
came with suggestions to make the code simpler. The first realization is in
regards to the $\star$ operation.

$$
(a_1, b_1) \star (a_2, b_2) := (a_1 \cdot a_2, b_1 \oplus (a_1 \cdot b_2))
$$

We can simplify the $\oplus$ operation away by definition:

$$
(a_1, b_1) \star (a_2, b_2) := (a_1 \cdot a_2, a_1 \cdot b_2)
$$

The second observation is the first tuple component computes the inclusive scan,
and the second component computes the exclusive scan leading to a scan which
computes both at the same time:

```
def lift_op 't (op: t -> t -> t) (ne: t) (a1: t, _:  t) (a2: t, b2: t) : (t, t) =
  (a1 `op` a2,  a1 `op` b2)

def obs 't (ne: t) (t: with_neutral (t, t)) : (t, t) =
  match t
  case #neutral -> (ne, ne)
  case (#val r) -> r

def incexscan [n] 't (eq: t -> t -> bool) (op: t -> t -> t) (ne: t) (xs: [n]t) : [n](t, t) =
  map (gen ne) xs
  |> scan (f_with_neutral (exclusive_op op)) (#neutral :> with_neutral (t, t))
  |> map (obs ne)
```

We originally had another idea to avoid the sum type which turned out to not
work. Instead you may pick an element you know will not appear in the input
sequence and let a tuple of that be a neutral element.

My advisor also came up with an idea for a use case, where I believe it would be
very useful, I need it for my parallel-parser generator
[Alpacc](https://github.com/diku-dk/alpacc). But the explanation of this is
beyond the scope of the post.
