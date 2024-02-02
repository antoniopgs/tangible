// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/State.sol";

contract Initializer is State {

    function initialize(
        IERC20 _UNDERLYING,
        SharesToken _SHARES,
        PropertyNft _PROPERTY
    ) external {

        // Ensure this is 1st and only Initialization
        require(!initialized, "already initialized");

        initializeContractLinks(_UNDERLYING, _SHARES, _PROPERTY);
        initializeState();

        // Set to initialized
        initialized = true;
    }

    function initializeContractLinks(IERC20 _UNDERLYING, SharesToken _SHARES, PropertyNft _PROPERTY) private {
        UNDERLYING = _UNDERLYING;
        SHARES = _SHARES;
        PROPERTY = _PROPERTY;
    }

    function initializeState() private {

        // Pool Vars
        _optimalUtilization = convert(90).div(convert(100)); // Note: 90%

        // Other Vars
        _maxLtv = convert(50).div(convert(100)); // Note: 50%
        _maxLoanMonths = 120; // Note: 10 years

        // Fees/Spreads
        _baseSaleFeeSpread = convert(1).div(convert(100)); // Note: 1%
        _redemptionFeeSpread = convert(2).div(convert(100)); // Note: 2%
        _defaultFeeSpread = convert(3).div(convert(100)); // Note: 3%
    }
}