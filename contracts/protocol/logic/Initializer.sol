// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/State.sol";

contract Initializer is State {

    function initialize(
        IERC20 _UNDERLYING,
        PropertyNft _PROPERTY,
        Vault _VAULT
    ) external {
        require(address(_UNDERLYING) != address(0), "underlying can't be address(0)");
        require(address(_PROPERTY) != address(0), "property can't be address(0)");

        // Ensure this is 1st and only Initialization
        require(!initialized, "already initialized");

        initializeContractLinks(_UNDERLYING, _PROPERTY, _VAULT);
        initializeState();

        // Set to initialized
        initialized = true;
    }

    function initializeContractLinks(IERC20 _UNDERLYING, PropertyNft _PROPERTY, Vault _VAULT) private {
        UNDERLYING = _UNDERLYING;
        PROPERTY = _PROPERTY;
        vault = _VAULT;
    }

    function initializeState() private {
        
        _maxLtv = convert(50).div(convert(100)); // Note: 50%
        _maxLoanMonths = 120; // Note: 10 years
    }
}