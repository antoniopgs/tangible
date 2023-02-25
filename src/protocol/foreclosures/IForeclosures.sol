// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../borrowing/IBorrowing.sol";

interface IForeclosures is IBorrowing {
    
    function defaulted(Loan calldata loan) external view returns (bool);
    function foreclose(Loan calldata loan) external;
    function chainlinkForeclose(Loan calldata loan) external;
}
