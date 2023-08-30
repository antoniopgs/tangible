// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";

interface IInfo {

    // Residents
    function isResident(address addr) external view returns (bool);

    // Pool
    function availableLiquidity() external view returns(uint);
    function utilization() external view returns(UD60x18);
    function usdcToTUsdc(uint usdcAmount) external view returns(uint tUsdcAmount);
    function tUsdcToUsdc(uint tUsdcAmount) external view returns(uint usdcAmount);
    // function borrowerApr() external view returns(UD60x18 apr);

    // Auctions
    function bidActionable(uint tokenId, uint idx) external view returns(bool);

    // Token Debts
    function unpaidPrincipal(uint tokenId) external view returns(uint);
    function accruedInterest(uint tokenId) external view returns(uint);
}