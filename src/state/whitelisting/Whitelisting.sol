// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Whitelisting is Ownable {

    mapping(address => uint) public addressToResidentId; // Note: eResident number of 0, it will considered "falsy"

    function whitelist(address[] calldata users, uint[] calldata eResidentNumbers) external onlyOwner {
        require(users.length == eResidentNumbers.length, "unequal array param lengths");
        
        for (uint i = 0; i < users.length; i++) {
            addressToResidentId[users[i]] = eResidentNumbers[i];
        }
    }

    modifier ifWhitelisted {
        require(addressToResidentId[msg.sender] != 0, "caller not whitelisted");
        _;
    } 
}