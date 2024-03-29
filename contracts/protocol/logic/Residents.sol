// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../interfaces/logic/IResidents.sol";
import "../state/State.sol";

contract Residents is IResidents, State {

    // Todo: add functionality to update resident address
    // Note: access control temporarily commented, so that anyone can play with MVP
    function verifyResident(address addr, uint resident) external onlyOwner {
        require(!_isResident(addr), "address already associated to an eResident");
        require(_residentToAddress[resident] == address(0), "resident already associated to an address");
        _addressToResident[addr] = resident;
        _residentToAddress[resident] = addr;
    }
}