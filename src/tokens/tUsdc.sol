// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

contract tUsdc is ERC777 {

    constructor(address[] memory defaultOperators_) ERC777("Tangible USDC", "tUSDC", defaultOperators_) {

    }

    function defaultOperatorMint(address account, uint amount) external {
        require(isDefaultOperator(msg.sender), "caller not default operator");
        _mint(account, amount, "", "");
    }

    // Note: will return true for default operators, but false for non-default operators, so long as:
    // - address(this) isn't msg.sender
    // - address(this) doesn't revoke any defaultOperators
    // - address(this) never calls authorizeOperator()
    function isDefaultOperator(address operator) private view returns (bool) {
        return isOperatorFor(operator, address(this));
    }
}