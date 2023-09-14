# Imports
import json
from data import yearlyNewLoans

# Classes
class Loan:

    yearSeconds = 365 * 24 * 60 * 60

    def __init__(self, unitPrice, ltv, apr, maxYears):

        # Calculate Vars
        self.principal = unitPrice * ltv
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

    def balanceAt(self, second):
        balance = (self.paymentPerSecond * (1 - (1 + self.ratePerSecond) ** (second - self.maxSeconds))) / self.ratePerSecond
        return balance if balance > 0 else 0

class LoanGroup(Loan):
    
    def __init__(self, unitPrice, ltv, apr, maxYears, units, mortgageNeed):
        Loan.__init__(self, unitPrice, ltv, apr, maxYears)
        self.loanCount = units * mortgageNeed
        principal = unitPrice * ltv
        self.combinedPrincipal = self.loanCount * principal

    def combinedBalanceAt(self, second):
        return self.loanCount * self.balanceAt(second)

    def combinedRepaymentPaidAt(self, second):
        return self.combinedBalanceAt(0) - self.combinedBalanceAt(second)

    def combinedInterestPaidAt(self, second):
        totalPaidAtSecond = self.loanCount * second * self.paymentPerSecond
        return totalPaidAtSecond - self.combinedRepaymentPaidAt(second)

    def combinedYearlyInterest(self, year):
        yearStart = (year - 1) * Loan.yearSeconds
        yearEnd = year * Loan.yearSeconds
        return self.combinedInterestPaidAt(yearEnd) - self.combinedInterestPaidAt(yearStart)

    def combinedPrincipalAt(self, year):
        yearEndSeconds = year * Loan.yearSeconds
        return self.combinedPrincipal if yearEndSeconds <= self.maxSeconds else 0


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
            LoanGroup(newLoans["avgPrice"], newLoans["ltv"], newLoans["apr"], newLoans["maxYears"], newLoans["units"], newLoans["mortgageNeed"])
        )

    # Loop Loan Groups
    allLoanGroupsYearlyInterest = 0
    allLoanGroupsYearlyPrincipal = 0
    for loanGroup in loanGroups:
        allLoanGroupsYearlyInterest += loanGroup.combinedYearlyInterest(year)
        allLoanGroupsYearlyPrincipal += loanGroup.combinedPrincipalAt(year)

    # Print
    print(f"- Net Apy: {netApyPct(allLoanGroupsYearlyInterest, allLoanGroupsYearlyPrincipal)}%\n")
    