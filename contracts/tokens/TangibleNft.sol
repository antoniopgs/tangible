// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TangibleNft is ERC721URIStorage, ERC721Enumerable, Ownable {

    event VerifyEResident(); // Todo: implement this later

    // Mappings
    mapping(address => uint) public addressToEResident; // Note: eResident number of 0 will considered "falsy", assuming nobody has it
    mapping(uint => address) public eResidentToAddress;

    // Other Vars
    uint private tokensCount;
    address protocol;
    address immutable PAC; // Note: Multi-Sig

    constructor(address _protocol, address _PAC) ERC721("Prospera Real Estate Token", "PROSPERA") Ownable(msg.sender) {
        protocol = _protocol;
        PAC = _PAC;
    }

    function _beforeTokenTransfer(address from, address to, uint256, /* firstTokenId */ uint256 batchSize) internal override(ERC721, ERC721Enumerable) {
        require(isEResident(to) || to == protocol, "receiver not eResident or protocol");
        super._beforeTokenTransfer(from, to, 0, batchSize); // is it fine to pass 0 here?
    }

    function verifyEResident(uint eResident, address addr) external onlyOwner {
        require(!isEResident(addr), "address already associated to an eResident");
        require(eResidentToAddress[eResident] == address(0), "eResident already associated to an address");
        addressToEResident[addr] = eResident;
        eResidentToAddress[eResident] = addr;
    }

    function mint(address to, string memory _tokenURI) external onlyOwner returns (uint newTokenId) {
        _safeMint(to, tokensCount);
        _setTokenURI(newTokenId, _tokenURI);
        tokensCount ++;
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view override returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender || spender == PAC);
    }

    // ----- VIEWS -----
    function isEResident(address addr) public view returns (bool) {
        return addressToEResident[addr] != 0;
    }

    // ----- NECESSARY OVERRIDES -----
    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
}