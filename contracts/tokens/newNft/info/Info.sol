// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IInfo.sol";

contract Info is IInfo {

    // Residents
    function isResident(address addr) external view returns (bool) {
        return _isResident(addr);
    }

    // Pool
    function availableLiquidity() external view returns(uint) {
        return _availableLiquidity();
    }

    function utilization() external view returns(UD60x18) {
        return _utilization();
    }

    function usdcToTUsdc(uint usdcAmount) external view returns(uint tUsdcAmount) {
        return _usdcToTUsdc(usdcAmount);
    }

    function tUsdcToUsdc(uint tUsdcAmount) external view returns(uint usdcAmount) {
        return _tUsdcToUsdc(tUsdcAmount);
    }

    // Auctions
    function bidActionable(Bid memory _bid) external view returns(bool) {
        return _bidActionable(_bid);
    }

    // Token Debts
    function unpaidPrincipal(uint tokenId) external view returns(uint) {
        return debts[tokenId].loan.unpaidPrincipal;
    }

    function accruedInterest(uint tokenId) external view returns(uint) {
        return _accruedInterest(debts[tokenId].loan);
    }
}