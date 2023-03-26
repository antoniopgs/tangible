// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./tUsdc.sol";
import "@prb/math/UD60x18.sol";

// Todo: implement payLoan fee, sale fee, foreclosure fee, and maybe redemption fee?
// Todo: implement view and withdrawal mechanism for protocolUsdc
contract Protocol is Initializable {

    // Tokens
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // ethereum
    tUsdc tUSDC;

    // Structs
    struct Loan {
        address borrower;
        UD60x18 monthlyRate;
        uint monthlyPayment;
        uint unpaidPrincipal;
        uint maxUnpaidInterest;
        uint nextPaymentDeadline;
    }

    // Enums
    enum State { None, Mortgage, Default, Foreclosurable } // Note: maybe switch to: enum NftOwner { Seller, Borrower, Protocol }

    // Pool
    uint totalPrincipal;
    uint totalDeposits;
    uint totalInterestOwed;

    // Loan storage
    mapping(uint => Loan) public loans;

    // Other
    UD60x18 public maxLtv = toUD60x18(50).div(toUD60x18(100)); // 50%
    uint public redemptionWindow = 45 days;
    UD60x18 public foreclosureSpread = toUD60x18(2).div(toUD60x18(100)); // 2%

    // Libs
    using SafeERC20 for IERC20;

    function initialize(tUsdc _tUSDC) external initializer {
        tUSDC = _tUSDC;
    }

    function deposit(uint _deposit) external {

        // Pull _deposit
        USDC.safeTransferFrom(msg.sender, address(this), _deposit);

        // Update pool
        totalDeposits += _deposit;

        // Calculate tusdc
        uint tusdc = usdcToTusdc(_deposit);

        // Mint tusdc to depositor
        tUSDC.mint(msg.sender, tusdc);
    }

    function withdraw(uint withdrawal) external {

        // Calculate tusdc
        uint tusdc = usdcToTusdc(withdrawal);

        // Burn tusdc from withdrawer
        tUSDC.burn(tusdc, "");

        // Update & Validate pool
        totalDeposits -= withdrawal;
        require(totalPrincipal <= totalDeposits, "utilization can't exceed 100%");

        // Send withdrawal
        USDC.safeTransfer(msg.sender, withdrawal); // Question: reentrancy possible?
    }

    function startLoan(uint tokenId, address borrower, uint propertyValue, uint downPayment, uint loanYears) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Ensure None
        require(state(loan) == State.None, "loan not empty");

        // Calculate principal
        uint principal = propertyValue - downPayment;

        // Calculate & Validate ltv
        UD60x18 ltv = toUD60x18(principal).div(toUD60x18(propertyValue));
        require(ltv.lte(maxLtv), "ltv can't exceed maxLtv");

        // Calculate monthlyRate
        UD60x18 monthlyRate = calculateMonthlyRate();

        // Calculate monthCount
        uint monthCount = loanYears * 12;

        // Calculate monthlyPayment
        uint monthlyPayment = calculateMonthlyPayment(principal, monthlyRate, monthCount);

        // Calculate maxCost
        uint maxCost = monthlyPayment * monthCount;

        // Calculate maxUnpaidInterest
        uint maxUnpaidInterest = maxCost - principal;

        // Store Loan
        loans[tokenId] = Loan({
            borrower: borrower,
            monthlyRate: monthlyRate,
            monthlyPayment: monthlyPayment,
            unpaidPrincipal: principal,
            maxUnpaidInterest: maxUnpaidInterest,
            nextPaymentDeadline: block.timestamp + 30 days
        });

        // Update pool
        totalPrincipal += principal;
        totalInterestOwed += maxUnpaidInterest;

        // Todo: pull downpayment?
    }

    function payLoan(uint tokenId) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Ensure mortgage
        require(state(loan) == State.Mortgage, "no active mortgage");

        // Pull monthlyPayment
        USDC.safeTransferFrom(msg.sender, address(this), loan.monthlyPayment); // Note: anyone can pay for the borrower

        // Calculate interest
        uint interest = fromUD60x18(loan.monthlyRate.mul(toUD60x18(loan.unpaidPrincipal)));

        // Calculate repayment
        uint repayment = loan.monthlyPayment - interest;

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += loan.maxUnpaidInterest;
        totalInterestOwed -= loan.maxUnpaidInterest;

        // Update Loan
        loan.unpaidPrincipal -= repayment;
        loan.maxUnpaidInterest -= interest;

        // If loan paid off 
        if (loan.unpaidPrincipal == 0) {

            // Clearout loan
            loan.borrower = address(0);
        
        // If loan not paid off
        } else {
            loan.nextPaymentDeadline += 30 days;
        }

        // Todo: clamp
    }

    function redeem(uint tokenId) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Ensure Default
        require(state(loan) == State.Default, "no default, or redemptionWindow exceeded");

        // Calculate defaulterDebt
        uint defaulterDebt = loan.unpaidPrincipal + loan.maxUnpaidInterest; // Note: should redeemer pay maxUnpaidInterest? I think so

        // Redeem (pull defaulter's entire debt)
        USDC.safeTransferFrom(msg.sender, address(this), defaulterDebt);

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += loan.maxUnpaidInterest;
        totalInterestOwed -= loan.maxUnpaidInterest;

        // Clearout loan
        loan.borrower = address(0); // Note: this eliminates need to decrease loan.unpaidPrincipal
    }

    function foreclose(uint tokenId, uint salePrice) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Ensure Foreclosurable
        require(state(loan) == State.Foreclosurable, "not foreclosurable");

        // Calculate defaulterDebt
        uint defaulterDebt = loan.unpaidPrincipal + loan.maxUnpaidInterest; // Note: this is unused, so something weird going on. need to rethink

        // require(salePrice >= defaulterDebt + fees, "salePrice must cover defaultDebt + fees"); // Todo: uncomment once other fees are implemented

        // Calculate defaulterEquity
        uint defaulterEquity = salePrice - loan.unpaidPrincipal;

        // Calculate foreclosureFee
        uint foreclosureFee = fromUD60x18(foreclosureSpread.mul(toUD60x18(defaulterEquity)));
        // uint foreclosureFee = foreclosureSpread.mul(salePrice); // Question: shouldn't the foreclosure spread be applied to the salePrice?

        // Calculate leftover
        uint leftover = defaulterEquity - foreclosureFee;

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += loan.maxUnpaidInterest;
        totalInterestOwed -= loan.maxUnpaidInterest;

        // Send leftover to defaulter
        USDC.safeTransfer(loan.borrower, leftover);

        // Clearout loan
        loan.borrower = address(0); // Note: this eliminates need to decrease loan.unpaidPrincipal
    }

    // ----- VIEWS -----
    function utilization() external view returns (UD60x18) {
        return toUD60x18(totalPrincipal).div(toUD60x18(totalDeposits));
    }

    function lenderApy() external view returns (UD60x18) {
        return toUD60x18(totalInterestOwed).div(toUD60x18(totalDeposits));
    }

    function calculateMonthlyRate() private /* view */ pure returns (UD60x18) {
        return borrowerApr().div(toUD60x18(12));
    }

    function borrowerApr() public /* view */ pure returns (UD60x18) { // Todo: make this vary with utilization
        return toUD60x18(5).div(toUD60x18(100));
    }

    function calculateMonthlyPayment(uint principal, UD60x18 monthlyRate, uint monthCount) private /* view */ pure returns (uint) {

        // Calculate x
        UD60x18 x = toUD60x18(1).add(monthlyRate).powu(monthCount);

        // Return monthlyPayment
        return fromUD60x18(toUD60x18(principal).mul(monthlyRate).mul(x).div(x.sub(toUD60x18(1))));
    }

    function usdcToTusdc(uint usdc) private view returns(uint tusdc) {
        tusdc = fromUD60x18(toUD60x18(usdc).mul(usdcToTusdcRatio()));
    }

    function usdcToTusdcRatio() private view returns(UD60x18) {
        
        // Get tusdcSupply
        uint tusdcSupply = tUSDC.totalSupply();

        if (tusdcSupply == 0 || totalDeposits == 0) {
            return toUD60x18(1);

        } else {
            return toUD60x18(tusdcSupply).div(toUD60x18(totalDeposits));
        }
    }

    function state(Loan memory loan) internal view returns (State) {
        
        // If no borrower
        if (loan.borrower == address(0)) { // Note: must zero-out borrower when loan is paid off, redeemed or foreclosed
            return State.None;

        // If borrower exists
        } else {

            // If borrower defaulted
            if (defaulted(loan)) {

                // If redemptionWindow exceeded
                if (block.timestamp > loan.nextPaymentDeadline + redemptionWindow) {
                    return State.Foreclosurable;

                // If within redemptionWindow
                } else {
                    return State.Default;
                }

            // If borrower didn't default
            } else {
                return State.Mortgage;
            }
        }
    }

    function defaulted(Loan memory loan) private view returns(bool) {
        return block.timestamp > loan.nextPaymentDeadline;
    }
}
