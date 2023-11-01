// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../targetManager/TargetManager.sol";
import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";
import { Debt, Loan, Bid } from "../../../types/Types.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../tokens/tUsdc.sol";
import "../../../tokens/tangibleNft/TangibleNft.sol";

abstract contract State is TargetManager {

    // Links
    IERC20 public UNDERLYING;
    tUsdc public YIELD;

    // Pool
    uint internal _totalPrincipal;
    uint internal _totalDeposits;

    // Whitelist
    mapping(address => uint) internal _addressToResident; // Note: eResident number of 0 will considered "falsy", assuming nobody has it
    mapping(uint => address) internal _residentToAddress;
    mapping(address => bool) internal _notAmerican;

    function _isResident(address addr) internal view returns (bool) {
        return _addressToResident[addr] != 0; // Note: eResident number of 0 will considered "falsy", assuming nobody has it
    }
}