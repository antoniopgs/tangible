**I can either:**

- a) **Compound per Second**
  - Pros: Easier math (each compoundingPeriod/second can only have 1 payment)
  - Cons: Complex Defaults (What would constitute a default?)
- b) **Compound per 30 Days**
 - Pros: Simpler Defaults (check if `block.timestamp > lastPaymentTime + 30 days`)
  - Cons: Harder Math (each compoundingPeriod/30 days could have multiple payments)

**What would constitute a default in a)?**

- **option 1:** Instead of calculating `loan.interest` upfront, I could make it grow by the second. If the borrower takes too long to pay, `loan.interest` will grow, raising his debt closer to the collateral value (which triggers liquidation). Few questions on this:
  - Would payment irregularity be a problem? Borrower could never pay, then dump a bunch of money all at once.
  - Currently,`lenderApy() = interestOwed / totalDeposits`. If `interestOwed` stops being calculated upfront, and becomes a function that grows over time, how do I calculate `lenderApy()`?
  - At foreclosure time, how would I know how much `unpaidInterest` the borrower owes?
- **option 2:** Maybe, I could implement some sort of "minimum payment speed" (which would be the slowest speed at which the borrower pays off his loan). A "principal" cap would be calculated for each month. If the borrower doesn't pay fast enough to stay below the cap, he gets liquidated. The principalCap for next month can't just be calculated off the current principal (because if a borrower pays more in January, it shouldn't force him to pay more in February). So the `principalCap` at each month should be calculated off the borrowedAmount at the start of the loan. This requires me to figure out the mathematical expression for the unpaidInterest at each payment, assuming each payment is minPayment.

**How to simplify multiple payments within same compounding period in b)?**

- **option 1:** I could say that if a 2nd payment happens within the same month, it will just pay for the next month in advance. I think this would mean the borrower would gain by paying more (because it would further reduce his loan balance for next month), but he wouldn't really gain by paying earlier, as the same monthly interest rate would apply (regardless of when he makes his payment)
- **option 2: **What if I just say that any further payments within the same month don't accrue interest?
