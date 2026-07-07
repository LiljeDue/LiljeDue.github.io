
$$
b_n + (b_{n - 1} \cdot a_{n}) + (b_{n - 2} \cdot a_{n - 1} \cdot a_n) +~\cdots~+ (b_1 \cdot a_2 \cdot~ \cdots~\cdot a_n)
$$


$$
\begin{aligned}
&\text{if}~\pi_1(b_n)~\text{then}~b_n \\
&\text{else if}~\pi_1(b_{n - 1})~\text{then}~b_{n - 1} \odot a_{n} \\
&\text{else if}~\pi_1(b_{n - 2})~\text{then}~b_{n - 2} \odot a_{n - 1} \odot a_n \\
&\ldots \\
&\text{then}~ b_1 \odot a_2 \odot~ \cdots~\odot a_n
\end{aligned}
$$


$$
\begin{aligned}
&\text{if}~\pi_1(b_n)~\text{then}~b_n \\
&\text{else if}~\pi_1(b_{n - 1} \odot a_{n})~\text{then}~b_{n - 1} \odot a_{n} \\
&\text{else if}~\pi_1(b_{n - 2} \odot a_{n - 1} \odot a_n)~\text{then}~b_{n - 2} \odot a_{n - 1} \odot a_n \\
&\ldots \\
&\text{then}~ b_1 \odot a_2 \odot~ \cdots~\odot a_n
\end{aligned}
$$

$$
(a_1 \oplus a_2, \text{if}~\pi_1(b_2)~\text{then}~b_1~\text{else}~a_1 \oplus b_2)
$$