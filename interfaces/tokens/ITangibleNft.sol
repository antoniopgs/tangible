// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface ITangibleNft {
    
    function mint(address to, string memory _tokenURI) external returns (uint newTokenId);
    // function burn(uint tokenId) external; // Question: should I even allow this? maybe as offboard mechanism? and if so, should user or admin call it?
    function exists(uint256 tokenId) external view returns (bool);
}