# Imports
import json
from re import X
from data import yearlyNewLoans


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
        x = (1 + ratePerSecond)**maxSeconds

        # Calculate paymentPerSecond
        paymentPerSecond = (principal * ratePerSecond * x) / (x - 1)

        # Return
        return ratePerSecond, maxSeconds, paymentPerSecond

    def balanceAt(self, loanSecond):
        balance = (self.paymentPerSecond *
                   (1 - (1 + self.ratePerSecond)**
                    (loanSecond - self.maxSeconds))) / self.ratePerSecond
        return balance if balance > 0 else 0


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

    def combinedYearlyInterest(self, currentYear): # year comes in as 3
        loanYear = self.loanYear(currentYear)
        loanYearEndSecond = loanYear * Loan.yearSeconds
        loanYearStartSecond = (loanYear - 1) * Loan.yearSeconds
        print("currentYear:", currentYear)
        print("loanYear:", loanYear)
        print("loanYearEndSecond:", loanYearEndSecond)
        print("loanYearStartSecond:", loanYearStartSecond)
        print("self.combinedInterestPaidAt(yearEnd):", self.combinedInterestPaidAt(loanYearEndSecond))
        print("self.combinedInterestPaidAt(yearStart):", self.combinedInterestPaidAt(loanYearStartSecond))
        print()
        return self.combinedInterestPaidAt(loanYearEndSecond) - self.combinedInterestPaidAt(loanYearStartSecond)


# Standalone Functions
def apy(interest, principal):
    return interest / principal if principal > 0 else 0


def netApy(interest, principal):
    return (1 - interestFee) * apy(interest, principal)


def netApyPct(interest, principal):
    return netApy(interest, principal) * 100


# Main Logic
interestFee = 0.02
years = 10
loanGroups = []
for year in range(1, years + 1):

    print(f"----- YEAR: {year} -----")

    # If there are newLoans
    newLoans = yearlyNewLoans.get(year)
    if (newLoans is not None):

        # Add new LoanGroup
        loanGroups.append(
            LoanGroup(newLoans["avgPrice"], newLoans["ltv"], newLoans["apr"],
                      newLoans["maxYears"], newLoans["units"],
                      newLoans["mortgageNeed"], year))

    # Loop Loan Groups
    allLoanGroupsYearlyInterest = 0
    allLoanGroupsYearlyPrincipal = 0
    for loanGroup in loanGroups:

        # If loan not over
        interest = loanGroup.combinedYearlyInterest(year)
        print("interest:", interest)
        if (interest > 0):
            allLoanGroupsYearlyInterest += interest
            allLoanGroupsYearlyPrincipal += loanGroup.combinedPrincipal

    # Print
    print(f"- allLoanGroupsYearlyInterest: {allLoanGroupsYearlyInterest}")
    print(f"- allLoanGroupsYearlyPrincipal: {allLoanGroupsYearlyPrincipal}")
    print(
        f"- Net Apy: {netApyPct(allLoanGroupsYearlyInterest, allLoanGroupsYearlyPrincipal)}%\n"
    )
