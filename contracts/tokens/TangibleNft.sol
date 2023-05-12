// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TangibleNft is ERC721URIStorage, ERC721Enumerable, Ownable {

    // Mappings
    mapping(address => uint) public addressToEResident; // Note: eResident number of 0 will considered "falsy", assuming nobody has it
    mapping(uint => address) public eResidentToAddress;

    // Other Vars
    Counters.Counter private _tokenIds;
    address protocol;

    // Libs
    using Counters for Counters.Counter;

    constructor(address _protocol) ERC721("Prospera Real Estate Token", "PROSPERA") {
        protocol = _protocol;
    }

    function _beforeTokenTransfer(address from, address to, uint256, /* firstTokenId */ uint256 batchSize) internal override(ERC721, ERC721Enumerable) {
        require(isEResident(to) || to == protocol, "receiver not eResident or protocol");
        super._beforeTokenTransfer(from, to, 0, batchSize); // is it fine to pass 0 here?
    }

    function verifyEResident(uint eResident, address addr) public { // Todo: limit access later
        require(!isEResident(addr), "address already associated to an eResident");
        require(eResidentToAddress[eResident] == address(0), "eResident already associated to an address");
        addressToEResident[addr] = eResident;
        eResidentToAddress[eResident] = addr;
    }

    function mint(address to, string memory _tokenURI) external returns (uint newTokenId) { // Todo: limit access later
        newTokenId = _tokenIds.current();
        _safeMint(to, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
        _tokenIds.increment();
    }

    // ----- VIEWS -----
    function isEResident(address addr) public view returns (bool) {
        return addressToEResident[addr] != 0;
    }

    // ----- NECESSARY OVERRIDES -----
    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
}