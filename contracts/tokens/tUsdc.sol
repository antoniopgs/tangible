// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract tUsdc is ERC20 {

    address immutable protocolProxy;

    constructor(address _protocolProxy) ERC20("Tangible USDC", "tUSDC") {
        protocolProxy = _protocolProxy;
    }

    function mint(address account, uint amount) external {
        require(msg.sender == protocolProxy, "only protocolProxy can mint");
        _mint(account, amount);
    }
}