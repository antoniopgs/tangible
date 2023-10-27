// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";
import { Status, Bid } from "../../types/Types.sol";

interface IInfo {

    struct BidInfo {
        uint tokenId;
        uint idx;
        Bid bid;
    }

    // Pool
    function totalPrincipal() external view returns(uint);
    function totalDeposits() external view returns(uint);
    function availableLiquidity() external view returns(uint);
    function utilization() external view returns(UD60x18);
    function optimalUtilization() external view returns(UD60x18);
    function usdcToTUsdc(uint usdcAmount) external view returns(uint tUsdcAmount);
    function tUsdcToUsdc(uint tUsdcAmount) external view returns(uint usdcAmount);

    // Residents
    function isResident(address addr) external view returns (bool);
    function addressToResident(address addr) external view returns(uint);
    function residentToAddress(uint id) external view returns(address);

    function isNotAmerican(address addr) external view returns (bool);

    // Auctions
    // function bids(uint tokenId) external view returns(Bid[] memory); // Todo: implement later
    function bids(uint tokenId, uint idx) external view returns(Bid memory);
    function bidsLength(uint tokenId) external view returns(uint);
    function bidActionable(uint tokenId, uint idx) external view returns(bool);
    function userBids(address user) external view returns(BidInfo[] memory _userBids);
    function minSalePrice(uint tokenId) external view returns(uint);

    // Loans
    function unpaidPrincipal(uint tokenId) external view returns(uint);
    function accruedInterest(uint tokenId) external view returns(uint);
    function status(uint tokenId) external view returns(Status);
    function redeemable(uint tokenId) external view returns(bool);
    function loanChart(uint tokenId) external view returns(uint[] memory x, uint[] memory y);

    // Loan Terms
    function maxLtv() external view returns(UD60x18);
    function maxLoanMonths() external view returns(uint);
    function borrowerApr() external view returns(UD60x18 apr);
    function redemptionWindow() external view returns(uint);

    // Fees/Spreads
    function baseSaleFeeSpread() external view returns(UD60x18);
    function interestFeeSpread() external view returns(UD60x18);
    function redemptionFeeSpread() external view returns(UD60x18);
    function defaultFeeSpread() external view returns(UD60x18);
}