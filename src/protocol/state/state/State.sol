// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IState.sol";
import "../targetManager/TargetManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../tokens/tUsdc.sol";
import "../../../tokens/TangibleNft.sol";

import "@prb/math/UD60x18.sol";

abstract contract State is IState, TargetManager {

    // Tokens
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // ethereum
    tUsdc tUSDC;
    TangibleNft internal prosperaNftContract;

    // Mappings
    mapping(uint => Bid[]) bids;
    mapping(uint => Loan) public loans;

    // Math Vars
    UD60x18 totalBorrowed;
    UD60x18 totalDeposits;
    
    // Borrowing Vars
    uint maxLtv;
    UD60x18 internal installmentCount;
    UD60x18 public utilizationCap;
    UD60x18 internal periodicBorrowerRate;

    // Foreclosure vars
    UD60x18 foreclosureFeeRatio;
    UD60x18 foreclosurerCutRatio;

    function utilization() public view returns (UD60x18) {
        return totalBorrowed.div(totalDeposits);
    }
}
