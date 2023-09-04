// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { Status } from "../../types/Types.sol";

interface ILoanStatus {
    function status(uint tokenId) external view returns(Status); // Todo: maybe move this to info?
    function loanChart(uint tokenId) external view returns(uint[] memory x, uint[] memory y); // Todo: maybe move this to info?
}