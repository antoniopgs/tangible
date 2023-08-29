// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IResidents.sol";
import "../state/State.sol";

contract Residents is IResidents, State {

    function verifyResident(address addr, uint resident) external onlyRole(GSP) { // Todo: add functionality to update resident address
        require(!_isResident(addr), "address already associated to an eResident");
        require(residentToAddress[resident] == address(0), "resident already associated to an address");
        addressToResident[addr] = resident;
        residentToAddress[resident] = addr;
    }

    function _isResident(address addr) internal view returns (bool) {
        return addressToResident[addr] != 0; // Note: eResident number of 0 will considered "falsy", assuming nobody has it
    }
}