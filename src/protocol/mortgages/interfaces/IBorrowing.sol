// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

interface IBorrowing {
    function startLoan(string calldata propertyUri, UD60x18 propertyValue, UD60x18 principal, address borrower, address seller) external;
    function payLoan(string calldata propertyUri) external;
    function propertyEquity(string calldata propertyUri) external view returns (UD60x18 equity);
}
