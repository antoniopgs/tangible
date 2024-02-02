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

    function maxLoanMonths() external view returns(uint) {
        return _maxLoanMonths;
    }

    function redemptionFeeSpread() external view returns(UD60x18) {
        return _redemptionFeeSpread;
    }
}