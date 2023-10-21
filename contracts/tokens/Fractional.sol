// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../protocol/Registry.sol";

contract Fractional is Ownable {

    // Links
    Registry registry;

    // Vars
    uint private constant ONE_HUNDRED_PCT_SHARES = 100 * 1e18;
    uint private tokenCount;

    // Mappings
    mapping(address user => mapping(uint tokenId => uint balance)) balances;
    mapping(uint256 tokenId => string URI) private URIs;

    constructor(address issuer) Ownable(issuer) {

    }

    // Issuer
    function mint(string memory _tokenURI, address to) external onlyOwner returns (uint newTokenId) {

        // Get newTokenId
        newTokenId = tokenCount;

        // Mint new token
        balances[to][newTokenId] = ONE_HUNDRED_PCT_SHARES;

        // Store new token's URI
        URIs[newTokenId] = _tokenURI;

        // Increment tokenCount
        tokenCount++;
    }

    function _update(address from, address to, uint256 value) internal override {
        require(registry.isResident(to), "receiver isn't resident");
        require(registry.isNotAmerican(to), "receiver might be american");
        super._update(from, to, value);
    }
}