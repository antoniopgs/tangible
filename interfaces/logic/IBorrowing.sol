// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";
import "../state/IState.sol";

interface IBorrowing is IState { // Todo: fix later

    // Events
    event StartLoan(UD60x18 ratePerSecond, UD60x18 paymentPerSecond, uint principal, uint maxDurationMonths, uint timestamp);
    event PayLoan(address caller, uint tokenId, uint payment, uint interest, uint repayment, uint timestamp, bool paidOff);
    event RedeemLoan(address caller, uint tokenId, uint interest, uint defaulterDebt, uint redemptionFee, uint timestamp);
    event DebtIncrease(uint tokenId, uint amount, string motive, uint timestamp);
    event DebtDecrease(uint tokenId, uint amount, string motive, uint timestamp);

    // Views
    function utilization() external view returns(UD60x18);
    function borrowerApr() external view returns(UD60x18 apr);

    // User Functions
    function payMortgage(uint tokenId, uint payment) external;
    
    // Admin Functions
    function foreclose(uint tokenId) external;

    // Other
    function debtTransfer(uint tokenId, address seller, Bid memory _bid) external; // only callable indirectly
}