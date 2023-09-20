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

    def repaymentPaidAt(self, loanSecond):
        return self.balanceAt(0) - self.balanceAt(loanSecond)

    def interestPaidAt(self, loanSecond):
        totalPaidAtSecond = loanSecond * self.paymentPerSecond
        return totalPaidAtSecond - self.repaymentPaidAt(loanSecond)

    def yearlyInterest(self, loanYear):
        loanYearEndSecond = loanYear * Loan.yearSeconds
        loanYearStartSecond = (loanYear - 1) * Loan.yearSeconds
        return self.interestPaidAt(loanYearEndSecond) - self.interestPaidAt(loanYearStartSecond)

    def loanYear(self, currentYear):
        return currentYear - self.startYear + 1

    def curYearStartBalanceAt(self, currentYear):
        loanYear = self.loanYear(currentYear)
        loanYearStartSecond = (loanYear - 1) * Loan.yearSeconds
        return self.balanceAt(loanYearStartSecond)

    def curYearYearlyInterest(self, currentYear):
        return self.yearlyInterest(self.loanYear(currentYear))


# Standalone Functions
def apy(interest, principal):
    return interest / principal if principal > 0 else 0

def netApy(interestFee, interest, principal):
    return (1 - interestFee) * apy(interest, principal)

def salesProfits(newLoanCount, avgSalePrice, saleFee):
    unitsSold = newLoanCount # only counting sales of initial mortgages
    salesVolume = unitsSold * avgSalePrice
    return saleFee * salesVolume

def simulate(yearlyNewLoans, saleFee, interestFee):
    
    loans = []
    output = {}

    # Calculate lastYear
    lastLoanStartYear = list(yearlyNewLoans)[-1]
    lastLoanMaxYears = yearlyNewLoans[lastLoanStartYear]["maxYears"]
    lastYear = lastLoanStartYear + lastLoanMaxYears - 1

    # Loop years
    for year in range(1, lastYear + 1):

        # Year vars
        newLoanCount = 0
        combinedNewPrincipal = 0
        tangibleSaleFees = 0
        combinedActivePrincipal = 0
        combinedInterest = 0

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
            combinedNewPrincipal = principal * newLoanCount
            tangibleSaleFees = salesProfits(newLoanCount, avgPrice, saleFee) # only counting sales of initial mortgages

            # Loop newLoanCount
            for i in range(newLoanCount):

                # Add new Loan
                loans.append(
                    Loan(principal, apr, maxYears, year)
                )

        # Loop loans
        for loan in loans:

            # If loan not over
            interest = loan.curYearYearlyInterest(year)
            if (interest > 0): # if loan is over interest will return negative

                # Update combinedActivePrincipal & combinedInterest
                combinedActivePrincipal += loan.curYearStartBalanceAt(year)
                combinedInterest += interest

        # Output year
        output[year] = {
            "newLoanCount": newLoanCount,
            "combinedNewPrincipal": combinedNewPrincipal,
            "tangibleSaleFees": tangibleSaleFees,
            "combinedActivePrincipal": combinedActivePrincipal,
            "combinedInterest": combinedInterest,
            "tangibleInterestFees": interestFee * combinedInterest,
            "lenderNetInterestProfits": (1 - interestFee) * combinedInterest,
            "lenderNetApy": netApy(interestFee, combinedInterest, combinedActivePrincipal) * 100,
            "tangibleTotalProfits": tangibleSaleFees + (interestFee * combinedInterest)
        }

    # Return output
    return output
