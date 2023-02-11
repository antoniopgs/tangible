// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

interface IBorrowing {
    function startLoan(uint tokenId, UD60x18 propertyValue, UD60x18 principal, address borrower, address seller) external;
    function payLoan(uint tokenId) external;
    function propertyEquity(uint tokenId) external view returns (UD60x18 equity);
}
