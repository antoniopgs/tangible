// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../pool/IPool.sol";

interface IForeclosures is IPool {
    
    function defaulted(Loan calldata loan) external view returns (bool);
    function foreclose(Loan calldata loan) external;
    function chainlinkForeclose(Loan calldata loan) external;
}
