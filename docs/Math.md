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

**At second 1:**
- $i_1 = i_0 - rp_0$
- $p_1 = p_0 - (k - rp_0)$

**Simplify $p_1$:**
- $p_1 = p_0 - (k - rp_0)$
- $p_1 = p_0 -k + rp_0$
- $p_1 = p_0 + rp_0 -k$
- $p_1 = p_0(1+r) -k$

**So at second 1 (simplified):**
- $i_1 = i_0 - rp_0$
- $p_1 = p_0(1+r) -k$

**At second 2:**
- $i_2 = i_1 - rp_1$
- $p_2 = p_1(1 + r) -k$

**Simplifying $i_2$:**
- $i_2 =$

**Simplifying $p_2$:**
- $p_2 =$

**At second 3:**
- $i_3 =$
- $p_3 =$

**Simplifying $i_3$:**
- $i_3 =$

**Simplifying $p_3$:**
- $p_3 =$
