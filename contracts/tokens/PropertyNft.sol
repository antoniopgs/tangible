// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Inheritance
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Other
// import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import "@openzeppelin/contracts/access/IAccessControl.sol";
// import "../../interfaces/logic/IInfo.sol";

contract PropertyNft is ERC721URIStorage, ERC721Enumerable, Ownable(msg.sender) {

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {

    }

    function mint(address to, string memory _tokenURI) external onlyOwner returns(uint newTokenId) {
        newTokenId = totalSupply();
        _safeMint(to, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
    }

    // Question: require payment of transfer fees & sale fees before transfer? Or just build up debt for later?
    // Todo: now even tokens without debt can't be transferred. must always go through admin. implement transferRequest mapping?
    function _update(address to, uint256 tokenId, address auth) internal override(ERC721, ERC721Enumerable) returns (address) {
        // require(IInfo(protocolProxy).isResident(to), "receiver not resident");
        // require(IInfo(protocolProxy).unpaidPrincipal(tokenId) == 0, "cannot transfer token with debt");
        return super._update(to, tokenId, auth);
    }

    // function isApprovedForAll(address owner, address operator) public view override(ERC721, IERC721) returns (bool) {
    //     return super.isApprovedForAll(owner, operator)
    //     || operator == protocolProxy // Note: protocolProxy should always be able to transfer, regardless of approvals // Note: this introduces security implications, revisit later
    //     /* || IAccessControl(protocolProxy).hasRole(PAC, operator)*/; // Note: PAC should always be able to transfer, regardless of approvals
    // }

    // Inheritance Overrides
    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721URIStorage, ERC721) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }
}