// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "forge-std/console.sol";

contract tUsdc is ERC777 {

    constructor(address[] memory defaultOperators_) ERC777("Tangible USDC", "tUSDC", defaultOperators_) {
        console.log(111);
        // require(defaultOperators_.length == 0, "lorem ipsum"); // IMPROVE LATER
    }

    function mint(address account, uint amount) external { // RESTRICT ACCESS LATER
        bytes memory emptyBytes;
        _mint(account, amount, emptyBytes, emptyBytes);
    }
}