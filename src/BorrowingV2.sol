// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

contract BorrowingV2 {

    // Structs
    struct Loan {
        UD60x18 periodicRate;
        uint unpaidPrincipal;
        uint maxUnpaidInterest;
        uint lastPaymentTime;
    }

    struct TimeConfig {
        uint periodsPerYear;
        uint periodLengthSeconds;
    }

    // Time Config
    TimeConfig private timeConfig = TimeConfig({ periodsPerYear: 365 days, periodLengthSeconds: 1 seconds });
    // TimeConfig private timeConfig = TimeConfig({ periodsPerYear: 12, periodLengthSeconds: 30 days });

    // Borrowing terms
    uint private maxPaymentGapSeconds = 30 days;

    // Pool vars
    uint totalPrincipal;
    uint totalDeposits;
    uint totalInterestOwed;

    // Loan storage
    mapping(uint => Loan) public loans;

    // Functions
    function deposit(uint usdc) external {
        totalDeposits += usdc;
    }

    function withdraw(uint usdc) external {
        totalDeposits -= usdc;
        require(totalPrincipal <= totalDeposits, "utilization can't exceed 100%");
    }

    function startLoan(uint tokenId, uint principal, uint yearsCount) external { // Note: principal should be uint (not UD60x18)

        // Calculate periodicRate
        UD60x18 periodicRate = _periodicRate();

        // Calculate periodCount
        uint periodCount = yearsCount * timeConfig.periodsPerYear;

        // Calculate periodicPayment
        uint periodicPayment = calculatePeriodicPayment(principal, periodicRate, periodCount);

        // Calculate maxCost
        uint maxCost = periodicPayment * periodCount;

        // Calculate maxUnpaidInterest
        uint maxUnpaidInterest = maxCost - principal;

        // Store Loan
        loans[tokenId] = Loan({
            periodicRate: periodicRate,
            unpaidPrincipal: principal,
            maxUnpaidInterest: maxUnpaidInterest,
            lastPaymentTime: block.timestamp // Note: so loan starts accruing from now (not a payment)
        });

        // Update pool
        totalPrincipal += principal;
        totalInterestOwed += maxUnpaidInterest;
    }

    function payLoan(uint tokenId, uint payment) external {

        // Load loan
        Loan storage loan = loans[tokenId];

        // Calculate accruedRate
        UD60x18 accruedRate = loan.periodicRate.mul(toUD60x18(periodsSinceLastPayment(loan)));

        // Calculate interest
        uint interest = fromUD60x18(accruedRate.mul(toUD60x18(loan.unpaidPrincipal)));

        // Calculate repayment
        require(payment >= interest, "payment must be >= interest");
        uint repayment = payment - interest;

        // Update loan
        loan.unpaidPrincipal -= repayment;
        loan.maxUnpaidInterest -= interest;
        loan.lastPaymentTime = block.timestamp;

        // Update pool
        totalPrincipal -= repayment;
        totalDeposits += interest;
        totalInterestOwed -= interest;
    }

    function redeem(uint tokenId) external {
        
        // Get Loan
        Loan storage loan = loans[tokenId];

        // require(defaulted(loan), "no default");

        // Calculate defaulterDebt
        uint defaulterDebt = loan.unpaidPrincipal + loan.maxUnpaidInterest; // Question: charge redeemer all the interest? or only interest accrued until now?

        // Redeem (pull defaulter's entire debt)
        // USDC.safeTransferFrom(loan.borrower, address(this), fromUD60x18(defaulterDebt));

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += loan.maxUnpaidInterest;
        totalInterestOwed -= loan.maxUnpaidInterest;

        // Zero-out loan (only need to zero-out borrower address)
        // loan.borrower = address(0);
    }

    function foreclose(Loan memory loan, uint salePrice) external {

        // require(defaulted(loan) + 45 days, "not foreclosurable");

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += loan.maxUnpaidInterest;
        totalInterestOwed -= loan.maxUnpaidInterest;

        // Calculate defaulterDebt
        uint defaulterDebt = loan.unpaidPrincipal + loan.maxUnpaidInterest; // Question: charge redeemer all the interest? or only interest accrued until now?

        // Calculate defaulterEquity
        uint defaulterEquity = salePrice - defaulterDebt;
    }

    // Views
    function utilization() public view returns (uint) {
        return totalPrincipal / totalDeposits;
    }

    function lenderApy() external view returns(uint) { // Note: should be equal to tusdcSupply / totalDeposits
        return totalInterestOwed / totalDeposits;
    }

    function defaulted(Loan memory loan) private view returns(bool) {
        return periodsSinceLastPayment(loan) > maxPeriodsBetweenPayments();
    }

    function periodsSinceLastPayment(Loan memory loan) private view returns(uint) {
        uint secondsSinceLastPayment = block.timestamp - loan.lastPaymentTime;
        return secondsSinceLastPayment / periodsPerSecond();
    }

    function borrowerApr(uint /* utilization */) public /* view */ pure returns (UD60x18) {
        return toUD60x18(5).div(toUD60x18(100)); // 5%
    }

    function _periodicRate() private view returns(UD60x18) {
        return borrowerApr(utilization()).div(toUD60x18(timeConfig.periodsPerYear));
    }

    function calculatePeriodicPayment(uint principal, UD60x18 periodicRate, uint periodCount) private pure returns(uint) {

        // Calculate x
        UD60x18 x = toUD60x18(1).add(periodicRate).powu(periodCount);
        
        // Calculate periodicPayment
        return fromUD60x18(toUD60x18(principal).mul(periodicRate).mul(x).div(x.sub(toUD60x18(1))));
    }

    function periodsPerSecond() private view returns(uint) {
        return 1 / timeConfig.periodLengthSeconds;
    }

    function maxPeriodsBetweenPayments() private view returns(uint) {
        return maxPaymentGapSeconds * periodsPerSecond();
    }
}
