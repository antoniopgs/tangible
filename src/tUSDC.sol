// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "lib/openzeppelin-contracts/contracts/token/ERC777/ERC777.sol";

contract tUsdc is ERC777 {

    constructor(address[] memory defaultOperators_) ERC777("Tangible USDC", "tUSDC", defaultOperators_) {
        require(defaultOperators_.length == 0); // IMPROVE LATER
    }

    function mint(address account, uint amount) external { // RESTRICT ACCESS LATER
        bytes memory emptyBytes;
        _mint(account, amount, emptyBytes, emptyBytes);
    }
}