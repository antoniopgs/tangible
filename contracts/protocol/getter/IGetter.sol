// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/IState.sol";

interface IGetter is IState {

    struct BidInfo {
        uint tokenId;
        uint idx;
        Bid bid;
    }
    
    function bids(uint tokenId) external view returns (Bid[] memory);
    function availableLiquidity() external view returns(uint);
    function myLoans() external view returns (uint[] memory myLoansTokenIds);
    function myBids() external view returns(BidInfo[] memory _myBids);
    function loansTokenIdsLength() external view returns (uint);
    function loans(uint tokenId) external view returns (Loan memory);
    function redemptionFeeSpread() external view returns (UD60x18);
    function defaultFeeSpread() external view returns (UD60x18);
    function accruedInterest(uint tokenId) external view returns(uint);
}