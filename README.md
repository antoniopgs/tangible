# tangible
## Formulas
- $$totalDebt() = savedTotalDebt*e^{rt}$$
- $$utilization() = \dfrac{borrowed}{deposits}$$
- $$utilization9() = \dfrac{totalDebt()}{deposits}$$ (not sure about this one)
- $$interestOwed() = totalDebt() - borrowed$$
- $$lenderApy1() = \dfrac{interestOwed()}{deposits}$$
- $$lenderApy2() = utilization() * wAvgBorrowerRate()$$
- $$lenderApy3() = tUsdcToUsdc() - 1$$
- $$tUsdcToUsdc1() = \dfrac{deposits + interestOwed()}{tUsdcSupply()}$$
- $$tUsdcToUsdc2() = 1+\dfrac{interestOwed}{tUsdcSupply()}$$
- $$tUsdcToUsdc3() = lenderApy() + 1$$
- $$wAvgBorrowerRate1() = \dfrac{lenderApy()}{utilization()}$$
- $$wAvgBorrowerRate2() = \dfrac{interestOwed()}{borrowed}$$
- $$wAvgBorrowerRate9() = \dfrac{interestOwed()}{totalDebt()}$$ (think this is wrong)
- $$borrowerDebt() = principal*e^{rt}$$
- $$borrowerDebt(loan) = loan.tUsdcBalance(1 + wAvgBorrowerRate())$$
