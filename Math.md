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
- $i_2 = i_0 - p_0r^2 - 2p_0r + rk$

**Simplifying $p_2$:**
- $p_2 = p_1 - (k - rp_1)$
- $p_2 = (p_0 - (k - rp_0)) - (k - r(p_0 - (k - rp_0)))$
- $p_2 = (p_0 -k + rp_0) - (k - r(p_0 -k + rp_0))$
- $p_2 = p_0 -k + rp_0 - (k -rp_0 +rk - r^2p_0)$
- $p_2 = p_0 -k + rp_0 -k +rp_0 -rk + r^2p_0$
- $p_2 = p_0 -2k + 2rp_0 -rk + r^2p_0$

**At second 3:**
- $i_3 = i_2 - rp_2$
- $p_3 = p_2 - (k - rp_2)$

**Simplifying $i_3$:**
- $i_3 = i_2 - rp_2$
- $i_3 = (i_0 - p_0r^2 - 2p_0r + rk) - r(p_0 -2k + 2rp_0 -rk + r^2p_0)$
- $i_3 = i_0 - p_0r^2 - 2p_0r + rk -rp_0 +2kr - 2r^2p_0 +r^2k - r^3p_0$
- $i_3 = i_0 - 3p_0r^2 - 3p_0r +3kr +r^2k - r^3p_0$
- $i_3 = i_0 - p_0r^3 - 3p_0r^2 - 3p_0r + kr^2 + 3kr$

**Simplifying $p_3$:**
- $p_3 = p_2 - (k - rp_2)$
