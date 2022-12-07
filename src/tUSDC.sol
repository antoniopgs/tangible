// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "lib/openzeppelin-contracts/contracts/token/ERC777/ERC777.sol";

contract tUSDC is ERC777("Tangible USDC", "tUSDC", []) {

    function operatorBurn(address account, XLiqType.XLiq calldata amount) external {
        operatorBurn(account, amount.XLiqToUint(), "", "");
    }

    function mint(address account, XLiqType.XLiq calldata amount) external {
        require(isDefaultOperator(msg.sender), "caller not default operator");
        _mint(account, amount.XLiqToUint(), "", "");
    }
}