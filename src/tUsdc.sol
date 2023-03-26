// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

contract tUsdc is ERC777 {

    constructor(address[] memory defaultOperators_) ERC777("Tangible USDC", "tUSDC", defaultOperators_) {
        
    }

    function mint(address account, uint amount) external {
        require(isDefaultOperator(msg.sender), "caller not default operator");
        _mint(account, amount, "", "");
    }

    function isDefaultOperator(address operator) private view returns (bool) {
        return isOperatorFor(operator, address(this));
    }
}