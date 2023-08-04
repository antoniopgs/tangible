// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../borrowing/status/IStatus.sol";
import "../state/state/IState.sol";

interface IInfo is IStatus, IState {
    
    function loans(uint tokenId) external view returns (Loan memory);

    function availableLiquidity() external view returns(uint);

    function userLoans(address user) external view returns (uint[] memory userLoansTokenIds);

    function loansTokenIdsLength() external view returns (uint);
    function loansTokenIdsAt(uint idx) external view returns (uint tokenId);

    function accruedInterest(uint tokenId) external view returns(uint);

    function lenderApy() external view returns(UD60x18);

    function usdcToTUsdc(uint usdcAmount) external view returns(uint tUsdcAmount);
    function tUsdcToUsdc(uint tUsdcAmount) external view returns(uint usdcAmount);

    function baseSaleFeeSpread() external view returns(UD60x18);
    function interestFeeSpread() external view returns(UD60x18);
    function redemptionFeeSpread() external view returns(UD60x18);
    function defaultFeeSpread() external view returns(UD60x18);

    function status(uint tokenId) external view returns (Status);
}