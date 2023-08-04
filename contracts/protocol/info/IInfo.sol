// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/IState.sol";

interface IInfo is IState {

    // struct BidInfo {
    //     uint tokenId;
    //     uint idx;
    //     Bid bid;
    // }
    
    function loans(uint tokenId) external view returns (Loan memory);

    function availableLiquidity() external view returns(uint);

    function userLoans(address user) external view returns (uint[] memory userLoansTokenIds);
    // function userBids(address user) external view returns(BidInfo[] memory _userBids);

    function loansTokenIdsLength() external view returns (uint);
    function loansTokenIdsAt(uint idx) external view returns (uint tokenId);

    function accruedInterest(uint tokenId) external view returns(uint);

    function lenderApy() external view returns(UD60x18);

    function tUsdcToUsdc(uint tUsdcAmount) external view returns(uint usdcAmount);

    // function bidActionable(uint tokenId, uint bidIdx) external view returns(bool);

    function baseSaleFeeSpread() external view returns(UD60x18);
    function interestFeeSpread() external view returns(UD60x18);
    function redemptionFeeSpread() external view returns(UD60x18);
    function defaultFeeSpread() external view returns(UD60x18);
}