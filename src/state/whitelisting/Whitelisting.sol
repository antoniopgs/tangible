// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Whitelisting is Ownable {

    mapping(address => bool) public whitelisted;

    function whitelist(address[] calldata users, bool status) external onlyOwner {
        
        for (uint i = 0; i < users.length; i++) {
            whitelisted[users[i]] = status;
        }
    }

    modifier ifWhitelisted {
        require(whitelisted[msg.sender], "caller not whitelisted");
        _;
    } 
}