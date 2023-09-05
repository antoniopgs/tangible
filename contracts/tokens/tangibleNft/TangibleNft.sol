// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./ITangibleNft.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// import "./residents/Residents.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../../protocol/info/IInfo.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import { PAC } from "../../types/RoleNames.sol";

contract TangibleNft is ITangibleNft, ERC721URIStorage, ERC721Enumerable {

    // Other Vars
    Counters.Counter private _tokenIds;
    address immutable protocolProxy;

    // Libs
    using Counters for Counters.Counter;

    constructor(address _protocolProxy) ERC721("Prospera Real Estate Token", "PROSPERA") {
        protocolProxy = _protocolProxy;
    }

    // Note: tokenURI will point to Prospera Property Registry (example: https://prospera-sure.hn/view/27) we might not even need IPFS
    function mint(address to, string memory _tokenURI) external /* onlyRole(GSP) */ returns (uint newTokenId) {
        newTokenId = _tokenIds.current();
        _safeMint(to, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
        _tokenIds.increment();
    }

    // Todo: require payment of transfer fees & sale fees before transfer? Or just build up debt for later?
    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal override(ERC721, ERC721Enumerable) {
        require(IInfo(protocolProxy).isResident(to), "receiver not resident");
        require(IInfo(protocolProxy).unpaidPrincipal(firstTokenId) == 0, "can't transfer nft with mortgage debt");
        super._beforeTokenTransfer(from, to, 0, batchSize); // is it fine to pass 0 here?
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view override returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender ||
        spender == protocolProxy || IAccessControl(protocolProxy).hasRole(PAC, spender)); // Note: override to allow protocol/PAC to move tokens (don't use operators, as they can be revoked)
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }

    // ----- INHERITANCE OVERRIDES -----
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
}