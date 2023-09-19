# Classes
class Loan:

    yearSeconds = 365 * 24 * 60 * 60

    def __init__(self, unitPrice, ltv, apr, maxYears, currentYear):

        # Calculate Vars
        self.principal = unitPrice * ltv
        self.startYear = currentYear
        self.maxYears = maxYears
        self.ratePerSecond, self.maxSeconds, self.paymentPerSecond = self.calculateVars(self.principal, apr, maxYears)

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


class LoanGroup(Loan):

    def __init__(self, unitPrice, ltv, apr, maxYears, units, mortgageNeed, currentYear):
        Loan.__init__(self, unitPrice, ltv, apr, maxYears, currentYear)
        self.loanCount = units * mortgageNeed
        principal = unitPrice * ltv
        self.combinedPrincipal = self.loanCount * principal

    def combinedBalanceAt(self, loanSecond):
        return self.loanCount * self.balanceAt(loanSecond)

    def combinedRepaymentPaidAt(self, loanSecond):
        return self.combinedBalanceAt(0) - self.combinedBalanceAt(loanSecond)

    def combinedInterestPaidAt(self, loanSecond):
        totalPaidAtSecond = self.loanCount * loanSecond * self.paymentPerSecond
        return totalPaidAtSecond - self.combinedRepaymentPaidAt(loanSecond)

    def loanYear(self, currentYear):
        return currentYear - self.startYear + 1

    def combinedYearlyInterest(self, currentYear):  # year comes in as 3
        loanYear = self.loanYear(currentYear)
        loanYearEndSecond = loanYear * Loan.yearSeconds
        loanYearStartSecond = (loanYear - 1) * Loan.yearSeconds
        return self.combinedInterestPaidAt(loanYearEndSecond) - self.combinedInterestPaidAt(loanYearStartSecond)


# Standalone Functions
def apy(interest, principal):
    return interest / principal if principal > 0 else 0

def netApy(interestFee, interest, principal):
    return (1 - interestFee) * apy(interest, principal)

def netApyPct(interestFee, interest, principal):
    return netApy(interestFee, interest, principal) * 100

def salesProfits(units, mortgageNeed, avgSalePrice, saleFee):
    unitsSold = units * mortgageNeed  # assuming we only sell mortgages
    salesVolume = unitsSold * avgSalePrice
    return saleFee * salesVolume

def simulate(yearlyNewLoans, saleFee, interestFee, years):
    loanGroups = []
    for year in range(1, years + 1):

        print(f"----- YEAR: {year} -----")

        # If there are newLoans
        newLoans = yearlyNewLoans.get(year)
        if (newLoans is not None):

            units = newLoans['units']
            mortgageNeed = newLoans['mortgageNeed']
            avgPrice = newLoans['avgPrice']
            ltv = newLoans['ltv']

            print(f"- New Loans: {int(units * mortgageNeed)}")
            print(f"- Tangible Sale Fees: {salesProfits(units, mortgageNeed, avgPrice, saleFee):,.2f}$")
            print(f"- New Principal: {(units * mortgageNeed) * avgPrice * ltv:,.2f}$")

            # Add new LoanGroup
            loanGroups.append(
                LoanGroup(newLoans["avgPrice"], newLoans["ltv"], newLoans["apr"], newLoans["maxYears"], newLoans["units"], newLoans["mortgageNeed"], year)
            )

        # If there are no newLoans
        else:
            print(f"- New Loans: 0")
            print(f"- Tangible Sale Fees: 0$")
            print(f"- New Principal: 0$")

        # Loop Loan Groups
        allLoanGroupsYearlyInterest = 0
        allLoanGroupsYearlyPrincipal = 0
        for loanGroup in loanGroups:

            # If loan not over
            interest = loanGroup.combinedYearlyInterest(year)
            if (interest > 0):
                allLoanGroupsYearlyInterest += interest
                allLoanGroupsYearlyPrincipal += loanGroup.combinedPrincipal

        # Print
        print(f"- Active Principal: {allLoanGroupsYearlyPrincipal:,.2f}$")
        print(f"- Gross Interest Profits: {allLoanGroupsYearlyInterest:,.2f}$")
        print(f"- Tangible Interest Fees: {interestFee * allLoanGroupsYearlyInterest:,.2f}$")
        print(f"- Lender Net Interest Profits: {(1 - interestFee) * allLoanGroupsYearlyInterest:,.2f}$")
        print(f"- Lender Net Apy: {round(netApyPct(interestFee, allLoanGroupsYearlyInterest, allLoanGroupsYearlyPrincipal), 2)}%\n")
