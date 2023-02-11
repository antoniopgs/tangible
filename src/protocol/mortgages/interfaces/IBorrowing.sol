// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

interface IBorrowing {

    event NewLoan(string propertyUri, UD60x18 propertyValue, UD60x18 principal, address borrower, address seller, uint time);
    event LoanPayment(string propertyUri, address payer, uint time, bool finalPayment);

    enum State { Null, Mortgage, Default, Foreclosed }

    function startLoan(string calldata propertyUri, UD60x18 propertyValue, UD60x18 principal, address borrower, address seller) external;
    function payLoan(string calldata propertyUri) external;
}
