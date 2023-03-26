// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./tUsdc.sol";
import "@prb/math/UD60x18.sol";

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

    // Pool
    uint totalPrincipal;
    uint totalDeposits;
    uint totalInterestOwed;

    // Loan storage
    mapping(uint => Loan) public loans;

    // Other
    UD60x18 public maxLtv = toUD60x18(50).div(toUD60x18(100)); // 50%
    uint public redemptionWindow = 45 days;

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
    }

    function payLoan(uint tokenId) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

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
    }

    function redeem(uint tokenId) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += loan.maxUnpaidInterest;
        totalInterestOwed -= loan.maxUnpaidInterest;

        // Update Loan
    }

    function foreclose(uint tokenId) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += loan.maxUnpaidInterest;
        totalInterestOwed -= loan.maxUnpaidInterest;

        // Update Loan
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

    // Todo: State Validations

    function defaulted(Loan memory loan) private view returns(bool) {
        return block.timestamp > loan.nextPaymentDeadline;
    }
}
