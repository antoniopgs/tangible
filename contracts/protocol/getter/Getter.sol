// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IGetter.sol";
import "../state/state/State.sol";

contract Getter is IGetter, State {

    using EnumerableSet for EnumerableSet.UintSet;

    function myLoans() external view returns (uint[] memory myLoansTokenIds) {

        for (uint i = 0; i < loansTokenIds.length(); i++) {

            // Get tokenId
            uint tokenId = loansTokenIds.at(i);

            if (_loans[tokenId].borrower == msg.sender) {
                myLoansTokenIds[myLoansTokenIds.length] = tokenId;
            }
        }
    }

    function myBids() external view returns(BidInfo[] memory _myBids) {
        
        // Loop tokenIds
        for (uint i = 0; i < prosperaNftContract.totalSupply(); i++) {
            
            // Get tokenIdBids
            Bid[] memory tokenIdBids = _bids[i];

            // Loop tokenIdBids
            for (uint n = 0; n < tokenIdBids.length; n++) {

                // Get bid
                Bid memory bid = tokenIdBids[n];
                
                // If bidder is caller
                if (bid.bidder == msg.sender) {

                    _myBids[_myBids.length] = BidInfo({
                        tokenId: i,
                        idx: n,
                        bid: bid
                    });
                }
            }
        }
    }

    function accruedInterest(uint tokenId) external view returns(uint) { // Note: made this duplicate of accruedInterest() for testing
        return _accruedInterest(tokenId);
    }

    function redemptionFeeSpread() external view returns (UD60x18) {
        return _redemptionFeeSpread;
    }

    function defaultFeeSpread() external view returns (UD60x18) {
        return _defaultFeeSpread;
    }

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

    function availableLiquidity() external view returns(uint) {
        return _availableLiquidity();
    }

    function lenderApy() public view returns(UD60x18) {
    //     if (totalDeposits == 0) {
    //         assert(maxTotalUnpaidInterest == 0);
    //         return convert(0);
    //     }
    //     return convert(maxTotalUnpaidInterest).div(convert(totalDeposits)); // Question: is this missing auto-compounding?
    }

    function utilization() public view returns(UD60x18) {
        if (totalDeposits == 0) {
            assert(totalPrincipal == 0);
            return convert(uint(0));
        }
        return convert(totalPrincipal).div(convert(totalDeposits));
    }
}