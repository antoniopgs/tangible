// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface ITangibleNft2 {
    
    function mint(address to, string memory _tokenURI) external returns (uint newTokenId);
}