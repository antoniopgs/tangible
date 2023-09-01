// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/State.sol";

contract Initializer is State {

    function initialize(
        address _USDC,
        address _tUSDC,
        address _tangibleNft,
        address tangible, // Note: Multi-Sig
        address gsp, // Note: Multi-Sig
        address pac // Note: Multi-Sig
    ) external {

        // Ensure this is 1st and only Initialization
        require(!initialized, "already initialized");
        initialized = true;

        initializeContractLinks(_USDC, _tUSDC, _tangibleNft);
        initializeState();
        initializeRoles(tangible, gsp, pac);
    }

    function initializeContractLinks(address _USDC, address _tUSDC, address _tangibleNft) private {
        USDC = IERC20(_USDC);
        tUSDC = tUsdc(_tUSDC);
        tangibleNft = TangibleNft(_tangibleNft);
    }

    function initializeState() private {

        // Pool Vars
        optimalUtilization = convert(90).div(convert(100)); // Note: 90%

        // Other Vars
        maxLtv = convert(50).div(convert(100)); // Note: 50%
        maxLoanMonths = 120; // Note: 10 years
        redemptionWindow = 45 days;

        // Interest vars
        m1 = convert(4).div(convert(100)); // Note: 0.04
        b1 = convert(3).div(convert(100)); // Note: 0.03
        m2 = convert(9); // Note: 9

        // Fees/Spreads
        _baseSaleFeeSpread = convert(1).div(convert(100)); // Note: 1%
        _interestFeeSpread = convert(2).div(convert(100)); // Note: 2%
        _redemptionFeeSpread = convert(3).div(convert(100)); // Note: 3%
        _defaultFeeSpread = convert(4).div(convert(100)); // Note: 4%

    }
}