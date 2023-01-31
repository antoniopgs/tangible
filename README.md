# tangible
## Formulas
- $$systemDebt() = savedSystemDebt*e^{rt}$$
- $$utilization() = \dfrac{borrowed}{deposits}$$
- $$utilization9() = \dfrac{systemDebt()}{deposits}$$ (not sure about this one)
- $$interestOwed() = systemDebt() - borrowed$$
- $$lenderApy1() = \dfrac{interestOwed()}{deposits}$$
- $$lenderApy2() = utilization() * wAvgBorrowerRate()$$
- $$lenderApy3() = tUsdcToUsdc() - 1$$
- $$tUsdcToUsdc1() = \dfrac{deposits + interestOwed()}{tUsdcSupply()}$$
- $$tUsdcToUsdc2() = 1+\dfrac{interestOwed}{tUsdcSupply()}$$
- $$tUsdcToUsdc3() = lenderApy() + 1$$
- $$wAvgBorrowerRate1() = \dfrac{lenderApy()}{utilization()}$$
- $$wAvgBorrowerRate2() = \dfrac{interestOwed()}{borrowed}$$
- $$wAvgBorrowerRate9() = \dfrac{interestOwed()}{systemDebt()}$$ (think this is wrong)
- $$borrowerDebt() = principal*e^{rt}$$
- $$borrowerDebt(loan) = loan.tUsdcBalance(1 + wAvgBorrowerRate())$$
