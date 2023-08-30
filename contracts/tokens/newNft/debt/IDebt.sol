// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";

interface IDebt {

    // Events
    event StartLoan(UD60x18 ratePerSecond, UD60x18 paymentPerSecond, uint principal, uint maxDurationMonths, uint timestamp);
    event PayLoan(address caller, uint tokenId, uint payment, uint interest, uint repayment, uint timestamp, bool paidOff);
    event RedeemLoan(address caller, uint tokenId, uint interest, uint defaulterDebt, uint redemptionFee, uint timestamp);
    event DebtIncrease(uint tokenId, uint amount, string motive, uint timestamp);
    event DebtDecrease(uint tokenId, uint amount, string motive, uint timestamp);

    // User Functions
    function payMortgage(uint tokenId, uint payment) external;
    function redeemMortgage(uint tokenId) external;

    // Admin Functions
    // function refinance(uint tokenId) external;
    function foreclose(uint tokenId) external;
    function increaseOtherDebt(uint tokenId, uint amount, string calldata motive) external;
    function decreaseOtherDebt(uint tokenId, uint amount, string calldata motive) external;
}