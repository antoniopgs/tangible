from logic import simulate

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
simulate(
    yearlyNewLoans, # don't touch this
    saleFee = 0.01,
    interestFee = 0.02,
    years = 10,
)