// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18, toUD60x18, fromUD60x18 } from "@prb/math/UD60x18.sol";
import { SD59x18, toSD59x18, fromSD59x18 } from "@prb/math/SD59x18.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./tUsdc.sol";

import "forge-std/console.sol";

contract BorrowingV3 is Initializable {

    IERC20 USDC;
    tUsdc tUSDC;

    // Time constants
    uint /* private */ public constant yearSeconds = 365 days; // Note: made public for testing
    uint /* private */ public constant yearMonths = 12;
    uint /* private */ public constant monthSeconds = yearSeconds / yearMonths; // Note: yearSeconds % yearMonths = 0 (no precision loss)
    
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
    UD60x18 public optimalUtilization = toUD60x18(90).div(toUD60x18(100)); // Note: 90% // Todo: relate to k1 and k2

    // Interest vars
    UD60x18 private m1 = toUD60x18(4).div(toUD60x18(100)); // Note: 0.04
    UD60x18 private b1 = toUD60x18(3).div(toUD60x18(100)); // Note: 0.03
    UD60x18 private m2 = toUD60x18(9); // Note: 9

    // Loan storage
    mapping(uint => Loan) public loans;

    // Libs
    using SafeERC20 for IERC20;

    function initialize(tUsdc _tUSDC) external initializer {
        USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // Note: ethereum mainnet
        tUSDC = _tUSDC;
    }

    function deposit(uint usdc) external {

        console.log("msg.sender:", msg.sender);
        
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

        console.log("");
        console.log("msg.sender:", msg.sender);
        console.log("usdc:", usdc);
        console.log("_tUsdc:", _tUsdc);
        console.log("tUSDC.balanceOf(msg.sender):", tUSDC.balanceOf(msg.sender));
        console.log(".availableLiquidity():", availableLiquidity());
        console.log("USDC.balanceOf(this):", USDC.balanceOf(address(this)));
        console.log("totalDeposits:", totalDeposits);
        console.log("totalPrincipal:", totalPrincipal);

        // Burn withdrawer tUsdc
        tUSDC.operatorBurn(msg.sender, _tUsdc, "", "");

        console.log("post burn");

        // Update pool
        totalDeposits -= usdc;
        require(totalPrincipal <= totalDeposits, "utilization can't exceed 100%");

        // Send usdc to withdrawer
        USDC.safeTransfer(msg.sender, usdc);
    }

    // Functions
    function startLoan(uint tokenId, uint principal, /* uint borrowerAprPct, */ uint maxDurationMonths) external {
        require(principal <= availableLiquidity(), "principal must be <= availableLiquidity");

        // Calculate ratePerSecond
        // UD60x18 ratePerSecond = toUD60x18(borrowerAprPct).div(toUD60x18(100)).div(toUD60x18(yearSeconds));
        UD60x18 ratePerSecond = borrowerRatePerSecond();
        console.log("UD60x18.unwrap(ratePerSecond):", UD60x18.unwrap(ratePerSecond));

        // Calculate maxDurationSeconds
        uint maxDurationSeconds = maxDurationMonths * monthSeconds;
        console.log("maxDurationSeconds:", maxDurationSeconds);

        // Calculate paymentPerSecond
        UD60x18 paymentPerSecond = calculatePaymentPerSecond(principal, ratePerSecond, maxDurationSeconds);
        console.log("UD60x18.unwrap(paymentPerSecond):", UD60x18.unwrap(paymentPerSecond));

        // Calculate maxCost
        uint maxCost = fromUD60x18(paymentPerSecond.mul(toUD60x18(maxDurationSeconds)));
        console.log("maxCost:", maxCost);

        // Calculate maxUnpaidInterest
        uint maxUnpaidInterest = maxCost - principal;
        console.log("maxUnpaidInterest:", maxUnpaidInterest);
        
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

        // Todo: Ensure State == Default

        // Calculate interest
        uint interest = accruedInterest(loan);

        // Calculate defaulterDebt
        uint defaulterDebt = loan.unpaidPrincipal + interest;

        // Redeem (pull defaulter's entire debt)
        USDC.safeTransferFrom(msg.sender, address(this), defaulterDebt); // Note: anyone can redeem on behalf of defaulter

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;
        console.log("interest:", interest);
        console.log("loan.maxUnpaidInterest:", loan.maxUnpaidInterest);
        console.log("interest <= loan.maxUnpaidInterest:", interest <= loan.maxUnpaidInterest);
        console.log(1);
        // assert(interest <= loan.maxUnpaidInterest); // Note: actually, if borrower defaults, can't he pay more interest than loan.maxUnpaidInterest?
        console.log(2);
        maxTotalInterestOwed -= loan.maxUnpaidInterest; // Note: maxTotalInterestOwed -= accruedInterest + any remaining unpaid interest (so can use loan.maxUnpaidInterest)

        // Todo: Clearout loan
        loan.borrower = address(0);
    }

    function foreclose(uint tokenId, uint salePrice) external {

        // Todo: Pull salePrice?

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Todo: Ensure State == Foreclosurable

        // Calculate interest
        uint interest = accruedInterest(loan);

        // Calculate defaulterDebt
        uint defaulterDebt = loan.unpaidPrincipal + interest; // Todo: add fees later

        // Ensure salePrice covers defaulterDebt + fees
        require(salePrice >= defaulterDebt, "salePrice must >= defaulterDebt"); // Question: minSalePrice will rise over time. Too risky?

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;
        console.log("interest", interest);
        console.log("loan.maxUnpaidInterest:", loan.maxUnpaidInterest);
        console.log("interest <= loan.maxUnpaidInterest:", interest <= loan.maxUnpaidInterest);
        console.log(1);
        // assert(interest <= loan.maxUnpaidInterest); // Note: actually, if borrower defaults, can't he pay more interest than loan.maxUnpaidInterest?
        console.log(2);
        maxTotalInterestOwed -= loan.maxUnpaidInterest; // Note: maxTotalInterestOwed -= accruedInterest + any remaining unpaid interest (so can use loan.maxUnpaidInterest)

        // Calculate defaulterEquity
        uint defaulterEquity = salePrice - defaulterDebt;

        // Send defaulterEquity to defaulter
        USDC.safeTransfer(loan.borrower, defaulterEquity);

        // Todo: Clearout loan
        loan.borrower = address(0);
    }
    
    // Public Views
    function defaulted(uint tokenId) public view returns(bool) {

        // Get loan
        Loan memory loan = loans[tokenId];

        // Get loanCompletedMonths
        uint _loanCompletedMonths = loanCompletedMonths(loan);

        // Calculate loanMaxDurationMonths
        uint loanMaxDurationMonths = loan.maxDurationSeconds / yearSeconds * yearMonths;

        // If loan exceeded allowed months
        if (_loanCompletedMonths > loanMaxDurationMonths) {
            return true;
        }

        return loan.unpaidPrincipal > principalCap(loan, _loanCompletedMonths);
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
    function principalCap(Loan memory loan, uint month) public pure returns(uint cap) {

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

    function borrowerApr() public view returns(UD60x18 apr) {
        
        // Get utilization
        UD60x18 _utilization = utilization();

        console.log("ba1");

        if (_utilization.lte(toSD59x18(int(fromUD60x18(optimalUtilization))))) {
            console.log("ba1.1");
            apr = m1.mul(_utilization).add(b1);
            console.log("ba1.2");

        } else {

            console.log("ba2.1");

            // If utilization == 100%
            if (_utilization.eq(1)) {
                revert("no APR. can't start loan if utilization = 100%");

            } else {
                console.log("ba2.2");
                apr = toUD60x18(uint(fromSD59x18(m2.mul(_utilization).add(b2()))));
                console.log("ba2.3");
            }
        }

        console.log("ba3");
        assert(apr.gt(toUD60x18(0)));
        console.log("ba4");
    }

    function b2() private view returns(SD59x18) {
        return optimalUtilization.mul(m1.sub(m2)).add(b1);
    }

    function borrowerRatePerSecond() private view returns(UD60x18 ratePerSecond) {
        ratePerSecond = borrowerApr().div(toUD60x18(yearSeconds)); // Todo: improve precision
    }

    function usdcToTUsdc(uint usdcAmount) public view returns(uint tUsdcAmount) {
        
        // Get tUsdcSupply
        uint tUsdcSupply = tUSDC.totalSupply();

        // If tUsdcSupply or totalDeposits = 0, 1:1
        if (tUsdcSupply == 0 || totalDeposits == 0) {
            return tUsdcAmount = usdcAmount;
        }

        // Calculate tUsdcAmount
        return tUsdcAmount = usdcAmount * tUsdcSupply / totalDeposits;
    }

    function tUsdcToUsdc(uint tUsdcAmount) public view returns(uint usdcAmount) {
        
        // Get tUsdcSupply
        uint tUsdcSupply = tUSDC.totalSupply();

        // If tUsdcSupply or totalDeposits = 0, 1:1
        if (tUsdcSupply == 0 || totalDeposits == 0) {
            return usdcAmount = tUsdcAmount;
        }

        // Calculate usdcAmount
        return usdcAmount = tUsdcAmount * totalDeposits / tUsdcSupply;
    }

    // Note: truncates on purpose (to enforce payment after monthSeconds, but not every second)
    function loanCompletedMonths(Loan memory loan) private view returns(uint) {
        return (block.timestamp - loan.startTime) / monthSeconds;
    }

    function calculatePaymentPerSecond(uint principal, UD60x18 ratePerSecond, uint maxDurationSeconds) /*private*/ public /* pure */ view returns(UD60x18 paymentPerSecond) {

        console.log("pps1");

        // Calculate x
        // - (1 + ratePerSecond) ** maxDurationSeconds <= MAX_UD60x18
        // - (1 + ratePerSecond) ** (maxDurationMonths * monthSeconds) <= MAX_UD60x18
        // - maxDurationMonths * monthSeconds <= log_(1 + ratePerSecond)_MAX_UD60x18
        // - maxDurationMonths * monthSeconds <= log(MAX_UD60x18) / log(1 + ratePerSecond)
        // - maxDurationMonths <= (log(MAX_UD60x18) / log(1 + ratePerSecond)) / monthSeconds // Note: ratePerSecond depends on util (so solve for maxDurationMonths)
        // - maxDurationMonths <= log(MAX_UD60x18) / (monthSeconds * log(1 + ratePerSecond))
        console.log("UD60x18.unwrap(utilization()):", UD60x18.unwrap(utilization()));
        console.log("UD60x18.unwrap(ratePerSecond):", UD60x18.unwrap(ratePerSecond));
        console.log("UD60x18.unwrap(toUD60x18(1).add(ratePerSecond)):", UD60x18.unwrap(toUD60x18(1).add(ratePerSecond)));
        console.log("UD60x18.unwrap(toUD60x18(1).add(ratePerSecond)):", UD60x18.unwrap(toUD60x18(1).add(ratePerSecond)));
        console.log("maxDurationSeconds:", maxDurationSeconds);
        UD60x18 x = toUD60x18(1).add(ratePerSecond).powu(maxDurationSeconds);

        console.log("pps2");

        // principal * ratePerSecond * x <= MAX_UD60x18
        // principal * ratePerSecond * (1 + ratePerSecond) ** maxDurationSeconds <= MAX_UD60x18
        // principal * ratePerSecond * (1 + ratePerSecond) ** (maxDurationMonths * monthSeconds) <= MAX_UD60x18
        // (1 + ratePerSecond) ** (maxDurationMonths * monthSeconds) <= MAX_UD60x18 / (principal * ratePerSecond)
        // maxDurationMonths * monthSeconds <= log_(1 + ratePerSecond)_(MAX_UD60x18 / (principal * ratePerSecond))
        // maxDurationMonths * monthSeconds <= log(MAX_UD60x18 / (principal * ratePerSecond)) / log(1 + ratePerSecond)
        // maxDurationMonths <= (log(MAX_UD60x18 / (principal * ratePerSecond)) / log(1 + ratePerSecond)) / monthSeconds
        // maxDurationMonths <= log(MAX_UD60x18 / (principal * ratePerSecond)) / (monthSeconds * log(1 + ratePerSecond))
        
        // Calculate paymentPerSecond
        paymentPerSecond = toUD60x18(principal).mul(ratePerSecond).mul(x).div(x.sub(toUD60x18(1)));

        console.log("pps3");
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

    // enum State { None, Mortgage, Default, Foreclosurable }
    enum State { None, Mortgage, Default }

    function state(uint tokenId) public view returns (State) {

        Loan memory loan = loans[tokenId];
        
        // If no borrower
        if (loan.borrower == address(0)) {
            return State.None;

        // If borrower
        } else {
            
            // If default
            if (defaulted(tokenId)) {
                return State.Default;

            // If no default
            } else {
                return State.Mortgage;
            }
        }
    }
}