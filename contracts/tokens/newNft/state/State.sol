// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IState.sol";
import "../roles/Roles.sol";
import { convert } from "@prb/math/src/UD60x18.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../tUsdc.sol";

abstract contract State is IState, Roles {

    bool public initialized; // Question: do I actually need this?
    
    // Links
    IERC20 public /* immutable */ USDC;
    tUsdc tUSDC;

    // Pool
    uint public totalPrincipal;
    uint public totalDeposits;

    // Debts
    mapping(uint => Debt) public debts;

    // Bids
    mapping(uint => Bid[]) public bids; // Todo: figure out multiple bids by same bidder on same nft later

    // Residents
    mapping(address => uint) public addressToResident; // Note: eResident number of 0 will considered "falsy", assuming nobody has it
    mapping(uint => address) public residentToAddress;

    // Other Vars
    UD60x18 public maxLtv = convert(50).div(convert(100)); // Note: 50%
    uint public maxLoanMonths = 120; // Note: 10 years





    // Time constants
    uint public constant yearSeconds = 365 days;
    uint public constant yearMonths = 12;
    uint public constant monthSeconds = yearSeconds / yearMonths; // Note: yearSeconds % yearMonths = 0 (no precision loss)

    // NFT Status
    enum Status { ResidentOwned, Mortgage, Default }
}