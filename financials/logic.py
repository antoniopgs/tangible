class Loan:

    yearSeconds = 365 * 24 * 60 * 60

    def __init__(self, principal, apr, maxYears, currentYear):

        # Calculate Vars
        self.startYear = currentYear
        self.maxYears = maxYears
        self.ratePerSecond, self.maxSeconds, self.paymentPerSecond = self.calculateVars(principal, apr, maxYears)

    def calculateVars(self, principal, apr, maxYears):

        # Calculate ratePerSecond & maxSeconds
        ratePerSecond = apr / Loan.yearSeconds
        maxSeconds = maxYears * Loan.yearSeconds

        # Calculate x
        x = (1 + ratePerSecond) ** maxSeconds

        # Calculate paymentPerSecond
        paymentPerSecond = (principal * ratePerSecond * x) / (x - 1)

        # Return
        return ratePerSecond, maxSeconds, paymentPerSecond

    def balanceAt(self, loanSecond):
        return (self.paymentPerSecond * (1 - (1 + self.ratePerSecond) ** (loanSecond - self.maxSeconds))) / self.ratePerSecond

    def loanYear(self, currentYear):
        return currentYear - self.startYear + 1

    def repaymentPaidAt(self, loanSecond):
        return self.balanceAt(0) - self.balanceAt(loanSecond)

    def interestPaidAt(self, loanSecond):
        totalPaidAtSecond = loanSecond * self.paymentPerSecond
        return totalPaidAtSecond - self.repaymentPaidAt(loanSecond)

    def yearlyInterest(self, currentYear):
        loanYear = self.loanYear(currentYear)
        loanYearEndSecond = loanYear * Loan.yearSeconds
        loanYearStartSecond = (loanYear - 1) * Loan.yearSeconds
        return self.interestPaidAt(loanYearEndSecond) - self.interestPaidAt(loanYearStartSecond)

    def yearlyRepayment(self, currentYear):
        loanYear = self.loanYear(currentYear)
        loanYearEndSecond = loanYear * Loan.yearSeconds
        loanYearStartSecond = (loanYear - 1) * Loan.yearSeconds
        return self.balanceAt(loanYearStartSecond) - self.balanceAt(loanYearEndSecond)


# Standalone Functions
def apy(interest, principal):
    return interest / principal if principal > 0 else 0

def netApy(interestFee, interest, principal):
    return (1 - interestFee) * apy(interest, principal)

def netApyPct(interestFee, interest, principal):
    return netApy(interestFee, interest, principal) * 100

def salesProfits(newLoanCount, avgSalePrice, saleFee):
    unitsSold = newLoanCount # assuming we only sell mortgages
    salesVolume = unitsSold * avgSalePrice
    return saleFee * salesVolume

def simulate(yearlyNewLoans, saleFee, interestFee):
    
    loans = []
    combinedUnpaidPrincipal = 0 # assuming lender keeps utilization at 100%

    # Calculate lastYear
    lastLoanStartYear = list(yearlyNewLoans)[-1]
    lastLoanMaxYears = yearlyNewLoans[lastLoanStartYear]["maxYears"]
    lastYear = lastLoanStartYear + lastLoanMaxYears - 1

    # Loop years
    for year in range(1, lastYear + 1):

        print(f"----- YEAR: {year} -----")

        # If there are newLoans
        newLoans = yearlyNewLoans.get(year)
        if (newLoans is not None):
            
            # Get data
            units = newLoans['units']
            mortgageNeed = newLoans['mortgageNeed']
            avgPrice = newLoans['avgPrice']
            ltv = newLoans['ltv']
            apr = newLoans['apr']
            maxYears = newLoans['maxYears']

            # Calculate info
            principal = ltv * avgPrice
            newLoanCount = int(mortgageNeed * units)

            print(f"- New Loans: {newLoanCount}")
            print(f"- Tangible Sale Fees: {salesProfits(newLoanCount, avgPrice, saleFee):,.2f}$")
            print(f"- New Principal: {newLoanCount * principal:,.2f}$")

            # Loop newLoanCount
            for i in range(newLoanCount):
                
                # Increase combinedUnpaidPrincipal
                combinedUnpaidPrincipal += principal

                # Add new Loan
                loans.append(
                    Loan(principal, apr, maxYears, year)
                )

        # Loop Loan Groups
        combinedYearlyInterest = 0

        # Loop loans
        for loan in loans:

            # If loan not over
            interest = loan.yearlyInterest(year)
            if (interest > 0):
                
                # Update activePrincipal and combinedYearlyInterest
                #combinedUnpaidPrincipal -= loan.yearlyRepayment(year) # TODO: figure this out
                combinedYearlyInterest += interest

        # Print
        print(f"- Active Principal: {combinedUnpaidPrincipal:,.2f}$")
        print(f"- Gross Interest Profits: {combinedYearlyInterest:,.2f}$")
        print(f"- Tangible Interest Fees: {interestFee * combinedYearlyInterest:,.2f}$")
        print(f"- Lender Net Interest Profits: {(1 - interestFee) * combinedYearlyInterest:,.2f}$")
        print(f"- Lender Net Apy: {round(netApyPct(interestFee, combinedYearlyInterest, combinedUnpaidPrincipal), 2)}%\n")
