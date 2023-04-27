// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IState.sol";
import "../targetManager/TargetManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../tokens/tUsdc.sol";
import "../../../tokens/TangibleNft.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { toUD60x18 } from "@prb/math/UD60x18.sol";

abstract contract State is IState, TargetManager, Initializable {

    // Tokens
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // ethereum
    tUsdc tUSDC;
    TangibleNft internal prosperaNftContract;

    // Main Storage
    mapping(TokenId => Bid[]) internal _bids;
    mapping(TokenId => Loan) public _loans;
    EnumerableSet.UintSet internal loansTokenIds;
    uint protocolMoney;

    // Pool vars
    uint public totalPrincipal;
    uint public totalDeposits;
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

    function initialize(tUsdc _tUSDC, TangibleNft _prosperaNftContract) external initializer { // Question: maybe move this elsewhere?
        tUSDC = _tUSDC;
        prosperaNftContract = _prosperaNftContract;
    }

    // function lenderApy() public view returns (UD60x18) {
    //     interestOwed.div(totalDeposits);
    // }

    function status(Loan memory loan) internal view returns (Status) {
        
        // If no borrower
        if (loan.borrower == address(0)) { // Note: acceptBid() must clear-out borrower & acceptLoanBid() must update borrower
            return Status.None;

        // If borrower
        } else {
            
            // If default // Note: payLoan() must clear-out borrower in finalPayment
            if (defaulted(loan)) {
                
                // Calculate timeSinceDefault
                uint timeSinceDefault; /*= block.timestamp - defaultTime(loan);*/

                if (timeSinceDefault <= redemptionWindow) {
                    return Status.Default; // Note: foreclose() must clear-out borrower & loanForeclose() must update borrower
                } else {
                    return Status.Foreclosurable;
                }

            // If no default
            } else {
                return Status.Mortgage;
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

    function bidActionable(Bid memory bid) public view returns(bool) {
        return bid.propertyValue == bid.downPayment || loanBidActionable(bid);
    }

    function loanBidActionable(Bid memory _bid) public view returns(bool) {

        // Calculate loanBid principal
        uint principal = _bid.propertyValue - _bid.downPayment;

        // Calculate loanBid ltv
        UD60x18 ltv = toUD60x18(principal).div(toUD60x18(_bid.propertyValue));

        // Return actionability
        return ltv.lte(maxLtv) && availableLiquidity() >= principal;
    }

    function availableLiquidity() public view returns(uint) {
        return totalDeposits - totalPrincipal;
    }

    // Views for Testing
    function loansTokenIdsLength() external view returns (uint) {
        return loansTokenIds.length();
    }

    function loansTokenIdsAt(uint idx) external view returns (uint tokenId) {
        tokenId = loansTokenIds.at(idx);
    }

    function loans(uint tokenId) external view returns (Loan memory) {
        return _loans[TokenId.wrap(tokenId)];
    }

    function bids(uint tokenId) external view returns (Bid[] memory) {
        return _bids[TokenId.wrap(tokenId)];
    }

    function status(uint tokenId) external view returns (Status) {
        return status(_loans[TokenId.wrap(tokenId)]);
    }

    function tokenIdBidsLength(uint tokenId) external view returns (uint) {
        return _bids[TokenId.wrap(tokenId)].length;
    }
}