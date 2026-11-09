# Shor's algorithm for a general period: a proof outline

Notation as in `Quantum_Basics.thy`: $e(\theta)=\cos\theta+i\sin\theta$ (`cis`), the QFT is
$(F_Nv)_j=N^{-1/2}\sum_{k<N}e(2\pi jk/N)\,v_k$, $\operatorname{prob}(v,j)=|v_j|^2$, and
$\psi=\psi_{N,r,x_0}=L^{-1/2}\sum_{k<N,\;k\equiv x_0\,(r)}|k\rangle$ with
$L=\#\{k<N: k\equiv x_0 \bmod r\}$. This is an outline of one proof, not a formal script.

## 1. The classical step (`shor_factor`)

Let $r$ be the order of $a$ modulo $n>1$, $r=2s$ even, and $b=a^{s}$ with $b\not\equiv -1\pmod n$.
Then $b^2=a^r\equiv1$, so $n\mid b^2-1=(b-1)(b+1)$. Since $0<s<r$, minimality of $r$ gives
$b\not\equiv1\pmod n$, so $n\nmid b-1$; by hypothesis $n\nmid b+1$. Put $g=\gcd(b-1,n)$.
If $g=n$ then $n\mid b-1$, a contradiction, so $g<n$. If $g=1$, then $n$ is coprime to $b-1$ and
divides $(b-1)(b+1)$, so $n\mid b+1$ (Euclid's lemma), a contradiction. Hence $1<g<n$.

## 2. Size of the residue class

For $x_0<r<N$ the indices are $x_0+mr$ with $0\le m<L$, so $x_0+(L-1)r<N\le x_0+Lr$, and since
$x_0<r$ this gives
$$N-r\le Lr\le N+r .$$
In particular $L>0$ and $\psi$ is a unit vector: $\sum_k|\psi_k|^2=L\cdot\frac1L=1$.

## 3. The amplitude as a geometric sum

Fix $j<N$ and an integer $c$, and write $d=jr-cN$ and $\varphi=\pi d/N$. Then
$$(F_N\psi)_j=\frac1{\sqrt{LN}}\sum_{m<L}e\!\Big(\frac{2\pi j(x_0+mr)}{N}\Big).$$
The factor $e(2\pi jx_0/N)$ has modulus 1 and is irrelevant. Since $jr=cN+d$ and $e$ is
$2\pi$-periodic, $e(2\pi jrm/N)=e(2m\varphi)$. So
$$|(F_N\psi)_j|=\frac{|G|}{\sqrt{LN}},\qquad G=\sum_{m<L}e^{2im\varphi}.$$
Only the distance $d$ from $jr$ to a multiple of $N$ matters. For $\sin\varphi\ne0$ the geometric
series gives
$$|G|=\Big|\frac{e^{2iL\varphi}-1}{e^{2i\varphi}-1}\Big|=\frac{|\sin L\varphi|}{|\sin\varphi|},$$
using $|e^{i\beta}-1|=2|\sin(\beta/2)|$. If $\varphi=0$, then $G=L$.

## 4. Lower bound on $|G|$ near a peak

Assume $2|d|\le r$, that is, $j$ is within $r/2$ of a multiple of $N/r$. Then
$|\varphi|\le\pi r/(2N)<\pi/2$, because $r<N$.

*Tool (Jordan's inequality).* $\sin x\ge\frac2\pi x$ on $[0,\pi/2]$ (concavity of $\sin$ there),
hence by symmetry $\sin t\ge\frac2\pi\min(t,\pi-t)$ on $[0,\pi]$. Also $|\sin\varphi|\le|\varphi|$.

*Case $d=0$.* $|G|=L\ge (N-r)/r\ge\frac2\pi\cdot\frac{N-r}{r}$.

*Case $d\ne0$.* Let $t=L|\varphi|$. Then $t\le L\cdot\frac{\pi r}{2N}\le\frac\pi2\cdot\frac{N+r}{N}<\pi$, so
$\sin t\ge0$ and $|\sin L\varphi|=\sin t$. Put $\kappa=(N-r)/r$. From $L\ge\kappa$ we get
$\kappa|\varphi|\le t$. From $L+\kappa\le 2N/r$ (add $Lr\le N+r$ to $N-r$) and $|\varphi|\le\pi r/(2N)$
we get $(L+\kappa)|\varphi|\le\pi$, i.e. $\kappa|\varphi|\le\pi-t$. So $\kappa|\varphi|\le\min(t,\pi-t)$ and
$$\sin t\ \ge\ \tfrac2\pi\kappa|\varphi|,\qquad
|G|=\frac{\sin t}{|\sin\varphi|}\ \ge\ \frac{\sin t}{|\varphi|}\ \ge\ \frac2\pi\kappa .$$
In both cases $|G|\ge\frac2\pi\cdot\frac{N-r}{r}$.

## 5. The peak probability (`shor_peak`)

Using $LN\le (N+r)N/r$ from §2,
$$\operatorname{prob}(F_N\psi,j)=\frac{|G|^2}{LN}\ \ge\ \frac4{\pi^2}\cdot\frac{(N-r)^2}{r^2}\cdot\frac{r}{(N+r)N}
=\frac{4}{\pi^2 r}\Big(1-\frac rN\Big)^2\frac{N}{N+r}.$$
Finally $\frac N{N+r}\ge 1-\frac rN$, which is $N^2\ge N^2-r^2$. Hence
$\operatorname{prob}\ge \frac4{\pi^2r}(1-r/N)^3$. Together with §2 (unit vector) this is `shor_peak`.

## 6. Recovering the period (`recover`)

`recover N j` is the least $b>0$ such that some fraction $a/b$ satisfies $|j/N-a/b|\le 1/(2N)$.
(The continued-fraction expansion of $j/N$ computes this efficiently; here only the value matters.)

*Claim.* Let $r^2<N$, $\gcd(c,r)=1$, and $|j/N-c/r|\le1/(2N)$ (equivalently $2|jr-cN|\le r$).
Then $\texttt{recover}\,N\,j=r$.

*Proof.* $b=r$ is admissible, so the least $b$ is $\le r$. Suppose some $a/b$ with $0<b<r$ is also
within $1/(2N)$ of $j/N$. By the triangle inequality $|c/r-a/b|\le 1/N$. The left side is
$|bc-ar|/(rb)$, and $rb<r^2<N$ gives $1/N<1/(rb)$. So the integer $|bc-ar|$ is $<1$, hence
$bc=ar$. Then $r\mid bc$, and since $\gcd(c,r)=1$, $r\mid b$, impossible for $0<b<r$. $\square$

This is the uniqueness half of Legendre's theorem on continued fractions: a fraction within
$1/(2q^2)$ of $x$ is a convergent of $x$, and two distinct fractions with denominators $\le r$ differ
by more than $1/N$ when $r^2<N$.

## 7. Counting good outcomes (`shor_general_success`)

Let $C=\{c<r:\gcd(c,r)=1\}$, so $|C|=\varphi(r)$, and for $c\in C$ let $j_c=\lfloor (2cN+r)/(2r)\rfloor$,
the integer nearest to $cN/r$. Then $2|j_cr-cN|\le r$, and $j_c<N$ because $c\le r-1$.

* Each $j_c$ has $\texttt{recover}\,N\,j_c=r$, by §6.
* The $j_c$ are distinct: if $j_c=j_{c'}$ then $|(c-c')N|\le|j_cr-cN|+|j_cr-c'N|\le r<N$, so $c=c'$.
* Each $j_c$ is a peak, so by §5 its probability is $\ge \frac4{\pi^2r}(1-r/N)^3$ (here $r<r^2<N$).

Probabilities are nonnegative, so the total probability of the set $\{j<N:\texttt{recover}\,N\,j=r\}$ is at
least the sum over the $\varphi(r)$ distinct points $j_c$:
$$\sum_{j<N,\ \texttt{recover}\,N\,j=r}\operatorname{prob}(F_N\psi,j)\ \ge\ \varphi(r)\cdot\frac4{\pi^2 r}\Big(1-\frac rN\Big)^3
=\frac4{\pi^2}\cdot\frac{\varphi(r)}{r}\Big(1-\frac rN\Big)^3 .$$
