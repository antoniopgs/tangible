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

        // Initialize state
        USDC = IERC20(_USDC);
        tUSDC = tUsdc(_tUSDC);
        tangibleNft = TangibleNft(_tangibleNft);
        initializeRoles(tangible, gsp, pac);
    }
}