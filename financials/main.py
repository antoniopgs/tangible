from logic import simulate
import pandas as pd
import matplotlib.pyplot as plt

def addlabels(x,y):
    for i in range(len(x)):
        plt.text(i,y[i],y[i])

# Edit year by year assumptions below
yearlyNewLoans = {
    1: {
        "units": 82,
        "mortgageNeed": 0.6,
        "avgPrice": 135_000,
        "ltv": 0.5,
        "apr": 0.06,
        "maxYears": 5
    },
    3: {
        "units": 82,
        "mortgageNeed": 0.6,
        "avgPrice": 155_000,
        "ltv": 0.5,
        "apr": 0.06,
        "maxYears": 5
    },
    4: {
        "units": 82,
        "mortgageNeed": 0.6,
        "avgPrice": 155_000,
        "ltv": 0.5,
        "apr": 0.06,
        "maxYears": 5
    }
}

# Edit assumptions below
data = simulate(
    yearlyNewLoans, # don't touch this
    saleFee = 0.01,
    interestFee = 0.01
)

df = pd.DataFrame.from_dict(data)
transposed = df.T

apys = transposed["lenderNetApy"].plot(
    kind="bar",
    xlabel="Year",
    ylabel="Lender Net Apy %"
)

x = [ year for year in list(data) ]
y = [ round(data[year]["lenderNetApy"], 2) for year in list(data) ]
addlabels(x, y)

plt.show()