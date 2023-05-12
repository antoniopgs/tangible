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

import { toUD60x18, fromUD60x18 } from "@prb/math/src/UD60x18.sol";

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
    // uint public maxTotalUnpaidInterest; // Todo: figure this out
    UD60x18 public optimalUtilization = toUD60x18(90).div(toUD60x18(100)); // Note: 90%

    // Interest vars
    UD60x18 internal m1 = toUD60x18(4).div(toUD60x18(100)); // Note: 0.04
    UD60x18 internal b1 = toUD60x18(3).div(toUD60x18(100)); // Note: 0.03
    UD60x18 internal m2 = toUD60x18(9); // Note: 9

    // Fees/Spreads
    UD60x18 internal _saleFeeSpread = toUD60x18(1).div(toUD60x18(100)); // Note: 1%
    UD60x18 internal _payLoanFeeSpread = toUD60x18(2).div(toUD60x18(100)); // Note: 2%
    UD60x18 internal _redemptionFeeSpread = toUD60x18(3).div(toUD60x18(100)); // Note: 3%
    UD60x18 internal _defaultFeeSpread = toUD60x18(4).div(toUD60x18(100)); // Note: 4%

    // Main Storage
    mapping(uint => Bid[]) internal _bids;
    mapping(uint => Loan) public _loans;
    EnumerableSet.UintSet internal loansTokenIds;
    uint protocolMoney;

    // Other vars
    uint internal redemptionWindow = 45 days;
    UD60x18 public maxLtv = toUD60x18(50).div(toUD60x18(100)); // Note: 50%
    uint public maxDurationMonthsCap = 120;

    // Libs
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    function initialize(tUsdc _tUSDC, TangibleNft _prosperaNftContract) external initializer { // Question: maybe move this elsewhere?
        tUSDC = _tUSDC;
        prosperaNftContract = _prosperaNftContract;
    }

    // ----- Views -----
    function availableLiquidity() public view returns(uint) {
        return totalDeposits - totalPrincipal;
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
        return ltv.lte(maxLtv) && principal <= availableLiquidity();
    }

    // ----- Views for Testing -----
    function loansTokenIdsLength() external view returns (uint) {
        return loansTokenIds.length();
    }

    function loansTokenIdsAt(uint idx) external view returns (uint tokenId) {
        tokenId = loansTokenIds.at(idx);
    }

    function loans(uint tokenId) external view returns (Loan memory) {
        return _loans[tokenId];
    }

    function bids(uint tokenId) external view returns (Bid[] memory) {
        return _bids[tokenId];
    }

    function tokenIdBidsLength(uint tokenId) external view returns (uint) {
        return _bids[tokenId].length;
    }

    function redemptionFeeSpread() external view returns (UD60x18) {
        return _redemptionFeeSpread;
    }

    function defaultFeeSpread() external view returns (UD60x18) {
        return _defaultFeeSpread;
    }

    function accruedInterest(Loan memory loan) private view returns(uint) {
        return fromUD60x18(toUD60x18(loan.unpaidPrincipal).mul(accruedRate(loan)));
    }

    function accruedInterest(uint tokenId) public view returns(uint) { // Note: made this duplicate of accruedInterest() for testing
        return accruedInterest(_loans[tokenId]);
    }

    function accruedRate(Loan memory loan) private view returns(UD60x18) {
        return loan.ratePerSecond.mul(toUD60x18(secondsSinceLastPayment(loan)));
    }

    function secondsSinceLastPayment(Loan memory loan) private view returns(uint) {
        return block.timestamp - loan.lastPaymentTime;
    }
}