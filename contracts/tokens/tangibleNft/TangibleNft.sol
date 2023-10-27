// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./ITangibleNft.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../../protocol/info/IInfo.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import { PAC } from "../../types/RoleNames.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// Todo: override to allow protocol/PAC to move tokens (don't use operators, as they can be revoked)
contract TangibleNft is ITangibleNft, ERC721URIStorage, ERC721Enumerable {

    address immutable protocolProxy;

    constructor(address _protocolProxy) ERC721("Prospera Real Estate Token", "PROSPERA") {
        protocolProxy = _protocolProxy;
    }

    // Note: tokenURI will point to Prospera Property Registry (example: https://prospera-sure.hn/view/27) we might not even need IPFS
    // Note: access control temporarily commented, so that anyone can play with MVP
    function mint(address to, string memory _tokenURI) external /* onlyRole(GSP) */ returns (uint newTokenId) {
        newTokenId = totalSupply();
        _safeMint(to, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
    }

    // Note: tokenIds will be minted sequentially
    // Note: could cause problems if NFTs are burnable
    function exists(uint256 tokenId) external view returns (bool) {
        return tokenId < totalSupply();
    }

    // Question: require payment of transfer fees & sale fees before transfer? Or just build up debt for later?
    function _update(address to, uint256 tokenId, address auth) internal override(ERC721, ERC721Enumerable) returns (address) {
        require(IInfo(protocolProxy).isResident(to), "receiver not resident");
        require(IInfo(protocolProxy).unpaidPrincipal(tokenId) == 0, "cannot transfer token with debt");
        return super._update(to, tokenId, auth);
    }

    function isApprovedForAll(address owner, address operator) public view override(ERC721, IERC721) returns (bool) {
        return super.isApprovedForAll(owner, operator) 
        || IAccessControl(protocolProxy).hasRole(PAC, operator); // Note: PAC should always be able to transfer, regardless of approvals
    }

    // Inheritance Overrides
    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
}