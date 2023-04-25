// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TangibleNft is ERC721URIStorage, Ownable {

    // Mappings
    mapping(address => bool) public isEResident; // Question: maybe move this to protocol
    mapping(uint => address) public eResidentAddress; // Question: maybe move this to protocol

    // Vars
    Counters.Counter private _tokenIds;

    // Libs
    using Counters for Counters.Counter;

    constructor() ERC721("Prospera Real Estate Token", "PROSPERA") {

    }

    function mint(address to, string memory _tokenURI) external onlyOwner returns (uint newTokenId) {
        newTokenId = _tokenIds.current();
        _safeMint(to, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
        _tokenIds.increment();
    }

    function _beforeTokenTransfer(address from, address to, uint256, /* firstTokenId */ uint256 batchSize) internal override {
        require(isEResident[to], "receiver not eResident");
        super._beforeTokenTransfer(from, to, 0, batchSize); // is it fine to pass 0 here?
    }

    function verifyEResident(uint eResidentId, address eResidentAddr) external onlyOwner {
        require(!isEResident[eResidentAddr], "address already associated to an eResident");
        require(eResidentAddress[eResidentId] == address(0), "eResidentId already associated to an address");
        isEResident[eResidentAddr] = true;
        eResidentAddress[eResidentId] = eResidentAddr;
    }
}