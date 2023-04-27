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

    // Time constants
    uint /* private */ public constant yearSeconds = 365 days; // Note: made public for testing
    uint /* private */ public constant yearMonths = 12;
    uint /* private */ public constant monthSeconds = yearSeconds / yearMonths; // Note: yearSeconds % yearMonths = 0 (no precision loss)

    // Pool vars
    uint public totalPrincipal;
    uint public totalDeposits;
    uint public maxTotalUnpaidInterest; // Todo: figure this out
    UD60x18 public optimalUtilization = toUD60x18(90).div(toUD60x18(100)); // Note: 90%

    // Interest vars
    UD60x18 internal m1 = toUD60x18(4).div(toUD60x18(100)); // Note: 0.04
    UD60x18 internal b1 = toUD60x18(3).div(toUD60x18(100)); // Note: 0.03
    UD60x18 internal m2 = toUD60x18(9); // Note: 9

    // Fees/Spreads
    UD60x18 internal _payLoanFeeSpread = toUD60x18(1).div(toUD60x18(100)); // Note: 1%
    UD60x18 internal _redemptionFeeSpread = toUD60x18(2).div(toUD60x18(100)); // Note: 2%
    UD60x18 internal _foreclosureFeeSpread = toUD60x18(3).div(toUD60x18(100)); // Note: 3%

    // Main Storage
    mapping(TokenId => Bid[]) internal _bids;
    mapping(TokenId => Loan) public _loans;
    EnumerableSet.UintSet internal loansTokenIds;
    uint protocolMoney;

    // Other vars
    uint internal redemptionWindow = 45 days;
    UD60x18 public maxLtv = toUD60x18(50).div(toUD60x18(100)); // Note: 50%

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

    function redemptionFeeSpread() external view returns (UD60x18) {
        return _redemptionFeeSpread;
    }

    function foreclosureFeeSpread() external view returns (UD60x18) {
        return _foreclosureFeeSpread;
    }

    function loans(uint tokenId) external view returns(Loan memory) {
        return _loans[tokenId];
    }
}