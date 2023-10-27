// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract tUsdc is ERC20("Tangible Protocol Interest-Bearing USDC", "tUSDC") {

    address private immutable protocolProxy;

    constructor(address _protocolProxy) {
        protocolProxy = _protocolProxy;
    }

    function mint(address account, uint256 value) external onlyProtocolProxy {
        _mint(account, value);
    }

    function burn(address account, uint256 value) external onlyProtocolProxy {
        _burn(account, value);
    }

    modifier onlyProtocolProxy {
        require(msg.sender == protocolProxy, "caller not protocol");
        _;
    }

    function _update(address from, address to, uint256 value) internal override {
        require(registry.isNotAmerican(to), "receiver might be american");
        super._update(from, to, value);
    }
}