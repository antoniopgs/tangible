// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IInfo.sol";
import "../borrowingInfo/BorrowingInfo.sol";
import "../lendingInfo/LendingInfo.sol";
import "../loanStatus/LoanStatus.sol";
import "../interest/Interest.sol";

contract Info is IInfo, BorrowingInfo, LendingInfo, LoanStatus, Interest {

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
        if (tUsdcSupply == 0 || _totalDeposits == 0) {
            return usdcAmount = tUsdcAmount;
        }

        // Calculate usdcAmount
        return usdcAmount = tUsdcAmount * _totalDeposits / tUsdcSupply;
    }

    function borrowerApr(UD60x18 _utilization) external view returns(UD60x18 apr) {
        return _borrowerApr(_utilization);
    }

    // Auctions
    function bids(uint tokenId, uint idx) external view returns(Bid memory) {
        return _bids[tokenId][idx];
    }

    function bidsLength(uint tokenId) external view returns(uint) {
        return _bids[tokenId].length;
    }

    function bidActionable(uint tokenId, uint idx) external view returns(bool) {
        return _bidActionable(_bids[tokenId][idx], _minSalePrice(_debts[tokenId].loan));
    }

    function userBids(address user) external view returns(BidInfo[] memory _userBids) {

        _userBids = new BidInfo[](1_000_000);
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
        return _minSalePrice(_debts[tokenId].loan);
    }

    // Token Debts
    function unpaidPrincipal(uint tokenId) external view returns(uint) {
        return _debts[tokenId].loan.unpaidPrincipal;
    }

    function accruedInterest(uint tokenId) external view returns(uint) {
        return _accruedInterest(_debts[tokenId].loan);
    }

    function status(uint tokenId) external view returns(Status) {
        return _status(_debts[tokenId].loan);
    }

    function redeemable(uint tokenId) external view returns(bool) {
        return _redeemable(tokenId);
    }

    function loanChart(uint tokenId) external view returns(uint[] memory x, uint[] memory y) {

        // Get loan
        Loan memory loan = _debts[tokenId].loan;

        // Loop loan months
        for (uint i = 0; i <= _loanMaxMonths(loan); i++) {
            
            // Add month to x
            // x.push(i);
            x[i] = i;

            // Add month's principal cap to y
            // y.push(principalCap(loan, i));
            y[i] = _principalCap(loan, i);
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

    function redemptionWindow() external view returns(uint) {
        return _redemptionWindow;
    }

    function totalDeposits() external view returns(uint) {
        return _totalDeposits;
    }

    function totalPrincipal() external view returns(uint) {
        return _totalPrincipal;
    }
}