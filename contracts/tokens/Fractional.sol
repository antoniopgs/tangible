// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Fractional is Ownable {

    // Vars
    uint private constant ONE_HUNDRED_PCT_SHARES = 100 * 1e18;
    uint private tokenCount;

    // Mappings
    mapping(address user => mapping(uint tokenId => uint balance)) balances;
    mapping(uint256 tokenId => string URI) private URIs;

    constructor(address issuer) Ownable(issuer) {
        
    }

    // Issuer
    function mint(string memory _tokenURI, address to) external onlyOwner onlyToResident(to) returns (uint newTokenId) {

        // Get newTokenId
        newTokenId = tokenCount;

        // Mint new token
        balances[to][newTokenId] = ONE_HUNDRED_PCT_SHARES;

        // Store new token's URI
        URIs[newTokenId] = _tokenURI;

        // Increment tokenCount
        tokenCount++;
    }
    
    // Users
    function transfer(uint tokenId, uint amount, address to) external onlyToResident(to) {

    }

    // Views
    function isResident(address addr) public view returns(bool) {

    }

    function isNotAmerican(address addr) public view returns(bool) {

    }

    modifier onlyToResident(address addr) {
        require(isResident(addr), "addr not resident");
        _;
    }
}