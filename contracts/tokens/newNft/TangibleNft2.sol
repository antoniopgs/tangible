// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./ITangibleNft2.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./residents/Residents.sol";
// import "./debt/Debt.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TangibleNft2 is ITangibleNft2, ERC721URIStorage, ERC721Enumerable, Residents /*, Debt */ {

    // Other Vars
    Counters.Counter private _tokenIds;

    // Libs
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    constructor() ERC721("Prospera Real Estate Token", "PROSPERA") {

    }

    // Note: tokenURI will point to Prospera Property Registry (example: https://prospera-sure.hn/view/27) we might not even need IPFS
    function mint(address to, string memory _tokenURI) external onlyRole(GSP) returns (uint newTokenId) {
        newTokenId = _tokenIds.current();
        _safeMint(to, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
        _tokenIds.increment();
    }

    // Todo: require payment of transfer fees & sale fees before transfer? Or just build up debt for later?
    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal override(ERC721, ERC721Enumerable) {
        require(_isResident(to), "receiver not resident");
        require(debts[firstTokenId].loan.unpaidPrincipal == 0, "can't transfer nft with mortgage debt");
        super._beforeTokenTransfer(from, to, 0, batchSize); // is it fine to pass 0 here?
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view override returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender ||
        hasRole(PAC, spender)); // Note: Overriden to allow PAC to move tokens
    }

    // ----- INHERITANCE OVERRIDES -----
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable, ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
}