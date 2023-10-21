// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../protocol/Registry.sol";

contract Yield is ERC20, Ownable {

    Registry registry;

    constructor(address protocol) ERC20("Tangible Yield Token", "tUSDC") Ownable(protocol) {
        
    }

    function mint(address account, uint value) external onlyOwner {
        _mint(account, value);
    }

    // Question: should anyone be able to burn their yield tokens?
    function burn(address account, uint value) external onlyOwner {
        _burn(account, value);
    }

    function _update(address from, address to, uint256 value) internal override {
        require(registry.isNotAmerican(to), "receiver might be american");
        super._update(from, to, value);
    }
}