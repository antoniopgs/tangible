// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

contract tUsdc is ERC777 {

    constructor(address[] memory defaultOperators_) ERC777("Tangible USDC", "tUSDC", defaultOperators_) {

    }

    function operatorMint(address account, uint amount) external { // Todo: RESTRICT ACCESS LATER
        _mint(account, amount, "", "");
    }
}