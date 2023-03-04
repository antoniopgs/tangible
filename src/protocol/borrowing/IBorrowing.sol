// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../pool/IPool.sol";

interface IBorrowing {
    
    event NewLoan(tokenId _tokenId, uint propertyValue, uint principal, address borrower, address seller, uint time);
    event LoanPayment(tokenId _tokenId, address payer, uint time, bool finalPayment);

    function startLoan(tokenId _tokenId, uint propertyValue, uint principal, address borrower) external;
    function payLoan(tokenId _tokenId) external;
    function maxLtv() external view returns (uint);
}
