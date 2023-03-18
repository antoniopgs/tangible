// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

contract BorrowingV2 {

    // Borrowing terms
    uint public loanMaxYears = 5;

    // Structs
    struct Loan {
        UD60x18 ratePerSecond;
        UD60x18 unpaidPrincipal;
        UD60x18 maxUnpaidInterest;
        uint lastPaymentTime;
        UD60x18 principal;
        UD60x18 avgPaymentPerSecond;
        uint startTime;
    }

    // Pool vars
    UD60x18 totalPrincipal;
    UD60x18 totalDeposits;
    UD60x18 totalInterestOwed;

    // Loan storage
    mapping(uint => Loan) public loans;

    // Functions
    function deposit(uint usdc) external {
        totalDeposits = totalDeposits.add(toUD60x18(usdc));
    }

    function withdraw(uint usdc) external {
        totalDeposits = totalDeposits.sub(toUD60x18(usdc));
        require(totalPrincipal.lte(totalDeposits), "utilization can't exceed 100%");
    }

    function startLoan(uint tokenId, uint principal) external { // Note: principal should be uint (not UD60x18)

        // Calculate loanRatePerSecond
        UD60x18 loanRatePerSecond = borrowerRatePerSecond();

        // Calculate loanMaxSeconds
        uint loanMaxSeconds = loanMaxYears * 365 days;

        // Calculate avgPaymentPerSecond
        UD60x18 _avgPaymentPerSecond = avgPaymentPerSecond(toUD60x18(principal), loanRatePerSecond, loanMaxSeconds);

        // Calculate loanMaxCost
        UD60x18 loanMaxCost = _avgPaymentPerSecond.mul(toUD60x18(loanMaxSeconds));

        // Calculate loanMaxUnpaidInterest
        UD60x18 loanMaxUnpaidInterest = loanMaxCost.sub(toUD60x18(principal));

        // Store Loan
        loans[tokenId] = Loan({
            ratePerSecond: borrowerRatePerSecond(),
            unpaidPrincipal: toUD60x18(principal),
            maxUnpaidInterest: loanMaxUnpaidInterest,
            lastPaymentTime: block.timestamp, // Note: so loan starts accruing from now (not a payment)
            principal: toUD60x18(principal),
            avgPaymentPerSecond: _avgPaymentPerSecond,
            startTime: block.timestamp
        });

        // Update pool
        totalPrincipal = totalPrincipal.add(toUD60x18(principal));
        totalInterestOwed = totalInterestOwed.add(loanMaxUnpaidInterest);
    }

    function payLoan(uint tokenId, uint payment) external {

        // Load loan
        Loan storage loan = loans[tokenId];

        // Calculate accruedRate
        UD60x18 accruedRate = loan.ratePerSecond.mul(toUD60x18(timeDeltaSinceLastPayment(tokenId)));

        // Calculate interest
        UD60x18 interest = accruedRate.mul(loan.unpaidPrincipal);

        // Calculate repayment
        require(toUD60x18(payment).gte(interest), "payment must be >= interest");
        UD60x18 repayment = toUD60x18(payment).sub(interest);

        // Update loan
        loan.unpaidPrincipal = loan.unpaidPrincipal.sub(repayment);
        loan.maxUnpaidInterest = loan.maxUnpaidInterest.sub(interest);
        loan.lastPaymentTime = block.timestamp;

        // Update pool
        totalPrincipal = totalPrincipal.sub(repayment);
        totalDeposits = totalDeposits.add(interest);
        totalInterestOwed = totalInterestOwed.sub(interest);
    }

    function redeem(uint tokenId) external {
        
        // Get Loan
        Loan storage loan = loans[tokenId];

        // require(defaulted(loan), "no default");

        // Calculate defaulterDebt
        UD60x18 defaulterDebt = loan.unpaidPrincipal.add(loan.maxUnpaidInterest); // Question: charge redeemer all the interest? or only interest accrued until now?

        // Redeem (pull defaulter's entire debt)
        // USDC.safeTransferFrom(loan.borrower, address(this), fromUD60x18(defaulterDebt));

        // Update pool
        totalPrincipal = totalPrincipal.sub(loan.unpaidPrincipal);
        totalDeposits = totalDeposits.add(loan.maxUnpaidInterest);
        totalInterestOwed = totalInterestOwed.sub(loan.maxUnpaidInterest);

        // Zero-out loan (only need to zero-out borrower address)
        // loan.borrower = address(0);
    }

    function foreclose(Loan memory loan, uint salePrice) external {

        // require(defaulted(loan) + 45 days, "not foreclosurable");

        // Update pool
        totalPrincipal = totalPrincipal.sub(loan.unpaidPrincipal);
        totalDeposits = totalDeposits.add(loan.maxUnpaidInterest);
        totalInterestOwed = totalInterestOwed.sub(loan.maxUnpaidInterest);

        // Calculate defaulterDebt
        UD60x18 defaulterDebt = loan.unpaidPrincipal.add(loan.maxUnpaidInterest); // Question: charge redeemer all the interest? or only interest accrued until now?

        // Calculate defaulterEquity
        UD60x18 defaulterEquity = toUD60x18(salePrice).sub(defaulterDebt);
    }

    // Views
    function utilization() public view returns (UD60x18) {
        return totalPrincipal.div(totalDeposits);
    }

    // Borrowers can pay off loans faster (by paying more/earlier), but there should be a minimum pay off speed: function unpaidPrincipalCap
    // At the slowest, every month the borrower must at least pay: 30 days * avgPaymentPerSecond
    //  - interest = (30 days * ratePerSecond) * unpaidPrincipal
    //  - repayment = (30 days * avgPaymentPerSecond) - interest
    // So after 1 month:
    //  - maxUnpaidInterestCap1 = unpaidInterest0 - 30 days * ratePerSecond * unpaidPrincipal0
    //  - unpaidPrincipalCap1 = unpaidPrincipal0 - (30 days * avgPaymentPerSecond) + (30 days * ratePerSecond * unpaidPrincipal0)
    // So after 2 months:
    //  - maxUnpaidInterestCap2 = maxUnpaidInterestCap1 - 30 days * ratePerSecond * unpaidPrincipalCap1
    //  - unpaidPrincipalCap2 = unpaidPrincipalCap1 - (30 days * avgPaymentPerSecond) + (30 days * ratePerSecond * unpaidPrincipalCap1)
    // Replacing in after 2 months:
    //  - maxUnpaidInterestCap2 = unpaidInterest0 - 30 days * ratePerSecond * unpaidPrincipal0 - 30 days * ratePerSecond * unpaidPrincipal0 - (30 days * avgPaymentPerSecond) + (30 days * ratePerSecond * unpaidPrincipal0)
    //  - unpaidPrincipalCap2 = unpaidPrincipal0 - (30 days * avgPaymentPerSecond) + (30 days * ratePerSecond * unpaidPrincipal0) - (30 days * avgPaymentPerSecond) + (30 days * ratePerSecond * unpaidPrincipal0 - (30 days * avgPaymentPerSecond) + (30 days * ratePerSecond * unpaidPrincipal0))
    // Simplifying after 2 months:
    //  - maxUnpaidInterestCap2 = unpaidInterest0 - 30 days((ratePerSecond * unpaidPrincipal0) - (avgPaymentPerSecond))
    //  - unpaidPrincipalCap2 = unpaidPrincipal0 - 30 days(3(avgPaymentPerSecond + (ratePerSecond * unpaidPrincipal0))
    function defaulted(Loan memory loan) private view returns(bool) {
        
        // Question: which one of these should I use?
        // return loanMonthMaxUnpaidInterestCap(loan).lt(loan.maxUnpaidInterest);
        return unpaidPrincipalCap(loan).lt(loan.unpaidPrincipal);
    }

    // Note: should be equal to tusdcSupply / totalDeposits
    function lenderApy() external view returns(UD60x18) {
        return totalInterestOwed.div(totalDeposits);
    }

    function timeDeltaSinceLastPayment(/* Loan memory loan */ uint tokenId) /* private */ public view returns(uint) {
        Loan memory loan = loans[tokenId];
        return block.timestamp - loan.lastPaymentTime;
    }

    function borrowerApr(UD60x18 /* utilization */) public /* view */ pure returns (UD60x18) {
        return toUD60x18(5).div(toUD60x18(100)); // 5%
    }

    function borrowerRatePerSecond() private view returns(UD60x18) {
        return borrowerApr(utilization()).div(toUD60x18(365 days));
    }

    function avgPaymentPerSecond(UD60x18 principal, UD60x18 ratePerSecond, uint loanMaxSeconds) private pure returns(UD60x18) {

        // Calculate x
        UD60x18 x = toUD60x18(1).add(ratePerSecond).powu(loanMaxSeconds);
        
        // Calculate avgPaymentPerSecond
        return principal.mul(ratePerSecond).mul(x).div(x.sub(toUD60x18(1)));
    }

    // function loanMonthMaxUnpaidInterestCap(Loan memory loan) private view returns(UD60x18) {
    //     return loan.initialMaxUnpaidInterest.sub(toUD60x18(loanCompletedMonths(loan)).mul(toUD60x18(30 days).mul(loan.ratePerSecond)));
    // }

    // why is this not using any loan tickover?
    function unpaidPrincipalCap(Loan memory loan) private pure returns(UD60x18) {
        UD60x18 minPayment = toUD60x18(30 days).mul(loan.avgPaymentPerSecond);
        UD60x18 minRate = toUD60x18(30 days).mul(loan.ratePerSecond);
        UD60x18 minInterest = minRate.mul(loan.unpaidPrincipal);
        UD60x18 minRepayment = (minPayment).sub(minInterest);
        return loan.unpaidPrincipal.sub(minRepayment);
    }

    // Note: should truncate on purpose, so that it enforces payment after 30 days, but not every second
    function loanCompletedMonths(Loan memory loan) private view returns(uint) {
        return (block.timestamp - loan.startTime) / 30 days;
    }

    function minimumPayment(uint tokenId) external view returns (uint) {

        // Get loan
        Loan memory loan = loans[tokenId];

        // Calculate accruedRate
        UD60x18 accruedRate = loan.ratePerSecond.mul(toUD60x18(timeDeltaSinceLastPayment(tokenId)));

        // Calculate interest
        UD60x18 interest = accruedRate.mul(loan.unpaidPrincipal);

        // Return interest as minimumPayment
        return fromUD60x18(interest);
    }
}
