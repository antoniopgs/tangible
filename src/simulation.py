# System Vars
outstandingDebt = 0
interestOwed = 0
deposits = 0
tUsdcSupply1 = 0
tUsdcSupply2 = 0


# System Functions
def utilization():
    try:
        return outstandingDebt / deposits
    except ZeroDivisionError:
        return 0


def weightedAvgBorrowerRate():
    try:
        return interestOwed / outstandingDebt
    except ZeroDivisionError:
        return 0


def lenderApr1():
    try:
        return interestOwed / deposits
    except ZeroDivisionError:
        return 0


def lenderApr2():
    return utilization() * weightedAvgBorrowerRate()


def tUsdcToUsdc1():
    if tUsdcSupply1 == 0:
        return 1
    else:
        return (deposits + interestOwed) / tUsdcSupply1


def tUsdcToUsdc2():
    if tUsdcSupply2 == 0:
        return 1
    else:
        return 1 + (interestOwed / tUsdcSupply2)


# Util Functions


# Util Functions
def printAndValidate():
    global outstandingDebt, interestOwed, deposits, tUsdcSupply1, tUsdcSupply2
    print(f"""
----- SYSTEM LOG -----
outstandingDebt: {outstandingDebt}$
interestOwed: {interestOwed}$
deposits: {deposits}$
tUsdcSupply1: {tUsdcSupply1}
tUsdcSupply2: {tUsdcSupply2}
utilization: {utilization() * 100}%
weightedAvgBorrowerRate: {weightedAvgBorrowerRate() * 100}%
lenderApr1: {lenderApr1() * 100}%
lenderApr2: {lenderApr2() * 100}%
tUsdcToUsdc1: {tUsdcToUsdc1()}
tUsdcToUsdc2: {tUsdcToUsdc2()}
""")
    # assert lenderApr1() == lenderApr2(), "lenderApr mismatch"
    # assert tUsdcToUsdc1() == tUsdcToUsdc2(), "tUsdcToUsdc mismatch"
    # assert tUsdcSupply1 == tUsdcSupply2, "tUsdcSupply mismatch"


def deposit(amount):
    global tUsdcSupply1, tUsdcSupply2, deposits
    print(f"A user deposits {amount} Usdc.")
    tUsdcSupply1 += amount / tUsdcToUsdc1()
    tUsdcSupply2 += amount / tUsdcToUsdc2()
    deposits += amount  # update this last

    # Log
    printAndValidate()


def borrow(amount, rate):
    global outstandingDebt, interestOwed
    print(f"A user borrows {amount} Usdc at {rate * 100}%.")
    outstandingDebt += amount
    interestOwed += rate * amount

    # Log
    printAndValidate()


printAndValidate()

# User deposits 150 Usdc
deposit(150)

# User deposits 50 Usdc
deposit(50)

# User borrows 100 Usdc at 10%
borrow(100, 0.1)
