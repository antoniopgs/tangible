// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IState.sol";
import "../targetManager/TargetManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../tokens/tUsdc.sol";
import "../../../tokens/TangibleNft.sol";
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
    
    // Borrowing vars
    UD60x18 public maxLtv;
    UD60x18 internal installmentCount;
    UD60x18 public utilizationCap;
    UD60x18 internal periodicBorrowerRate; // period is 30 days

    // Auction vars
    UD60x18 saleFeeRatio;

    // Foreclosure vars
    UD60x18 foreclosureFeeRatio;
    UD60x18 foreclosurerCutRatio;

    // UD60x18 internal immutable compoundingPeriodsPerYear = toUD60x18(365).div(toUD60x18(30)); // period is 30 days
    // UD60x18 perfectLenderApy; // lenderApy if 100% utilization

    constructor() {

    }

    // constructor(uint yearlyBorrowerRatePct, uint loansYearCount, uint maxLtvPct, uint utilizationCapPct) {
    //     periodicBorrowerRate = toUD60x18(yearlyBorrowerRatePct).mul(toUD60x18(30)).div(toUD60x18(100)).div(toUD60x18(365)); // yearlyBorrowerRate is the APR
    //     installmentCount = toUD60x18(loansYearCount * 365).div(toUD60x18(30)); // make it separate from compoundingPeriodsPerYear to move div later (and increase precision)
    //     maxLtv = toUD60x18(maxLtvPct).div(toUD60x18(100));
    //     utilizationCap = toUD60x18(utilizationCapPct).div(toUD60x18(100));
    //     perfectLenderApy = toUD60x18(1).add(periodicBorrowerRate).pow(compoundingPeriodsPerYear).sub(toUD60x18(1));
    // }

    function utilization() public view returns (UD60x18) {
        return totalBorrowed.div(totalDeposits);
    }

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

    function defaulted(Loan memory loan) internal view returns (bool) {
        return block.timestamp > loan.nextPaymentDeadline;
    }
}
