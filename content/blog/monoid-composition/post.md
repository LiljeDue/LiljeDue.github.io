In my previous post I talked about parallel parentheses matching and how it
could be done using different methods. One of these methods could be done as a
single monoid for a single type of parenthesis. The investigation into this
problem was inspired by a [monoid composition
library](https://github.com/diku-dk/monoidal) that [Martin
Elsman](https://elsman.com/) is working on. I decided to look more into the
parentheses matching monoid to generalize it and explore its usefulness, and in
this blog post I will discuss this.

If we look back at the parentheses matching monoid then it was defined by the
following operation.

$$
(v_0, m_0) \star (v_1,m_1) := (v_0 + v_1, \min~\lbrace m_0, v_0 + m_1\rbrace)
$$

Defined on the extended integers $\overline{\mathbb{Z}} := \mathbb{Z} \cup
\lbrace \infty \rbrace$ with the identity element $(0, \infty)$. What this
monoid is able to compute is a sum and the minimum of the prefix sum. So this is
a case of computing a reduction and a prefix sum in a single reduction.

$$
\max~\lbrace a_1, (a_1 + a_2), (a_1 + a_2 + a_3), \ldots, a_1 + a_2 +~ \cdots~+ a_n \rbrace
$$

The question I had is whether this generalizes, and it generalizes to two
composition rules which seem useful. We will start by abstracting over the
monoids $(\overline{\mathbb{Z}}, +, 0)$ and $(\overline{\mathbb{Z}}, \min,
\infty)$ to arbitrary ones and see what properties are needed to derive the
composed monoid $(\overline{\mathbb{Z}}^2, \star, (0, \infty))$. Through
exploring this subject I realized that the key to seeing whether two monoids can be
composed is related to whether they form a non-commutative semiring. So we need
$(A, +, e_{+})$ and $(A, \cdot, e_{\cdot})$ to be monoids such that they form a
non-commutative semiring, meaning we have the extra property that $\cdot$ can be
distributed over a $+$ operation:

$$
a \cdot (b + c) = a \cdot b + a \cdot c \\
(b + c) \cdot a  = b \cdot a + c \cdot a
$$

Furthermore, we also have the annihilation property:

$$
a \cdot e_+ = e_+ \\
e_+ \cdot a = e_+
$$

We can see that the summation and minimum monoids make up a non-commutative
semiring. It fulfills distributivity $a + \min~\lbrace b, c \rbrace =
\min~\lbrace a + b, a + c \rbrace$ and it fulfills annihilation $a + \infty =
\infty$. Now we wish to show that this hypothesis holds true: that given a
non-commutative semiring, we can construct a composed monoid which computes the
first monoid followed by another monoid.

## Monoid Composition
Let $(A, +, e_+)$ and, $(A, \cdot, e_\cdot)$ be monoids that form
non-commutative semiring $(A, +, \cdot, e_+, e_\cdot)$. From this we define the
following operation.

$$
(a_1, b_1) \star (a_2, b_2) := (a_1 \cdot a_2, b_1 + (a_1 \cdot b_2))
$$

We wish to show that $(A^2, \star, (e_\cdot, e_+))$ forms a monoid, so now we
will start by showing that $(e_\cdot, e_+)$ is an identity element. We do so by
showing it is a left-identity element:

$$
\begin{aligned}
(e_\cdot, e_+) \star (a, b) &= (e_\cdot \cdot a, e_+ + (e_\cdot \cdot b)) \quad& \text{(definition of }\star\text{)} \\
&= (a, b) \quad& \text{(identity)}
\end{aligned}
$$

Next we must show that it is also a right-identity element:

$$
\begin{aligned}
(a, b) \star (e_\cdot, e_+) &= (a \cdot e_\cdot, b + (a \cdot e_+)) \quad& \text{(definition of }\star\text{)} \\
&= (a, b) \quad& \text{(identity and annihilation)}
\end{aligned}
$$

Now lastly we must show that the operation we have is associative:

$$
(a_1, b_1) \star ((a_2, b_2) \star (a_3, b_3)) = ((a_1, b_1) \star (a_2, b_2)) \star (a_3, b_3)
$$

This can be shown by first expanding the definition of the left-hand side and
using properties given:

$$
\begin{aligned}
(a_1, b_1) \star \big((a_2, b_2) \star (a_3, b_3)\big) &= (a_1, b_1) \star \big( (a_2 \cdot a_3, b_2 + (a_2 \cdot b_3)) \big)
\quad& \text{(definition of }\star\text{)} \\

&= \Big(a_1 \cdot (a_2 \cdot a_3),
 b_1 + \big(a_1 \cdot (b_2 + (a_2 \cdot b_3))\big)\Big)
\quad& \text{(definition of }\star\text{)} \\

&= \Big((a_1 \cdot a_2) \cdot a_3,
 b_1 + \big((a_1 \cdot b_2) + (a_1 \cdot (a_2 \cdot b_3))\big)\Big) \quad & \text{(distributivity)} \\

&= \Big(a_1 \cdot a_2 \cdot a_3,
 b_1 + (a_1 \cdot b_2) + (a_1 \cdot a_2 \cdot b_3)\Big)
\quad& \text{(associativity of } \cdot \text{and} + \text{)}
\end{aligned}
$$

Lastly, we must show the right-hand side is equal to the left-handside:

$$
\begin{aligned}
\big((a_1, b_1) \star (a_2, b_2)\big) \star (a_3, b_3) &= \big((a_1 \cdot a_2, b_1 + (a_1 \cdot b_2))\big) \star (a_3, b_3)
\quad& \text{(definition of }\star\text{)} \\

&= \Big((a_1 \cdot a_2) \cdot a_3,
 (b_1 + (a_1 \cdot b_2)) + ((a_1 \cdot a_2) \cdot b_3)\Big)
\quad& \text{(definition of }\star\text{)} \\

&= \Big(a_1 \cdot a_2 \cdot a_3,
 b_1 + (a_1 \cdot b_2) + (a_1 \cdot a_2 \cdot b_3)\Big)
\quad& \text{(associativity of } \cdot \text{and} + \text{)}
\end{aligned}
$$

Hence we have shown that $(A^2, \star, (e_\cdot, e_+))$ is a monoid.

Now some observations: we can clearly see on the last line of the left- and
right-hand sides of the associativity derivations that if we pick $a_i = b_i$
then we get a monoid composed with a monoid. Furthermore, we see that if instead
we were given two semigroups (i.e. monoids without an identity element), then we
would only need the distributive property and two associative operations to
construct a composed semigroup. This is useful when programming, as you can just
add an identity element afterwards if you do not have all the properties or an
identity element is missing. We saw in the last blog post that the monoid
composition of the summation and minimum monoid can be used to assert whether
parentheses match. It can also be used for evaluating polynomials; this is the
same approach as found in [Oleg
Kiselyov](https://okmij.org/ftp/Algorithms/map-monoid-reduce.html)'s work. If we
pick the semiring $(\mathbb{R}, +, \cdot, e_+, e_\cdot)$ and consider the
reduction of a prefix sum for arbitrary elements.

$$
b_1 + (a_1 \cdot b_2) + (a_1 \cdot a_2 \cdot b_3) +~\cdots~+ (a_1 \cdot a_2 \cdot~ \cdots~\cdot b_n)
$$

If we pick $b_i$ to be the coefficients of a polynomial and pick $a_i = x$ to be
the variables then we can make the following derivation:

$$
\begin{aligned}
b_1 + (a_1 \cdot b_2) + (a_1 \cdot a_2 \cdot b_3) +~\cdots~+ (a_1 \cdot a_2 \cdot~ \cdots~\cdot b_n) &= \sum_{i = 1}^n \left(\prod_{j = 1}^{i - 1} a_j \right) b_i \\
&= \sum_{i = 1}^n \left(\prod_{j = 1}^{i - 1} x \right) b_i \\
&= \sum_{i = 1}^n b_i x^{i - 1}
\end{aligned}
$$

Now this is not the only way to compose two monoids; it is possible to compose
them such that you get a reduction of a suffix sum instead.

$$
b_n + (b_{n - 1} \cdot a_{n}) + (b_{n - 2} \cdot a_{n - 1} \cdot a_n) +~\cdots~+ (b_1 \cdot a_2 \cdot~ \cdots~\cdot a_n)
$$

Now it will be shown that it is possible to construct a reduction of a suffix
sum given a non-commutative semiring. I will do this for completeness' sake.

## Reverse Monoid Composition
Let $(A, +, e_+)$ and, $(A, \cdot, e_\cdot)$ be monoids that form
non-commutative semiring $(A, +, \cdot, e_+, e_\cdot)$. From this we define the
following operation.

$$
(a_1, b_1) \diamond (a_2, b_2) := (a_1 \cdot a_2, b_2 + (b_1 \cdot  a_2))
$$

We wish to show that $(A^2, \diamond, (e_\cdot, e_+))$ forms a monoid, so now we
will start by showing that $(e_\cdot, e_+)$ is an identity element. We do so by
showing it is a left-identity element:

$$
\begin{aligned}
(e_\cdot, e_+) \diamond (a, b) &= (e_\cdot \cdot a, b + (e_+ \cdot  a)) \quad& \text{(definition of }\diamond\text{)} \\
&= (a, b) \quad& \text{(identity and annihilation)}
\end{aligned}
$$

Next we must show that it is also a right-identity element:

$$
\begin{aligned}
(a, b) \diamond (e_\cdot, e_+) &= (a \cdot e_\cdot, e_+ + (b \cdot e_\cdot)) \quad& \text{(definition of }\diamond\text{)} \\
&= (a, b) \quad& \text{(identity)}
\end{aligned}
$$

Now lastly we must show that the operation we have is associative:

$$
(a_1, b_1) \diamond ((a_2, b_2) \diamond (a_3, b_3)) = ((a_1, b_1) \diamond (a_2, b_2)) \diamond (a_3, b_3)
$$

This can be shown by first expanding the definition of the left-hand side and
using properties given:

$$
\begin{aligned}
(a_1, b_1) \diamond \big((a_2, b_2) \diamond (a_3, b_3)\big) &= (a_1, b_1) \diamond \big( (a_2 \cdot a_3, b_3 + (b_2 \cdot a_3)) \big) \quad& \text{(definition of }\diamond\text{)} \\

&= \Big(a_1 \cdot (a_2 \cdot a_3), (b_3 + (b_2 \cdot a_3)) + (b_1 \cdot (a_2 \cdot a_3))\Big) \quad& \text{(definition of }\diamond\text{)} \\

&= \Big(a_1 \cdot a_2 \cdot a_3, b_3 + (b_2 \cdot a_3) + (b_1 \cdot a_2 \cdot a_3)\Big) \quad& \text{(associativity of } \cdot \text{ and } +\text{)}
\end{aligned}
$$

Lastly, we must show the right-hand side is equal to the left-handside:

$$
\begin{aligned}
\big((a_1, b_1) \diamond (a_2, b_2)\big) \diamond (a_3, b_3) &= \big((a_1 \cdot a_2, b_2 + (b_1 \cdot a_2))\big) \diamond (a_3, b_3) \quad& \text{(definition of }\diamond\text{)} \\

&= \Big((a_1 \cdot a_2) \cdot a_3, b_3 + \big((b_2 + (b_1 \cdot a_2)) \cdot a_3\big)\Big) \quad& \text{(definition of }\diamond\text{)} \\

&= \Big((a_1 \cdot a_2) \cdot a_3, b_3 + (b_2 \cdot a_3) + ((b_1 \cdot a_2) \cdot a_3)\Big) \quad& \text{(distributivity)} \\

&= \Big(a_1 \cdot a_2 \cdot a_3, b_3 + (b_2 \cdot a_3) + (b_1 \cdot a_2 \cdot a_3)\Big) \quad& \text{(associativity of } \cdot \text{ and } +\text{)}
\end{aligned}
$$

Hence we have shown that $(A^2, \diamond, (e_\cdot, e_+))$ is a monoid.

Now here comes the question: what is the use case? Well, both of these
compositions appear when solving the maximum subarray sum problem.

## Maximum Subarray Sum Problem
If we consider the following semiring $(\overline{\mathbb{Z}}, \max, +, -\infty,
0)$, where we extend the integers with a smallest element $\overline{\mathbb{Z}}
:= \mathbb{Z} \cup \lbrace -\infty \rbrace$. Then we can compute the maximum
prefix sum and maximum suffix sum using the two monoids composition rules that
have been described which forms $\left(\overline{\mathbb{Z}}^2, \star, (0,
-\infty)\right)$ and $\left(\overline{\mathbb{Z}}^2, \diamond, (0,
-\infty)\right)$. These monoids can be combined using the monoid product
allowing for the ability to compute both the maximum prefix sum and maximum
suffix sum.

$$
(a_1, b_1) \times (a_2, b_2) := (a_1 \star a_2, b_1 \diamond b_2)
$$

The resulting monoid is $\left(\left(\overline{\mathbb{Z}}^2\right)^2, \times,
((-\infty, 0), (-\infty, 0)) \right)$ but it can be simplified to avoid nested
tuples and to only compute the sum once.

$$
(a_1, b_1, c_1) \oplus (a_2, b_2, c_2) := (a_1 + a_2, \max~\lbrace b_1, a_1 + b_2 \rbrace, \max~\lbrace c_2, c_1 + a_2 \rbrace)
$$

Now a single component is missing from this operation to compute the maximum
subarray sum. We extend the 3-tuple to a 4-tuple with a component which is the
maximum subarray sum of the subarray the tuple corresponds to. Here we have
three cases: either the left or right tuple has the maximum subarray sum or
combining the two subarrays gives the maximum subarray sum. The first two cases
are easy, but the third one is a little harder and is the reason why we compute
the maximum prefix sum and maximum suffix sum. We can simply add these together
to see if combining the subarrays gives a new maximum subarray sum.

$$
(a_1, b_1, c_1, d_1) \odot (a_2, b_2, c_2, d_2) := (a_1 + a_2, \max~\lbrace b_1, a_1 + b_2 \rbrace, \max~\lbrace c_2, c_1 + a_2 \rbrace, \max~\lbrace d_1, d_2, c_1 + b_2 \rbrace)
$$

The question is now whether this operation actually forms a monoid, it is fairly
easy to see the identity element is $(0, -\infty, -\infty, -\infty)$. It remains
to show that the operation is associative:

$$
(a_1, b_1, c_1, d_1) \odot ((a_2, b_2, c_2, d_2) \odot (a_3, b_3, c_3, d_3)) = ((a_1, b_1, c_1, d_1) \odot (a_2, b_2, c_2, d_2)) \odot (a_3, b_3, c_3, d_3)
$$

Luckily we only have to inspect the fourth component, we can start inspecting
the result in the inner parenthesis in the left-hand side of the equation.

$$
\begin{aligned}
\pi_4((a_2, b_2, c_2, d_2) \odot (a_3, b_3, c_3, d_3)) &= \max~\lbrace d_2, d_3, c_2 + b_3 \rbrace \quad& \text{(definition of } \odot \text{)} \\
\pi_2((a_2, b_2, c_2, d_2) \odot (a_3, b_3, c_3, d_3)) &= \max~\lbrace b_2, a_2 + b_3 \rbrace \quad& \text{(definition of } \odot \text{)}
\end{aligned}
$$

Now we just have to substitute these values into the outer parentheses, then simplify.

$$
\begin{aligned}
\pi_4((a_1, b_1, c_1, d_1) \odot ((a_2, b_2, c_2, d_2) \odot
(a_3, b_3, c_3, d_3))) &= \max~\lbrace d_1, \max~\lbrace d_2, d_3, c_2 + b_3
\rbrace, c_1 + \max~\lbrace b_2, a_2 + b_3 \rbrace \rbrace \quad&
\text{(definition of } \odot \text{)} \\
&= \max~\lbrace d_1, \max~\lbrace d_2, d_3, c_2 + b_3 \rbrace, \max~\lbrace c_1 + b_2, c_1 + a_2 + b_3 \rbrace \rbrace \quad& \text{(distributivity)} \\
&= \max~\lbrace d_1, d_2, d_3, c_2 + b_3 ,c_1 + b_2, c_1 + a_2 + b_3 \rbrace \quad& \text{(associativity of } \max \text{)}
\end{aligned}
$$

Now once again we find the result of the inner parenthesis, but now for the
right-hand side.

$$
\begin{aligned}
\pi_4((a_1, b_1, c_1, d_1) \odot (a_2, b_2, c_2, d_2)) &= \max~\lbrace d_1, d_2, c_1 + b_2 \rbrace \quad& \text{(definition of } \odot \text{)} \\
\pi_3((a_1, b_1, c_1, d_1) \odot (a_2, b_2, c_2, d_2)) &= \max~\lbrace c_2, c_1 + a_2 \rbrace \quad& \text{(definition of } \odot \text{)}
\end{aligned}
$$

Lastly, we just have to substitute the result in.

$$
\begin{aligned}
\pi_4(((a_1, b_1, c_1, d_1) \odot (a_2, b_2, c_2, d_2)) \odot (a_3, b_3, c_3, d_3)) &= \max~\lbrace \max~\lbrace d_1, d_2, c_1 + b_2 \rbrace, d_3, \max~\lbrace c_2, c_1 + a_2 \rbrace + b_3 \rbrace \quad& \text{(definition of } \odot \text{)} \\
&= \max~\lbrace \max~\lbrace d_1, d_2, c_1 + b_2 \rbrace, d_3, \max~\lbrace c_2 + b_3, c_1 + a_2 + b_3 \rbrace\rbrace \quad& \text{(distributivity)} \\
&= \max~\lbrace d_1, d_2, c_1 + b_2, d_3, c_2 + b_3, c_1 + a_2 + b_3 \rbrace \quad& \text{(associativity of } \max \text{)} \\
&= \max~\lbrace d_1, d_2, d_3, c_2 + b_3, c_1 + b_2, c_1 + a_2 + b_3 \rbrace \quad& \text{(commutativity of } \max \text{)}
\end{aligned}
$$

And we see that the operation is associative.

What we see is that the monoid composition seems useful and appears in quite a
few places. It also seems to be a good combinator for constructing new monoids
from monoids. Sadly, I had no deeper insight into how the last part of the
maximum subarray sum monoid comes to light, but hopefully the explanation still
helps give an insight into why the monoid actually works.