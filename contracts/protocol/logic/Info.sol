// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../interfaces/logic/IInfo.sol";
import "./loanStatus/LoanStatus.sol";

contract Info is IInfo, LoanStatus {

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

    function tUsdcToUsdc(uint tUsdcAmount) external view returns(uint usdcAmount) {
        
        // Get tUsdcSupply
        uint tUsdcSupply = tUSDC.totalSupply();

        // If tUsdcSupply or totalDeposits = 0, 1:1
        if (tUsdcSupply == 0 || _totalDeposits == 0) {
            usdcAmount = tUsdcAmount / 1e12; // Note: USDC has 12 less decimals than tUSDC

        } else {
            usdcAmount = tUsdcAmount * _totalDeposits / tUsdcSupply; // Note: dividing by tUsdcSupply removes need to remove 12 decimals
        }
    }

    // Auctions
    function bids(uint tokenId, uint idx) external view returns(Bid memory) {
        return _bids[tokenId][idx];
    }

    function bidsLength(uint tokenId) external view returns(uint) {
        return _bids[tokenId].length;
    }

    function bidActionable(uint tokenId, uint idx) external view returns(bool) {
        return _bidActionable(_bids[tokenId][idx], _minSalePrice(_loans[tokenId]));
    }

    function userBids(address user) external view returns(BidInfo[] memory _userBids) {

        _userBids = new BidInfo[](100);
        uint realLength;
        
        // Loop tokenIds
        for (uint i = 0; i < tangibleNft.totalSupply(); i++) {
            
            // Get tokenIdBids
            Bid[] memory tokenIdBids = _bids[i];

            // Loop tokenIdBids
            for (uint n = 0; n < tokenIdBids.length; n++) {

                // Get bid
                Bid memory bid = tokenIdBids[n];
                
                // If bidder is user
                if (bid.bidder == user) {

                    _userBids[realLength] = BidInfo({
                        tokenId: i,
                        idx: n,
                        bid: bid
                    });

                    realLength++;
                }
            }
        }
    }

    function minSalePrice(uint tokenId) external view returns(uint) {
        return _minSalePrice(_loans[tokenId]);
    }

    // Token Debts
    function unpaidPrincipal(uint tokenId) external view returns(uint) {
        return _loans[tokenId].unpaidPrincipal;
    }

    function accruedInterest(uint tokenId) external view returns(uint) {
        return _accruedInterest(_loans[tokenId]);
    }

    function status(uint tokenId) external view returns(Status) {
        return _status(_loans[tokenId]);
    }

    function _loanMaxMonths(Loan memory loan) internal pure returns (uint) {
        return MONTHS_IN_YEAR * loan.maxDurationSeconds / SECONDS_IN_YEAR;
    }

    function loanChart(uint tokenId) external view returns(uint[] memory x, uint[] memory y) {

        // Get loan
        Loan memory loan = _loans[tokenId];

        // Loop loan months
        for (uint i = 1; i <= _loanMaxMonths(loan); i++) {
            
            // Add i to x
            x[i] = i;

            // Add month's principal cap to y
            y[i] = principalCapAtMonth(loan, i);
        }
    }

    function maxLtv() external view returns(UD60x18) {
        return _maxLtv;
    }

    function baseSaleFeeSpread() external view returns(UD60x18) {
        return _baseSaleFeeSpread;
    }

    function defaultFeeSpread() external view returns(UD60x18) {
        return _defaultFeeSpread;
    }

    function interestFeeSpread() external view returns(UD60x18) {
        return _interestFeeSpread;
    }

    function maxLoanMonths() external view returns(uint) {
        return _maxLoanMonths;
    }

    function optimalUtilization() external view returns(UD60x18) {
        return _optimalUtilization;
    }

    function redemptionFeeSpread() external view returns(UD60x18) {
        return _redemptionFeeSpread;
    }

    function totalDeposits() external view returns(uint) {
        return _totalDeposits;
    }

    function totalPrincipal() external view returns(uint) {
        return _totalPrincipal;
    }

    function isNotAmerican(address addr) external view returns (bool) {
        return _notAmerican[addr];
    }
}