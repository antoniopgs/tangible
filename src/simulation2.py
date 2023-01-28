import random
import matplotlib.pyplot as plt

class Tangible:

    def __init__(self):

        # System Vars
        self.outstanding_debt = 0
        self.interest_owed = 0
        self.deposits = 0
        self.tUsdc_supply_1 = 0
        self.tUsdc_supply_2 = 0
        self.loan_years = 5
        self.time_elapsed = 0

        # Interest Model Vars
        self.optimal_utilization = 0.9
        self.m1 = 0.04
        self.b1 = 0.02
        self.m2 = 1
        self.b2 = self.optimal_utilization * (self.m1 - self.m2) + self.b1

        # Storage
        self.scheduled_repayments = {}

        # Chart Data
        self.x_axis = []
        self.y_axis = []

    # User Actions
    def deposit(self, amount):
        print(f"A user deposits {amount} Usdc.")
        self.tUsdc_supply_1 += amount / self.tUsdcToUsdc1()
        self.tUsdc_supply_2 += amount / self.tUsdcToUsdc2()
        self.deposits += amount  # update this last

    def withdraw(self, amount):
        available_liquidity = self.deposits - self.outstanding_debt
        assert available_liquidity >= 0, f"available_liquidity cannot be negative {self.deposits} {self.outstanding_debt}"
        assert amount <= available_liquidity, "not enough liquidity available"
        print(f"A user withdraws {amount} Usdc.")
        self.tUsdc_supply_1 -= amount / self.tUsdcToUsdc1()
        self.tUsdc_supply_2 -= amount / self.tUsdcToUsdc2()
        self.deposits -= amount

    def start_loan(self, principal):
        available_liquidity = self.deposits - self.outstanding_debt
        assert available_liquidity >= 0, f"available_liquidity cannot be negative {self.deposits} {self.outstanding_debt}"
        assert principal <= available_liquidity, "not enough liquidity available"
        yearly_rate = self.new_borrower_rate()
        print(f"A user starts a loan of {principal} Usdc at {yearly_rate}.")
        monthly_rate = yearly_rate / 12
        self.outstanding_debt += principal
        self.interest_owed += monthly_rate * principal
        monthly_payment = self.calculate_monthly_payment(
            principal, monthly_rate)
        print(f"calculated monthly payment: {monthly_payment}")
        self.scheduled_repayments[self.time_elapsed + (30 * 24 * 60 * 60)] = {
            "monthly_payment": monthly_payment,
            "monthly_rate": monthly_rate,
            "balance": principal,
        }

    def pay_loan(self):
        loan = self.scheduled_repayments[self.time_elapsed]
        payment = loan["monthly_payment"]  # keep it simple for now
        print(f"A borrower pays {payment} Usdc for his loan")
        assert payment >= loan[
            "monthly_payment"], "payment must be >= monthly_payment"
        interest = loan["monthly_rate"] * loan["balance"]
        repayment = payment - interest
        loan["balance"] -= repayment
        self.outstanding_debt -= repayment
        self.deposits += interest
        self.interest_owed -= loan["monthly_rate"] * repayment
        self.scheduled_repayments.pop(self.time_elapsed)
        self.scheduled_repayments[self.time_elapsed + (30 * 24 * 60 * 60)] = {
            "monthly_payment": loan["monthly_payment"],
            "monthly_rate": loan["monthly_rate"],
            "balance": loan["balance"]
        }

    # System Functions
    def utilization(self):
        try:
            assert self.outstanding_debt <= self.deposits, "utilization can't exceed 1"
            return self.outstanding_debt / self.deposits
        except ZeroDivisionError:
            return 0

    def new_borrower_rate(self):
        utilization = self.utilization()
        if utilization <= self.optimal_utilization:
            return (self.m1 * utilization) + self.b1
        else:
            return (self.m2 * utilization) + self.b2

    def borrower_rate_weighted_avg(self):
        try:
            return self.interest_owed / self.outstanding_debt
        except ZeroDivisionError:
            return 0

    def lenderApr1(self):
        try:
            return self.interest_owed / self.deposits
        except ZeroDivisionError:
            return 0

    def lenderApr2(self):
        return self.utilization() * self.borrower_rate_weighted_avg()

    def tUsdcToUsdc1(self):
        if self.tUsdc_supply_1 == 0:
            return 1
        else:
            return (self.deposits + self.interest_owed) / self.tUsdc_supply_1

    def tUsdcToUsdc2(self):
        if self.tUsdc_supply_2 == 0:
            return 1
        else:
            return 1 + (self.interest_owed / self.tUsdc_supply_2)

    def calculate_monthly_payment(self, principal, monthly_rate):
        months_count = self.loan_years * 12
        r = 1 / (1 + monthly_rate)
        return principal * ((1 - r) / r - (r**(months_count + 1)))

    # Utils
    def logSystem(self):
        print(f"""
----- SYSTEM LOG -----
outstandingDebt: {self.outstanding_debt}$
interestOwed: {self.interest_owed}$
deposits: {self.deposits}$
tUsdcSupply1: {self.tUsdc_supply_1}
tUsdcSupply2: {self.tUsdc_supply_2}
utilization: {self.utilization()}
weightedAvgBorrowerRate: {self.borrower_rate_weighted_avg()}
lenderApr1: {self.lenderApr1()}
lenderApr2: {self.lenderApr2()}
tUsdcToUsdc1: {self.tUsdcToUsdc1()}
tUsdcToUsdc2: {self.tUsdcToUsdc2()}
""")

    # assert lenderApr1() == lenderApr2(), "lenderApr mismatch"
    # assert tUsdcToUsdc1() == tUsdcToUsdc2(), "tUsdcToUsdc mismatch"
    # assert tUsdcSupply1 == tUsdcSupply2, "tUsdcSupply mismatch"

    # Randomness
    def deposit_likelihood(self):
        d1 = 10
        d2 = 0
        return d1 * self.lenderApr1() + d2

    def withdraw_likelihood(self):
        w1 = -10
        w2 = 1
        return w1 * self.lenderApr1() + w2

    def start_loan_likelihood(self):
        s1 = -10
        s2 = 1
        return s1 * self.new_borrower_rate() + s2

    def trigger_random_event(self):
        event = random.choices(["deposit", "withdraw", "start_loan"],
                               weights=[
                                   self.deposit_likelihood(),
                                   self.withdraw_likelihood(),
                                   self.start_loan_likelihood()
                               ])[0]
        if event == "deposit":
            amount = random.randint(0, 1000)
            self.deposit(amount)
        elif event == "withdraw":
            available_liquidity = self.deposits - self.outstanding_debt
            assert available_liquidity >= 0, f"available_liquidity cannot be negative {self.deposits} {self.outstanding_debt}"
            amount = random.randint(
                0, available_liquidity)  # account for utilization rise later
            self.withdraw(amount)
        elif event == "start_loan":
            available_liquidity = self.deposits - self.outstanding_debt
            assert available_liquidity >= 0, f"available_liquidity cannot be negative {self.deposits} {self.outstanding_debt}"
            avg_principal = 50_000
            if avg_principal <= available_liquidity:
                self.start_loan(avg_principal)

    def simulate(self, years):

        self.deposit(10_000_000);

        total_seconds = years * 365 * 24 * 60 * 60
        while self.time_elapsed < total_seconds:

            self.logSystem()

            # If a payment is due
            if self.time_elapsed in self.scheduled_repayments:
                self.pay_loan()
            else:
                # Trigger Randomness
                self.trigger_random_event()

            # Store Data
            self.x_axis.append(self.time_elapsed)
            self.y_axis.append(self.utilization())

            # Skip random time (at max until next payment)
            one_week = 7 * 24 * 60 * 60
            sorted_payment_times = sorted(
                [time for time in self.scheduled_repayments])
            if len(sorted_payment_times) > 0:
                next_payment_time = sorted_payment_times[0]
                next_payment_time_delta = next_payment_time - self.time_elapsed
                self.time_elapsed += random.randint(1, next_payment_time_delta)
            else:
                self.time_elapsed += random.randint(1, one_week)

        # Make Plot
        plt.plot(self.x_axis, self.y_axis)
        plt.title('Utilization over Time')
        plt.xlabel('Time Elapsed')
        plt.ylabel('Utilization')
        plt.show()


# Simulate for 5 years
Tangible().simulate(5)  # might have to fix the weights of random.choices
