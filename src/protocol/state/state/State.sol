// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IState.sol";
import "../targetManager/TargetManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../tokens/tUsdc.sol";
import "../../../tokens/TangibleNft.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract State is IState, TargetManager {

    // Tokens
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // ethereum
    tUsdc tUSDC;
    TangibleNft internal prosperaNftContract;

    // Main Storage
    mapping(TokenId => Bid[]) bids;
    mapping(TokenId => Loan) public loans;
    EnumerableSet.UintSet internal loansTokenIds;
    UD60x18 protocolMoney;

    // Pool vars
    UD60x18 totalBorrowed;
    UD60x18 totalDeposits;
    UD60x18 public utilizationCap = toUD60x18(90).div(toUD60x18(100)); // 90%

    // Borrowing terms
    uint internal constant loanYears = 5; // 5 "years" (each "year" will have 360 days)
    UD60x18 public maxLtv = toUD60x18(50).div(toUD60x18(100)); // 50%
    UD60x18 public borrowerApr = toUD60x18(5).div(toUD60x18(100)); // 5%

    // Borrowing math vars
    uint internal constant periodDuration = 30 days;
    uint internal constant periodsPerYear = 12;
    // UD60x18 internal immutable periodsPerYear = toUD60x18(365 days).div(toUD60x18(periodDuration)); // 365 days / 30 days = 12.1666...
    uint internal constant yearDuration = periodsPerYear * periodDuration; // 12 * 30 = 360 days
    uint internal constant installmentCount = loanYears * periodsPerYear; // 5 * 12 = 60 installments
    UD60x18 internal immutable periodRate = borrowerApr.div(toUD60x18(periodsPerYear)); // 5% / 12 = 0.41666...%
    // UD60x18 perfectLenderApy = toUD60x18(1).add(periodicBorrowerRate).pow(periodsPerYear).sub(toUD60x18(1)); // lenderApy if 100% utilization

    // Auction vars
    UD60x18 saleFeeRatio;

    // Foreclosure vars
    UD60x18 foreclosureFeeRatio;
    UD60x18 foreclosurerCutRatio;
    uint public redemptionWindow = 45 days;

    // Libs
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    function utilization() public view returns (UD60x18) {
        return totalBorrowed.div(totalDeposits);
    }

    // function lenderApy() public view returns (UD60x18) {
    //     interestOwed.div(totalDeposits);
    // }

    function state(Loan memory loan) internal view returns (State) {
        
        // If no borrower
        if (loan.borrower == address(0)) { // Note: acceptBid() must clear-out borrower & acceptLoanBid() must update borrower
            return State.None;

        // If borrower
        } else {
            
            // If not defaulted // Note: payLoan() must clear-out borrower in finalPayment
            if (!defaulted(loan)) {
                return State.Mortgage;

            // If defaulted
            } else { // Note: foreclose() must clear-out borrower & loanForeclose() must update borrower
                return State.Default;
            }
        }
    }

    function defaulted(Loan memory loan) private view returns (bool) {
        return block.timestamp > loan.nextPaymentDeadline; // Note: no allowed missed payments for now to keep it simple
    }

    function sendNft(Loan storage loan, address receiver, uint tokenId) internal {

        // Send Nft to receiver
        prosperaNftContract.safeTransferFrom(address(this), receiver, tokenId);

        // Reset loan state to Null (so it can re-enter system later)
        loan.borrower = address(0);

        // Remove tokenId from loansTokenIds
        loansTokenIds.remove(tokenId);
    }
}