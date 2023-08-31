// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface IBorrowingMath {
    function loanChart(uint tokenId) external view returns(uint[] memory x, uint[] memory y);
}