A professor at the PLTC section by the name of [Martin
Elsman](https://elsman.com/) introduced me to a paper called [More Fun with
Monoids](https://link.springer.com/chapter/10.1007/978-981-92-0184-6_7) by [Oleg
Kiselyov](https://okmij.org/ftp/) (There is also [blog
post](https://okmij.org/ftp/Algorithms/map-monoid-reduce.html)). Because of this
paper, I looked into what other problems can be expressed as a
[map-reduce](https://en.wikipedia.org/wiki/MapReduce) pattern. Apparently
asserting that a string of parentheses is balanced can be done in this manner,
it has it downsides (which we will get to), but this is not the parallel
algorithm for parentheses matching. Therefore, I decided to write a short blog
post about these methods. Now, to start off, let us define what the parentheses
matching problem is.

To start off, we will discuss a smaller instance of the problem, which is given
a single type of parentheses that has its open and closed forms '(' and ')',
determine if a string of parentheses is balanced. Meaning that for all opening
parentheses, there must exist a unique closing parenthesis with a strictly
larger index, and every closing parenthesis must match exactly one opening
parenthesis (i.e., no closing parenthesis is unmatched).

This can be solved sequentially using a stack. Here, every time you run into an
opening parenthesis, you put it on top of the stack, and every time you run into
a closing parenthesis, you pop the stack. If this is not possible, then the
parentheses are not matching, or if the stack is not empty at the end. This can
very easily be implemented in a language like Haskell.

```
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

Now, this algorithm solves the problem with $O(n)$ work and $O(n)$ span. To
parallelize this, we can utilize the fact that we only have a single type of
parenthesis pair. This fact is helpful since we can instead just think about how
the size of the stack changes during evaluation. We see that the stack initially
has a size of zero and increments on opening parentheses and decrements on
closing parentheses. When trying to pop an element from an empty stack, the
parentheses do not match, or the stack is not zero at the end.

```
   [(, ), (, (, (, ), (, ), ), )] = "()((()()))"
[0, 1, 0, 1, 2, 3, 2, 3, 2, 1, 0] (Stack sizes)
```

This is a good insight because it allows us to express the problem in a
data-parallel manner in Futhark. The parentheses can each be mapped in parallel
to either 1 or -1. This map can be fused into a parallel prefix sum to determine
the stack size at each state. If the last value of the scan is zero, then we
know that there are at least the correct number of parentheses. But we also have
to compute a reduction of the prefix sum to check if any of the values are
negative, which would mean the scan has gone negative, and therefore the
parentheses do not match.

```
def parentheses_matches [n] (str: [n]u8): bool =
  let prefix_sum =
    map (\c -> if c == '(' then 1 else -1)) str
    |> scan (+) 0
  let min = reduce i64.min i64.highest prefix_sum
  in n == 0 || (prefix_sum[n - 1] == 0 && 0 <= min)
```

This code solves the problem with $O(n)$ work and $O(\log n)$ span, but it
produces two kernels using the CUDA backend. This leads to approximately $17n$
bytes being read or written, so it would be nice if we could express it as a
single reduce. What we deduce is that we compute two values from the same input:
the total sum and the minimum value of the prefix sum. A possible idea to turn
the algorithm into a single monoid is to compute the minimum of the predecessor
and the current minimum sum. You may initially come up with the following:

$$ (v_0, m_0) \oplus (v_1,m_1) = (v_0 + v_1, \min~\\{m_0, v_0 + m_1\\}) $$

Here, we use an extended set of integers with a largest value $\infty = a +
\infty$ to get a neutral element $(0, \infty)$. This does form a monoid, and the
first case I found of this monoid was in an old [blog
post](https://xi-editor.io/docs/rope_science_04.html). Therefore, it is possible
to perform a reduce, but when implementing it, we have to account for the fact
that a signed 64-bit integer does not have such a value. The closest is the
largest signed 64-bit value, but it would cause overflow. Therefore, we modify
the operator to account for this problem to get the following algorithm.

```
def op (v0: i64, m0: i64) (v1: i64, m1: i64): (i64, i64) =
  (v0 + v1, if m1 == i64.highest then m0 else i64.min m0 (v0 + m1))

def ne: (i64, i64) = (0, i64.highest)

def parentheses_matches [n] (str: [n]u8): bool =
  let (sum, min) =
    map (\c -> if c == '(' then (1, 1) else (-1, -1)) str
    |> reduce op ne
  in sum == 0 && 0 <= min
```

This does solve the problem with $O(n)$ work and $O(\log n)$ span again, but you
only perform approximately $n$ byte reads. Using this approach, you sadly do not
know which parentheses pair up together. So, in the case where you have multiple
different types of parentheses like {[()]}, you cannot check if parentheses of
the same type match. This is the most general definition of the parentheses
matching problem. This could be solved sequentially using the stack approach as
aforementioned. A [classic
approach](https://futhark-lang.org/examples/parens.html) to solving this
instance in a parallel manner is first computing the nesting depth of each
parenthesis and then using a stable sorting algorithm to pair them up. This can
again be thought of as maintaining the stack size, since the stack size is
related to the nesting depth of each parenthesis by subtracting one from the
stack size at an opening parenthesis.

```
   [(, ), (, {, (, ), {, }, }, )] = "()({(){}})"
[0, 1, 0, 1, 2, 3, 2, 3, 2, 1, 0] (Stack size)
   [0, 0, 0, 1, 2, 2, 2, 2, 1, 0] (Nesting depth)
```

From this observation, we can clearly construct a function that computes the
nesting depth of every pair.

```
def nesting_depths [n] (str: [n]u8): bool =
  map (\c -> if c == '(' then 1 else -1)) str
  |> scan (+) 0
  |> map2 (\c i -> if c == '(' then i - 1 else i) str
```

Now, if we pair each parenthesis with its nesting depth and sort them by their
nesting depth, we can then check if all parentheses on even indices match with
the parenthesis at the neighboring odd index. The stable sort here is important
since it maintains the relative ordering of items that are equal.

```
[(, ), (, ), {, }, (, ), {, }] (Sorted parentheses)
[0, 0, 0, 0, 1, 1, 2, 2, 2, 2] (Sorted nesting depths)
[0, 1, 2, 9, 3, 8, 4, 5, 6, 7] (Origin indices)
```

In Futhark, we can implement this using a radix sort, and then in the end do a
simple map-reduce to determine if the parentheses pair up correctly.

```
def is_match (c: u8) (c': u8): bool =
  (c == '(' && c' == ')') ||
  (c == '{' && c' == '}')

def parentheses_matches [n] (str: [n]u8): bool =
  let depths = nesting_depths str
  let sorted =
    zip depths str
    |> radix_sort_by_key (.0)
    |> map (.1)
  in iota (n / 2)
     |> map (\i ->
          2 * i + 1 < n &&
          is_match sorted[2 * i] sorted[2 * i + 1])
     |> reduce (&&) true
```

This solves the problem in $O(n)$ work with $O(\log n)$ span. For me, this is an
unsatisfying solution, since radix sort is quite an expensive function and
performs quite a few read and write operations. Luckily, this is not the only
way of solving the problem, because what the sequential stack algorithm and the
parallel sorting algorithm have in common is that they are solving an instance
of the "all previous smaller or equal" problem. That is, for each element in an
array, we ask: what is the nearest index to the left whose value is less than or
equal to the current element? This problem has been thoroughly studied in the
literature.

One such algorithm that is reasonable in practice and quite easy to implement is
due to [Berkman, Schieber &
Vishkin](https://www.sciencedirect.com/science/article/pii/S0196677483710187?via%3Dihub).
The idea is to compute a reduction tree like you would do with the reduce
operation using the minimum operation on an array of values. Here, you must
store the whole tree, which will later be used for querying. First, we compute
this tree from the nesting depths with some padding, where $m$ is the largest
number.

```
                         0
            ┌────────────┴───────────┐
            0                        0
      ┌─────┴─────┐            ┌─────┴─────┐
      0           2            0           m
   ┌──┴──┐     ┌──┴──┐      ┌──┴──┐     ┌──┴──┐
   0     0     2     2      0     m     m     m
 ┌─┴─┐ ┌─┴─┐ ┌─┴─┐ ┌─┴─┐  ┌─┴─┐ ┌─┴─┐ ┌─┴─┐ ┌─┴─┐
[0,  0,0,  1,2,  2,2,  2, 1,  0,m,  m,m,  m,m,  m] (Depths)
[(,  ),(,  {,(,  ),{,  }, },  )]
[0,  1,2,  3,4,  5,6,  7, 8,  9] (Indices)
```

Now to figure out what is the previous or smaller element we traverse up the
tree from a leaf node until the edge taken to the parent is an edge from the a
right child. And till the parent is smaller than or equal to the value of the
leaf we started at. Now we are at a node where the parent is smaller than the
value of the leaf and traverse to the sibling to this node. From this node we
continuely go down to the right children unless it is not smaller or equal to
the original leaf value. When we reach a leaf we have the index of the previous
or smaller element. An implementation of this algorithm can be found in the
[containers](https://github.com/diku-dk/containers) library under the name
`transparent_reduction_tree.fut`. The way this is representated is as an array
using a same approach as a
[eytzinger](https://futhark-lang.org/examples/binary-search.html) layout for
binary search. Where by performing arithmetic operations on the index of nodes
we can traverse to the parent and children using arithmetic operations.

```
def go_parent (i: i64) : i64 = (i - 1) / 2i64

def go_left (i: i64) : bool = 2 * i

def go_right (i: i64) : bool = 2 * i + 1
```

To construct the tree takes $O(n)$ work and has $O(\log n)$ span, while
searching for a previous or smaller element takes $O(\log n)$ work and $O(\log
n)$ span. So, to solve the previous or smaller element problem for every
element would take $O(n \log n)$ work and $O(\log n)$ span. It is possible to do
this work efficiently by splitting up the input array into subarrays of size $n
/ \log n$, solving them sequentially, and using the tree construction with each
leaf being a subarray.

Now, how do we use this to solve the parentheses matching problem? Well, if we
start by computing the nesting depth of every parenthesis, then we just have to
solve the previous or smaller element problem for every element, like we did
before with sorting. We solve this by constructing the tree and then mapping the
lookup procedure over all closing parentheses.

```
import "lib/github.com/diku-dk/containers/array/reduction_tree"

module mintree = mk_mintree i64

def parentheses_matches [n] (str: [n]u8): bool =
  let depths = nesting_depths str
  let tree = mintree.make depths
  in iota n
     |> map (\i ->
        str[i] == '(' ||
        (let j = mintree.previous tree i
         in j != -1 && str[j] == ')'))
     |> reduce (&&) true
```

The insight that we get from solving the parentheses matching problem is that
there are ways of parallelizing problems that are typically solved using a
stack. This technique is used in the Alpacc parser generator to perform
$\text{LL}(k)$ parsing and determine the parent of a node in a preorder
traversal tree in parallel, both tasks where stacks are usually employed.