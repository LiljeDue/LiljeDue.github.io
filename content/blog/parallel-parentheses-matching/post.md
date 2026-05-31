A professor at the PLTC section by the name of [Martin
Elsman](https://elsman.com/) introduced me to a paper called [More Fun with
Monoids](https://link.springer.com/chapter/10.1007/978-981-92-0184-6_7) by [Oleg
Kiselyov](https://okmij.org/ftp/) (There is also [blog
post](https://okmij.org/ftp/Algorithms/map-monoid-reduce.html)). Because of this
paper I looked into what other problems can be expressed as a
[map-reduce](https://en.wikipedia.org/wiki/MapReduce) pattern. Apparently
asserting that a string of parentheses is balanced, it has it downsides (which
we will get to) but this is not the only parallel manner of matching parentheses
so therefore, I decided to write a short blog about these methods. Now to start
off let us define what the parentheses matching problem is.

## Parallel Parentheses Matching (Single)
To start off we will discuss a smaller instance of the problem which is given a
single type of parentheses which has its open and closed forms '(' and ')'
determine if a string of parentheses is balanced. Meaning for all opening
parenthesis, there must exist a unique closing parenthesis with a strictly
larger index, and every closing parenthesis must match exactly one opening
parenthesis (i.e., no closing parenthesis is unmatched).

This can be solved sequentially using a stack, here every time you run into an
opening parenthesis you put it on top of the stack and everytime you run into a
closing parenthesis you pop the stack. If this is not possible then the
parentheses are not matching or if the stack is not empty at the end. This can
very easily be implemented in a language like Haskell.
```hs
parenthesesMatches :: [Char] -> Bool
parenthesesMatches = go []
  where
    go []     []         = True
    go (_:_)  []         = False
    go stack ('(':cs)    = go ('(':stack) cs
    go []    (')':_)     = False
    go ('(':ss) (')':cs) = go ss cs
    go stack (_:cs)      = undefined
```
To parallize this we can utilize the fact that we only have a single type of
parenthesis pair. This fact is helpful since we can instead just think about how
the size if the stack change during evaluation. We see that the stack initially
has a size of zero and increments on opening parenthesis and decrements on
closing parenthesis. And when trying to pop an element from the empty stack then
the parentheses do not match or the stack is not zero at the end.
```
   [(, ), (, (, (, ), (, ), ), )] = "()((()()))"
[0, 1, 0, 1, 2, 3, 2, 3, 2, 1, 0]
```
This is a good insight because it allows us to express the problem in a
data-parallel manner. The parenthesis can each be mapped in parallel to either 1
or -1. This map can be fused in to a parallel prefix sum to determine the stack
size at each state. If the last value of the scan is zero then we know that
there is atleast the correct amount of parenthesis. But we also have to compute
a reduction of the prefix sum to check if any of the values a negative, which
would mean the scan size had gone in negative and therefore the parenthesis do
not match.
```fut
def parentheses_matches [n] (str: [n]u8): bool =
  -- Assuming input is well-formed.
  let prefix_sum =
    map (\c -> if c == '(' then 1 else -1))
    |> scan (+) 0
  let min = reduce i64.min i64.highest prefix_sum
  in n == 0 || (prefix_sum[n - 1] = 0 && 0 <= min)
```
The code above produces two kernels using the CUDA backend so it would be nice
if we could express it as a single reduce. What we deduce is we compute two
values from the same input, the total sum and the minimum value of the prefix
sum. A possible idea you will have to turn the algorithm into a single monoid is
to compute the minimum of the predecessor and the current minimum sum. You may
initially come up with the following.
$$
(v_0, m_0) \oplus (v_1,m_1) = (v_0 + v_1, \min~\{m_0, v_0 + m_1\}) \\
$$

Where we use an extended set of the integers with a largest value $\infty = a +
\infty$ to get a neutral element $(0, \infty)$. This does end up forming a
monoid meaning it is possible to perform a reduce but when implementing it we
have to account for that signed 64-bit integer does not have such a value. The
closest is the largest signed 64-bit value but it would cause overflow.
Therefore, we modify the operator to account for this problem to get the
following algorithm.
```fut
def op (v0: i64, m0: i64) (v1: i64, m1: i64): (i64, i64) =
  (v0 + v1, if m1 == i64.highest then m0 else i64.min m0 (v0 + m1))

def ne: (i64, i64) = (0, i64.highest)

def parentheses_matches [n] (str: [n]u8): bool =
  -- Assuming input is well-formed.
  let (sum, min) =
    map (\c -> if c == '(' then (1, 1) else (-1, -1)) str
    |> reduce op ne
  in sum = 0 && 0 <= min
```
