// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUsdc is ERC20("Mock USDC", "mUSDC") {

    function mint(address account, uint amount) external {
        _mint(account, amount);
    }
}