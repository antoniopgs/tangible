from data import yearlyNewLoans
import json


class Loan:

    loanIDs = 1
    yearSeconds = 365 * 24 * 60 * 60

    def __init__(self, principal, apr, maxYears):

        # Calculate Vars
        ratePerSecond, maxSeconds, paymentPerSecond = self.calculateVars(
            principal, apr, maxYears)

        # Store Instance Vars
        self.id = Loan.loanIDs
        Loan.loanIDs = Loan.loanIDs + 1
        self.ratePerSecond = ratePerSecond
        self.maxSeconds = maxSeconds
        self.paymentPerSecond = paymentPerSecond
        self.currentYear = 1  # start on 1st year

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

    def balanceAtSecond(self, second):
        return ((self.paymentPerSecond *
                 (1 -
                  (1 + self.ratePerSecond)**(second - self.maxSeconds - 1))) /
                self.ratePerSecond)

    def yearStartTime(self, yearNumber):
        return Loan.yearSeconds * (yearNumber - 1)

    def yearlyRepayments(self):
        currentYearStartBalance = self.balanceAtSecond(
            self.yearStartTime(self.currentYear))
        nextYearStartBalance = self.balanceAtSecond(
            self.yearStartTime(self.currentYear + 1))
        return currentYearStartBalance - nextYearStartBalance

    def yearlyPayments(self):
        return self.paymentPerSecond * Loan.yearSeconds

    def incrementYear(self):
        self.currentYear = self.currentYear + 1

    def calculateYearlyInterestPaid(self):
        yearlyInterestPaid = self.yearlyPayments() - self.yearlyRepayments()
        return yearlyInterestPaid if yearlyInterestPaid > 0 else 0


# Yearly New Loans
years = 10
activeLoans = []
yearlyInterestPayments = {}
interestFee = 0.02

for y in range(1, years):

    print(f"----- YEAR: {y} -----")
    print(f"- activeLoans: {len(activeLoans)}")

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

    yearlyInterestPayments[y] = {
        "tangibleInterestProfit": interestFee * combinedInterestPayments,
        "lenderProfit": (1 - interestFee) * combinedInterestPayments
    }

print(json.dumps(yearlyInterestPayments, indent=4))

# Todo: remove loans from activeLoans