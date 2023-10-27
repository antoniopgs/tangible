// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../targetManager/TargetManager.sol";
import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";
import { Debt, Loan, Bid } from "../../../types/Types.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../tokens/tUsdc.sol";
import "../../../tokens/tangibleNft/TangibleNft.sol";

abstract contract State is TargetManager {

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
    uint locked;

    // Residents
    mapping(address => uint) internal _addressToResident; // Note: eResident number of 0 will considered "falsy", assuming nobody has it
    mapping(uint => address) internal _residentToAddress;

    mapping(address => bool) internal _notAmerican;

    // Bids
    mapping(uint tokenId => Bid[]) internal _bids; // Todo: figure out multiple bids by same bidder on same nft late
    mapping(uint tokenId => bool bidAccepted) internal pendingBid;

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

    function _availableLiquidity() internal view returns(uint) {
        return _totalDeposits - _totalPrincipal - locked; // Question: - protocolMoney?
    }
}