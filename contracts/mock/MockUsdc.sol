// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUsdc is ERC20("Mock USDC", "USDC") {

    function mint(address account, uint amount) external {
        _mint(account, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6; // Note: override to same decimals as USDC
    }
}