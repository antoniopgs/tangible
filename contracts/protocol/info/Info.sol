// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IInfo.sol";
import "../auctionsInfo/AuctionsInfo.sol";
import "../borrowingInfo/BorrowingInfo.sol";
import "../lendingInfo/LendingInfo.sol";

contract Info is IInfo, AuctionsInfo, BorrowingInfo, LendingInfo {

    // Residents
    function isResident(address addr) external view returns (bool) {
        return _isResident(addr);
    }

    function addressToResident(address addr) external view returns(uint) {
        return _addressToResident[addr];
    }

    function residentToAddress(uint id) external view returns(address) {
        return _residentToAddress[id];
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
        
        // Get tUsdcSupply
        uint tUsdcSupply = tUSDC.totalSupply();

        // If tUsdcSupply or totalDeposits = 0, 1:1
        if (tUsdcSupply == 0 || totalDeposits == 0) {
            return usdcAmount = tUsdcAmount;
        }

        // Calculate usdcAmount
        return usdcAmount = tUsdcAmount * totalDeposits / tUsdcSupply;
    }

    // Auctions
    function bids(uint tokenId, uint idx) external view returns(Bid memory) {
        return _bids[tokenId][idx];
    }

    function bidsLength(uint tokenId) external view returns(uint) {
        return _bids[tokenId].length;
    }

    function bidActionable(uint tokenId, uint idx) external view returns(bool) {
        return _bidActionable(_debts[tokenId].loan, _bids[tokenId][idx]);
    }

    // Todo: test this later
    function userBids(address user) external view returns(uint[] memory tokenIds, uint[] memory idxs) {

        // Loop tokenIds
        for (uint i = 0; i < tangibleNft.totalSupply(); i++) {

            // Get tokenBids
            Bid[] memory tokenBids = _bids[i];

            // Loop tokenBids
            for (uint n = 0; n < tokenBids.length; n++) {
                
                // If bidder is user
                if (tokenBids[n].bidder == user) {

                    // Store in arrays
                    tokenIds[tokenIds.length] = i;
                    idxs[idxs.length] = n;
                }
            }
        }
    }

    // Token Debts
    function unpaidPrincipal(uint tokenId) external view returns(uint) {
        return _debts[tokenId].loan.unpaidPrincipal;
    }

    function accruedInterest(uint tokenId) external view returns(uint) {
        return _accruedInterest(_debts[tokenId].loan);
    }
}