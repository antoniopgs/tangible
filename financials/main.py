import json
from data import yearlyNewLoans

interestFee = 0.02

class Loan:

    yearSeconds = 365 * 24 * 60 * 60

    def __init__(self, principal, apr, maxYears):

        # Calculate Vars
        ratePerSecond, maxSeconds, paymentPerSecond = self.calculateVars(principal, apr, maxYears)

        # Increment Loan Counter
        Loan.loanCounter = Loan.loanCounter + 1

        # Store Instance Vars
        self.id = Loan.loanCounter
        self.principal = principal
        self.ratePerSecond = ratePerSecond
        self.maxSeconds = maxSeconds
        self.paymentPerSecond = paymentPerSecond

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
    
    def __init__(self, principal, apr, maxYears, units, mortgageNeed):
        Loan.__init__(self, principal, apr, maxYears)
        self.loanCount = units * mortgageNeed

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

    def grossCombinedApy(self, year):
        combinedPrincipal = self.loanCount * self.principal
        return self.combinedYearlyInterest(year) / combinedPrincipal

    def netCombinedApy(self, year):
        return (1 - interestFee) * self.grossCombinedApy(year)

    def netCombinedApyPct(self, year):
        return self.netCombinedApy(year) * 100

    

    


# Yearly New Loans
years = 10
activeLoans = []

for y in range(1, years):

    print(f"----- YEAR: {y} -----")

    # If there are newLoans
    newLoans = yearlyNewLoans.get(y)
    if (newLoans is not None):

        # Calculate newLoans vars
        newLoansAmount = newLoans["mortgageNeed"] * newLoans["units"]
        combinedPrincipal = newLoansAmount * newLoans["avgPrice"] * newLoans[
            "ltv"]

        print(f"- newLoans: {newLoansAmount}")
        print(f"- combinedPrincipal: {combinedPrincipal}")

        # Push newLoans to activeLoans
        activeLoans.append(
            Loan(combinedPrincipal, newLoans["apr"], newLoans["maxYears"]))

        totalPrincipal += combinedPrincipal

    print()

    # Loop activeLoans
    combinedInterestPayments = 0
    for loan in activeLoans:
        print(f"Loan {loan.id}:")
        print(
            f"- balance at start of year {loan.currentYear}: {loan.balanceAtSecond(loan.yearStartTime(loan.currentYear))}"
        )
        combinedInterestPayments += loan.calculateYearlyInterestPaid()
        loan.incrementYear()

    print()

    tangibleInterestProfit = interestFee * combinedInterestPayments
    lenderProfit = combinedInterestPayments - tangibleInterestProfit
    lenderApy = lenderProfit * 100 / totalPrincipal

    print(f"lenderProfit: {lenderProfit}")
    print(f"totalPrincipal: {totalPrincipal}")

    yearlyInterestPayments[y] = {
        "tangibleInterestProfit": interestFee * combinedInterestPayments,
        "lenderProfit": lenderProfit,
        "lenderApy": lenderApy
    }

print(json.dumps(yearlyInterestPayments, indent=4))

# Todo: remove loans from activeLoans
