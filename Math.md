**If borrower pays `avgPaymentPerSecond` every second:**
- each payment's interest = `unpaidPrincipal * (ratePerSecond * 1s)` = `unpaidPrincipal * ratePerSecond`
- each payment's repayment = `avgPaymentPerSecond - (unpaidPrincipal * ratePerSecond)`

**So at second 1:**
- unpaidInterestS1 = unpaidInterestS0 - (unpaidPrincipalS0 * ratePerSecond)
- unpaidPrincipalS1 = unpaidPrincipalS0 - (avgPaymentPerSecond - (unpaidPrincipalS0 * ratePerSecond))

**Rename:**
- unpaidInterestSecond0 -> $i_0$
- unpaidPrincipalSecond1 -> $p_1$
- ratePerSecond -> $r$
- avgPaymentPerSecond -> $k$

**So at second 1:**
- $i_1 = i_0 - rp_0$
- $p_1 = p_0 - (k - rp_0)$

**At second 2:**
- $i_2 = i_1 - rp_1$
- $p_2 = p_1 - (k - rp_1)$

**Simplifying $i_2$:**
- $i_2 = i_1 - rp_1$
- $i_2 = (i_0 - rp_0) - r(p_0 - (k - rp_0))$
- $i_2 = i_0 - rp_0 - r(p_0  -k + rp_0)$
- $i_2 = i_0 - rp_0 -rp_0  +rk - r^2p_0$
- $i_2 = i_0 - 2rp_0  +rk - r^2p_0$
- $i_2 = -p_0r^2-2p_0r+rk+i_0$
- $i_2 = r(-p_0r-2p_0+k)+i_0$
- $i_2 = r(-p_0(r+2)+k)+i_0$

**Simplifying $p_2$:**
- $p_2 = i_1 - rp_1$

**At second 3:**
- $i_3 = i_2 - rp_2$
- $p_3 = p_2 - (k - rp_2)$

