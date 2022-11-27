// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract ProsperaNft is ERC721 {

    // metadata
    string[] inspections;
    // restrict transfers to eResidents only

    function addInspection() external /* onlyInspector */ {

    }

    function updateMetadata() external /* onlyOwner */ {

    }

    // function lastUpdateInspected() external view returns (bool) {
    //     return inspections[inspections.length - 1].inspectionTime > metadata.lastUpdateTime;
    // }
}