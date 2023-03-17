// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";
import "forge-std/console.sol";

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

        console.log(1);

        // Calculate loanRatePerSecond
        UD60x18 loanRatePerSecond = borrowerRatePerSecond();

        console.log(2);

        // Calculate loanMaxSeconds
        uint loanMaxSeconds = loanMaxYears * 365 days;

        console.log(3);

        // Calculate avgPaymentPerSecond
        UD60x18 _avgPaymentPerSecond = avgPaymentPerSecond(toUD60x18(principal), loanRatePerSecond, loanMaxSeconds);

        console.log(4);

        // Calculate loanMaxCost
        UD60x18 loanMaxCost = _avgPaymentPerSecond.mul(toUD60x18(loanMaxSeconds));

        console.log(5);

        // Calculate loanMaxUnpaidInterest
        UD60x18 loanMaxUnpaidInterest = loanMaxCost.sub(toUD60x18(principal));

        console.log(6);

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

        console.log(7);

        // Update pool
        totalPrincipal = totalPrincipal.add(toUD60x18(principal));
        console.log(8);
        totalInterestOwed = totalInterestOwed.add(loanMaxUnpaidInterest);
        console.log(9);
    }
    
    function payLoan(uint tokenId, uint payment) external {

        console.log(11);

        // Load loan
        Loan storage loan = loans[tokenId];

        console.log(22);

        // Calculate accruedRate
        UD60x18 accruedRate = loan.ratePerSecond.mul(toUD60x18(timeDeltaSinceLastPayment(tokenId)));

        console.log(33);

        // Calculate interest
        UD60x18 interest = accruedRate.mul(loan.unpaidPrincipal);

        console.log(44);

        // Calculate repayment
        console.log("payment:", payment);
        console.log("UD60x18.unwrap(interest)", UD60x18.unwrap(interest));
        require(toUD60x18(payment).gte(interest), "payment must be >= interest");
        UD60x18 repayment = toUD60x18(payment).sub(interest);

        console.log(55);

        // Update loan
        console.log("UD60x18.unwrap(loan.unpaidPrincipal):", UD60x18.unwrap(loan.unpaidPrincipal));
        console.log("UD60x18.unwrap(repayment)", UD60x18.unwrap(repayment));
        loan.unpaidPrincipal = loan.unpaidPrincipal.sub(repayment);
        console.log(551);
        loan.maxUnpaidInterest = loan.maxUnpaidInterest.sub(interest);
        console.log(552);
        loan.lastPaymentTime = block.timestamp;

        console.log(66);

        // Update pool
        totalPrincipal = totalPrincipal.sub(repayment);
        totalDeposits = totalDeposits.add(interest);
        totalInterestOwed = totalInterestOwed.sub(interest);
        
        console.log(77);
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

    // If borrower paid avgPaymentPerSecond every second:
    //  - each payment's interest would be: ratePerSecond * 1s = ratePerSecond
    //  - each payment's repayment would be: avgPaymentPerSecond - ratePerSecond
    // So each second:
    //  - loan.maxUnpaidInterest -= ratePerSecond
    //  - loan.unpaidPrincipal -= avgPaymentPerSecond - ratePerSecond
    // So 30 days later:
    //  - loan.maxUnpaidInterest -= 30 days(ratePerSecond);
    //  - loan.unpaidPrincipal -= 30 days(avgPaymentPerSecond - ratePerSecond);
    // Don't think an early/bigger payment should anticipate the rest of the payments. should probably calculate all deadlines off the 1st one
    // So, at the end of month 1:
    //  - loan.month1EndMaxUnpaidInterest = loan.initialMaxUnpaidInterest - 30 days(ratePerSecond)
    //  - loan.month1EndMaxUnpaidPrincipal = loan.principal - 30 days(avgPaymentPerSecond - ratePerSecond)
    // So, at the end of month 7:
    //  - loan.month7EndMaxUnpaidInterest = loan.initialMaxUnpaidInterest - 7(30 days(ratePerSecond))
    //  - loan.month7EndMaxUnpaidPrincipal = loan.principal - 7(30 days(avgPaymentPerSecond - ratePerSecond))
    // So, at the end of month n:
    //  - loan.monthNEndMaxUnpaidInterest = loan.initialMaxUnpaidInterest - n(30 days(ratePerSecond))
    //  - loan.monthNEndMaxUnpaidPrincipal = loan.principal - n(30 days(avgPaymentPerSecond - ratePerSecond))
    function defaulted(Loan memory loan) private view returns(bool) {
        
        // Question: which one of these should I use?
        // return loanMonthMaxUnpaidInterestCap(loan).lt(loan.maxUnpaidInterest);
        return loanMonthUnpaidPrincipalCap(loan).lt(loan.unpaidPrincipal);
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

    function loanMonthUnpaidPrincipalCap(Loan memory loan) private view returns(UD60x18) {
        return loan.principal.sub(toUD60x18(loanCompletedMonths(loan)).mul(toUD60x18(30 days).mul(loan.avgPaymentPerSecond.sub(loan.ratePerSecond))));
    }

    // Note: should truncate on purpose, so that it enforces payment after 30 days, but not every second
    function loanCompletedMonths(Loan memory loan) private view returns(uint) {
        return (block.timestamp - loan.startTime) / 30 days;
    }

    function minimumPayment(uint tokenId) external view returns (uint) {

        // Get loan
        Loan memory loan = loans[tokenId];

        console.log("rate per second:", UD60x18.unwrap(loan.ratePerSecond));
        console.log("timeDelta:", timeDeltaSinceLastPayment(tokenId));

        // Calculate accruedRate
        UD60x18 accruedRate = loan.ratePerSecond.mul(toUD60x18(timeDeltaSinceLastPayment(tokenId)));

        console.log("accruedRate", UD60x18.unwrap(accruedRate));

        // Calculate interest
        UD60x18 interest = accruedRate.mul(loan.unpaidPrincipal);

        console.log("interest", UD60x18.unwrap(interest));

        // Return interest as minimumPayment
        return fromUD60x18(interest);
    }
}
