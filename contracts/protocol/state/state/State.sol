// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../targetManager/TargetManager.sol";
import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";
import { Debt, Loan, Bid } from "../../../types/Types.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../tokens/tUsdc.sol";
import "../../../tokens/tangibleNft/TangibleNft.sol";

abstract contract State is TargetManager {

    // Time constants
    uint public constant yearSeconds = 365 days;
    uint public constant yearMonths = 12;
    uint public constant monthSeconds = yearSeconds / yearMonths; // Note: yearSeconds % yearMonths = 0 (no precision loss)

    uint public protocolMoney; // Question: do I actually need this?
    bool public initialized;

    // Links
    IERC20 public USDC;
    tUsdc public tUSDC;
    TangibleNft public tangibleNft;

    // Pool
    uint internal _totalPrincipal;
    uint internal _totalDeposits;
    UD60x18 internal _optimalUtilization;

    // Residents
    mapping(address => uint) internal _addressToResident; // Note: eResident number of 0 will considered "falsy", assuming nobody has it
    mapping(uint => address) internal _residentToAddress;

    // Bids
    mapping(uint => Bid[]) internal _bids; // Todo: figure out multiple bids by same bidder on same nft late

    // Debts
    mapping(uint => Debt) internal _debts;

    // Loan Terms
    UD60x18 internal _maxLtv;
    uint internal _maxLoanMonths;
    uint internal _redemptionWindow;

    // Fees/Spreads
    UD60x18 internal _baseSaleFeeSpread;
    UD60x18 internal _interestFeeSpread;
    UD60x18 internal _redemptionFeeSpread;
    UD60x18 internal _defaultFeeSpread;

    // Interest vars
    UD60x18 internal m1;
    UD60x18 internal b1;
    UD60x18 internal m2;

    function _isResident(address addr) internal view returns (bool) {
        return _addressToResident[addr] != 0; // Note: eResident number of 0 will considered "falsy", assuming nobody has it
    }

    function _accruedInterest(Loan memory loan) internal view returns(uint) {
        return convert(convert(loan.unpaidPrincipal).mul(accruedRate(loan)));
    }

    function accruedRate(Loan memory loan) private view returns(UD60x18) {
        return loan.ratePerSecond.mul(convert(secondsSinceLastPayment(loan)));
    }

    function secondsSinceLastPayment(Loan memory loan) private view returns(uint) {
        return block.timestamp - loan.lastPaymentTime;
    }
}