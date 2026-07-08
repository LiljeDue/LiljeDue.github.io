In this blog post I will try to explain why the segmented scan monoids works. So
to start of with, what is a segmented scan? A segmented scan is like a scan but
it can be done on an irregular array encoded as a flat array. The encoding is
given as an array of elements and an array of flags of same size, where the
flags are booleans, true means the element is at the start of the subarray and
false meaning it is an continuation of an array.

```
[1, 2, 3, 4, 5, 6] = flatten([[1, 2, 3], [3, 4], [6]])
[t, f, f, t, f, t]
```

And if we now performed a segmented scan with addition we would get a result
like this:

```
[1, 3, 6, 4, 9, 6] = flatten([[1, 3, 6], [3, 9], [6]])
```

The ability to compute segmented scans is highly importantant for parallel
computing, it allows for the ability to express irregular problems as regular
onces. It is possible to express the segmented scan as a scan where you pair up
the the flags and elements. The way I would like to derive this segmented scan
is if we think about the second monoid composition described the previous blog
post. Then given non-commutative semiring $(A, +, \cdot, e_+, e_\cdot)$ then we
can compute the $i\text{th}$ of element of a scan feeding into a scan in a
single scan using the second monoid composition. 

$$
b_i + (b_{i - 1} \cdot a_{i}) + (b_{i - 2} \cdot a_{i - 1} \cdot a_i) +~\cdots~+ (b_1 \cdot a_2 \cdot~ \cdots~\cdot a_i)
$$

So we first are gonna define $a_k, b_k \in \mathbb{B} \times A$ where $a_k =
b_k$ to be elements paired with its flags. Now what we want for a segmented scan
is for $+$ to be an operation which selects largest $j \leq i$ such that
$\pi_1(a_j)$ is true. This would allow us to select a single scanned segmented
out of all of them to be the result of that segment up to this point.

$$
\begin{aligned}
&\text{if}~\pi_1(a_i)~\text{then}~a_i \\
&\text{else if}~\pi_1(a_{i - 1})~\text{then}~a_{i - 1} \odot a_{i} \\
&\text{else if}~\pi_1(a_{i - 2})~\text{then}~a_{i - 2} \odot a_{i - 1} \odot a_i \\
&\ldots \\
&\text{then}~ a_1 \odot a_2 \odot~ \cdots~\odot a_i
\end{aligned}
$$

We run into a problem here since we can not access a given $a_j$ value at the
given point in the scan. What we do have access to is actually the accumulated
value under the given $\odot$ operation so we could construct the following scan
feeding into a scan.

$$
\begin{aligned}
&\text{if}~\pi_1(a_i)~\text{then}~a_i \\
&\text{else if}~\pi_1(a_{i - 1} \odot a_{i})~\text{then}~a_{i - 1} \odot a_{i} \\
&\text{else if}~\pi_1(a_{i - 2} \odot a_{i - 1} \odot a_n)~\text{then}~a_{i - 2} \odot a_{i - 1} \odot a_i \\
&\ldots \\
&\text{then}~ a_1 \odot a_2 \odot~ \cdots~\odot a_i
\end{aligned}
$$

The wish we now has is that this from a semiring:



$$
(a_1 \odot a_2, \text{if}~\pi_1(b_2)~\text{then}~b_2~\text{else}~a_1 \odot b_2)
$$

$$
(a_1 \odot a_2, \text{if}~\pi_1(b_2)~\text{then}~b_2~\text{else}~a_1 \odot b_2)
$$

The big question is now what operation is $\odot$, it should compute the actual
scan and it should propagate the flag from $a_j$ all the way through to 
