// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

contract BorrowingV2 {

    // Borrowing vars
    uint private periodsPerYear = 365 days; // means 1 period = 1 second
    uint maxPeriodsBetweenPayments = 30 days;

    // Structs
    struct Loan {
        UD60x18 periodicRate;
        uint periodicPayment;
        uint unpaidPrincipal;
        uint maxUnpaidInterest;
        uint startTime;
        uint lastPaymentTime;
    }

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
        uint periodCount = yearsCount * periodsPerYear;

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
            lastPaymentTime: block.timestamp, // Note: so loan starts accruing from now (not a payment)
            periodicPayment: periodicPayment,
            startTime: block.timestamp
        });

        // Update pool
        totalPrincipal += principal;
        totalInterestOwed += maxUnpaidInterest;
    }

    function payLoan(uint tokenId, uint payment) external {

        // Load loan
        Loan storage loan = loans[tokenId];

        // Calculate accruedRate
        UD60x18 accruedRate = loan.periodicRate.mul(toUD60x18(periodsSinceLastPayment(tokenId)));

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

    // Borrowers can pay off loans faster (by paying more/earlier), but there should be a minimum pay off speed: function unpaidPrincipalCap
    // At the slowest, every month the borrower must at least pay: ks

    // Renaming:
    // i0 -> month0UnpaidInterestCap (or initialUnpaidInterest)
    // p1 -> month1UnpaidPrincipalCap
    // r -> ratePerSecond
    // k -> avgPaymentPerSecond
    // s -> secondsIn30Days

    // So after 1 month:
    // i1 = i0 - rsp0
    // p1 = p0 - (ks - i1) <=> p0 - ks + i1 <=> p0 - ks + i0 - rsp0

    // So after 2 months:
    // i2 = i1 - rsp1 <=> i0 - rsp0 - rs(p0 -ks + i0 - rsp0) <=> i0 - 2rsp0 + krs^2 - rsi0 + p0r^2s^2
    // p2 = p1 - (ks - i2) <=> p1 -ks + i2 <=> p0 -ks + i0 - rsp0 -ks + i0 - rsp0 - rs(p0 -ks + i0 - rsp0) <=> p0 -2ks + 2i0 - 3rsp0 +rks^2 - rsi0 + p0r^2s^2

    // So after 3 months:
    // i3 = i2 - rsp2 <=> i0 - 3rsp0 - 3rsi0 + 3krs^2 + 4p0r^2s^2 - ks^3r^2 + i0r^2s^2 - p0r^3s^3
    // p3 = 
    function defaulted(Loan memory loan) private view returns(bool) {
        
        // Question: which one of these should I use?
        // return loanMonthMaxUnpaidInterestCap(loan).lt(loan.maxUnpaidInterest);
        return unpaidPrincipalCap(loan) < loan.unpaidPrincipal;
    }

    // Note: should be equal to tusdcSupply / totalDeposits
    function lenderApy() external view returns(uint) {
        return totalInterestOwed / totalDeposits;
    }

    function periodsSinceLastPayment(/* Loan memory loan */ uint tokenId) /* private */ public view returns(uint) {
        Loan memory loan = loans[tokenId];
        return block.timestamp - loan.lastPaymentTime;
    }

    function borrowerApr(uint /* utilization */) public /* view */ pure returns (UD60x18) {
        return toUD60x18(5).div(toUD60x18(100)); // 5%
    }

    function _periodicRate() private view returns(UD60x18) {
        return borrowerApr(utilization()).div(toUD60x18(periodsPerYear));
    }

    function calculatePeriodicPayment(uint principal, UD60x18 periodicRate, uint periodCount) private pure returns(uint) {

        // Calculate x
        UD60x18 x = toUD60x18(1).add(periodicRate).powu(periodCount);
        
        // Calculate avgPaymentPerSecond
        return fromUD60x18(toUD60x18(principal).mul(periodicRate).mul(x).div(x.sub(toUD60x18(1))));
    }

    // function loanMonthMaxUnpaidInterestCap(Loan memory loan) private view returns(UD60x18) {
    //     return loan.initialMaxUnpaidInterest.sub(toUD60x18(loanCompletedMonths(loan)).mul(toUD60x18(30 days).mul(loan.ratePerSecond)));
    // }

    // why is this not using any loan tickover?
    function unpaidPrincipalCap(Loan memory loan) private view returns(uint) {
        uint minPayment = maxPeriodsBetweenPayments * loan.periodicPayment;
        UD60x18 maxRate = toUD60x18(maxPeriodsBetweenPayments).mul(loan.periodicRate);
        uint maxInterest = fromUD60x18(maxRate.mul(toUD60x18(loan.unpaidPrincipal)));
        uint minRepayment = minPayment - maxInterest;
        return loan.unpaidPrincipal - minRepayment;
    }

    // Note: should truncate on purpose, so that it enforces payment after 30 days, but not every second
    function loanCompletedMonths(Loan memory loan) private view returns(uint) {
        return (block.timestamp - loan.startTime) / 30 days;
    }

    function minimumPayment(uint tokenId) external view returns (uint) {

        // Get loan
        Loan memory loan = loans[tokenId];

        // Calculate accruedRate
        UD60x18 accruedRate = loan.periodicRate.mul(toUD60x18(periodsSinceLastPayment(tokenId)));

        // Calculate interest
        uint interest = fromUD60x18(accruedRate.mul(toUD60x18(loan.unpaidPrincipal)));

        // Return interest as minimumPayment
        return interest;
    }
}
