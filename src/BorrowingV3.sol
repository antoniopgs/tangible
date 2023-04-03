// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18, toUD60x18, fromUD60x18 } from "@prb/math/UD60x18.sol";
import { SD59x18, toSD59x18 } from "@prb/math/SD59x18.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./tUsdc.sol";

contract BorrowingV3 is Initializable {

    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // Note: ethereum mainnet
    tUsdc tUSDC;

    // Time constants
    uint public constant yearSeconds = 365 days;
    uint private constant yearMonths = 12;
    uint private constant monthSeconds = yearSeconds / yearMonths; // Note: yearSeconds % yearMonths = 0 (no precision loss)
    
    // Structs
    struct Loan {
        address borrower;
        UD60x18 ratePerSecond;
        UD60x18 paymentPerSecond;
        uint startTime;
        uint unpaidPrincipal;
        uint maxUnpaidInterest;
        uint maxDurationSeconds;
        uint lastPaymentTime;
    }

    // Pool vars
    uint public totalPrincipal;
    uint public totalDeposits;
    uint public maxTotalInterestOwed;

    // Loan storage
    mapping(uint => Loan) public loans;

    // Libs
    using SafeERC20 for IERC20;

    function initialize(tUsdc _tUSDC) external initializer {
        tUSDC = _tUSDC;
    }

    function deposit(uint usdc) external {
        
        // Pull usdc from depositor
        USDC.safeTransferFrom(msg.sender, address(this), usdc);

        // Update pool
        totalDeposits += usdc;
        
        // Calulate depositor tUsdc
        uint _tUsdc = usdcToTUsdc(usdc);

        // Mint tUsdc to depositor
        tUSDC.operatorMint(msg.sender, _tUsdc);
    }

    function withdraw(uint usdc) external {

        // Calulate withdrawer tUsdc
        uint _tUsdc = usdcToTUsdc(usdc);

        // Burn withdrawer tUsdc
        tUSDC.operatorBurn(msg.sender, _tUsdc, "", "");

        // Update pool
        totalDeposits -= usdc;
        require(totalPrincipal <= totalDeposits, "utilization can't exceed 100%");

        // Send usdc to withdrawer
        USDC.safeTransfer(msg.sender, usdc);
    }

    // Functions
    function startLoan(uint tokenId, uint principal, uint borrowerAprPct, uint maxDurationYears) external {
        require(principal <= availableLiquidity(), "principal must be <= availableLiquidity");

        // Calculate ratePerSecond
        UD60x18 ratePerSecond = toUD60x18(borrowerAprPct).div(toUD60x18(100)).div(toUD60x18(yearSeconds));

        // Calculate maxDurationSeconds
        uint maxDurationSeconds = maxDurationYears * yearSeconds;

        // Calculate paymentPerSecond
        UD60x18 paymentPerSecond = calculatePaymentPerSecond(principal, ratePerSecond, maxDurationSeconds);

        // Calculate maxCost
        uint maxCost = fromUD60x18(paymentPerSecond.mul(toUD60x18(maxDurationSeconds)));

        // Calculate maxUnpaidInterest
        uint maxUnpaidInterest = maxCost - principal;
        
        loans[tokenId] = Loan({
            borrower: msg.sender,
            ratePerSecond: ratePerSecond,
            paymentPerSecond: paymentPerSecond,
            startTime: block.timestamp,
            unpaidPrincipal: principal,
            maxUnpaidInterest: maxUnpaidInterest,
            maxDurationSeconds: maxDurationSeconds,
            lastPaymentTime: block.timestamp // Note: no payment here, but needed so lastPaymentElapsedSeconds only counts from now
        });

        // Update pool
        totalPrincipal += principal;
        maxTotalInterestOwed += maxUnpaidInterest;
    }

    function payLoan(uint tokenId, uint payment) external {
        require(!defaulted(tokenId), "can't pay loan after defaulting");

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Calculate interest
        uint interest = accruedInterest(loan);
        //require(payment <= loan.unpaidPrincipal + interest, "payment must be <= unpaidPrincipal + interest");
        //require(payment => interest, "payment must be => interest"); // Question: maybe don't calculate repayment if payment < interest?

        // Calculate repayment
        uint repayment = payment - interest;

        // Update loan
        loan.unpaidPrincipal -= repayment;
        loan.maxUnpaidInterest -= interest;
        loan.lastPaymentTime = block.timestamp;

        // Update pool
        totalPrincipal -= repayment;
        totalDeposits += interest;
        maxTotalInterestOwed -= interest;

        // If loan is paid off
        if (loan.unpaidPrincipal == 0) {

            // Clear out loan
            loan.borrower = address(0);  
        }
    }

    function redeem(uint tokenId) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Ensure State == Default

        // Calculate interest
        uint interest = accruedInterest(loan);

        // Calculate defaulterDebt
        uint defaulterDebt = loan.unpaidPrincipal + interest;

        // Redeem (pull defaulter's entire debt)
        USDC.safeTransferFrom(msg.sender, address(this), defaulterDebt); // Note: anyone can redeem on behalf of defaulter

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;
        assert(interest < loan.maxUnpaidInterest);
        maxTotalInterestOwed -= loan.maxUnpaidInterest; // Note: maxTotalInterestOwed -= accruedInterest + any remaining unpaid interest (so can use loan.maxUnpaidInterest)

        // Clearout loan
    }

    function foreclose(uint tokenId, uint salePrice) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Ensure State == Foreclosurable

        // Calculate interest
        uint interest = accruedInterest(loan);

        // Calculate defaulterDebt
        uint defaulterDebt = loan.unpaidPrincipal + interest; // Todo: add fees later

        // Ensure salePrice covers defaulterDebt + fees
        require(salePrice >= defaulterDebt, "salePrice must >= defaulterDebt"); // Question: minSalePrice will rise over time. Too risky?

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;
        assert(interest < loan.maxUnpaidInterest);
        maxTotalInterestOwed -= loan.maxUnpaidInterest; // Note: maxTotalInterestOwed -= accruedInterest + any remaining unpaid interest (so can use loan.maxUnpaidInterest)

        // Calculate defaulterEquity
        uint defaulterEquity = salePrice - defaulterDebt;

        // Send defaulterEquity to defaulter
        USDC.safeTransfer(loan.borrower, defaulterEquity);

        // Clearout loan
    }
    
    // Public Views
    function defaulted(uint tokenId) public view returns(bool) {

        // Get loan
        Loan memory loan = loans[tokenId];

        // Get loanCompletedMonths
        uint _loanCompletedMonths = loanCompletedMonths(tokenId);

        // Calculate loanMaxDurationMonths
        uint loanMaxDurationMonths = loan.maxDurationSeconds / yearSeconds * yearMonths;

        // If loan exceeded allowed months
        if (_loanCompletedMonths > loanMaxDurationMonths) {
            return true;
        }

        return loan.unpaidPrincipal > principalCap(tokenId, _loanCompletedMonths);
    }

    function utilization() public view returns(UD60x18) {
        if (totalDeposits == 0) {
            assert(totalPrincipal == 0);
            return toUD60x18(0);
        }
        return toUD60x18(totalPrincipal).div(toUD60x18(totalDeposits));
    }

    function lenderApy() public view returns(UD60x18) {
        if (totalDeposits == 0) {
            assert(maxTotalInterestOwed == 0);
            return toUD60x18(0);
        }
        return toUD60x18(maxTotalInterestOwed).div(toUD60x18(totalDeposits)); // Question: is this missing auto-compounding?
    }

    // Other Views
    function principalCap(uint tokenId, uint month) public view returns(uint cap) {

        // Get loan
        Loan memory loan = loans[tokenId];

        // Ensure month doesn't exceed loanMaxDurationMonths
        uint loanMaxDurationMonths = loan.maxDurationSeconds / yearSeconds * yearMonths;
        require(month <= loanMaxDurationMonths, "month must be <= loanMaxDurationMonths");

        // Calculate elapsedSeconds
        uint elapsedSeconds = month * monthSeconds;

        // Calculate negExponent
        SD59x18 negExponent = toSD59x18(int(elapsedSeconds)).sub(toSD59x18(int(loan.maxDurationSeconds))).sub(toSD59x18(1));

        // Calculate numerator
        SD59x18 z = toSD59x18(1).sub(SD59x18.wrap(int(UD60x18.unwrap(toUD60x18(1).add(loan.ratePerSecond)))).pow(negExponent));
        UD60x18 numerator = UD60x18.wrap(uint(SD59x18.unwrap(SD59x18.wrap(int(UD60x18.unwrap(loan.paymentPerSecond))).mul(z))));

        // Calculate cap
        cap = fromUD60x18(numerator.div(loan.ratePerSecond));
    }

    function usdcToTUsdc(uint usdcAmount) public view returns(uint tUsdcAmount) {
        
        // Get tUsdcSupply
        uint tUsdcSupply = tUSDC.totalSupply();

        // If tUsdcSupply or totalDeposits = 0, 1:1
        if (tUsdcSupply == 0 || totalDeposits == 0) {
            return tUsdcAmount = usdcAmount;
        }

        // Calculate tUsdc
        return tUsdcAmount = usdcAmount * tUsdcSupply / totalDeposits;
    }

    // Note: truncates on purpose (to enforce payment after monthSeconds, but not every second)
    function loanCompletedMonths(uint tokenId) private view returns(uint) {
        Loan memory loan = loans[tokenId];
        return (block.timestamp - loan.startTime) / monthSeconds;
    }

    function calculatePaymentPerSecond(uint principal, UD60x18 ratePerSecond, uint maxDurationSeconds) /*private*/ public pure returns(UD60x18 paymentPerSecond) {

        // Calculate x
        UD60x18 x = toUD60x18(1).add(ratePerSecond).powu(maxDurationSeconds);
        
        // Calculate paymentPerSecond
        paymentPerSecond = toUD60x18(principal).mul(ratePerSecond).mul(x).div(x.sub(toUD60x18(1)));
    }

    function accruedInterest(Loan memory loan) private view returns(uint) {
        return fromUD60x18(toUD60x18(loan.unpaidPrincipal).mul(accruedRate(loan)));
    }

    function accruedInterest(uint tokenId) public view returns(uint) { // Note: made this duplicate of accruedInterest() for testing
        return accruedInterest(loans[tokenId]);
    }

    function accruedRate(Loan memory loan) private view returns(UD60x18) {
        return loan.ratePerSecond.mul(toUD60x18(secondsSinceLastPayment(loan)));
    }

    function secondsSinceLastPayment(Loan memory loan) private view returns(uint) {
        return block.timestamp - loan.lastPaymentTime;
    }

    function availableLiquidity() /* private */ public view returns(uint) {
        return totalDeposits - totalPrincipal;
    }
}