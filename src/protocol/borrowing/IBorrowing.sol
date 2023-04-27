// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/IState.sol";

interface IBorrowing is IState {

    // Functions
    function startLoan(uint tokenId, uint propertyValue, uint downPayment, uint maxDurationMonths) external;
    function payLoan(uint tokenId, uint payment) external;
    function redeemLoan(uint tokenId) external;
    function forecloseLoan(uint tokenId, uint bidIdx) external;

    // Views
    function lenderApy() external view returns(UD60x18);
    function principalCap(Loan memory loan, uint month) external pure returns(uint cap);
    function status(uint tokenId) external view returns (Status);
    function utilization() external view returns(UD60x18);
    function availableLiquidity() /* private */ external view returns(uint);
}