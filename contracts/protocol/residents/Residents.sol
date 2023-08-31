// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IResidents.sol";
import "../state/state/State.sol";

contract Residents is IResidents, State {

    function verifyResident(address addr, uint resident) external onlyRole(GSP) { // Todo: add functionality to update resident address
        require(!_isResident(addr), "address already associated to an eResident");
        require(_residentToAddress[resident] == address(0), "resident already associated to an address");
        _addressToResident[addr] = resident;
        _residentToAddress[resident] = addr;
    }
}