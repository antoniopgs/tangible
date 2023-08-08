// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../borrowing/status/IStatus.sol";
import "../state/state/IState.sol";

interface IInfo is IStatus, IState {

    // Pool Info
    function availableLiquidity() external view returns(uint);
    function utilization() external view returns(UD60x18);
    function borrowerApr() external view returns(UD60x18 apr);
    function lenderApy() external view returns(UD60x18);

    // Loan Info
    function unpaidPrincipal(uint tokenId) external view returns(uint);
    function accruedInterest(uint tokenId) external view returns(uint);

    // tUsdc Info
    function usdcToTUsdc(uint usdcAmount) external view returns(uint tUsdcAmount);
    function tUsdcToUsdc(uint tUsdcAmount) external view returns(uint usdcAmount);

    // Fees Info
    function baseSaleFeeSpread() external view returns(UD60x18);
    function interestFeeSpread() external view returns(UD60x18);
    function redemptionFeeSpread() external view returns(UD60x18);
    function defaultFeeSpread() external view returns(UD60x18);

    function status(uint tokenId) external view returns (Status);
    function userLoans(address user) external view returns (uint[] memory userLoansTokenIds);
    function loansTokenIdsLength() external view returns (uint);
    function loansTokenIdsAt(uint idx) external view returns (uint tokenId);
    function loans(uint tokenId) external view returns (Loan memory);
}