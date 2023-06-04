// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract ERC721Receiver is IERC721Receiver {

    function onERC721Received(address, address from, uint tokenId, bytes calldata data) external returns (bytes4) {

        // Decode
        (bytes4 selector) = abi.decode(data, (bytes4));

        // Validate selector
        require(selector == AcceptNoneBid, "erc721Receiver: unallowed function selector");

        // AcceptNoneBid
        AcceptNone(address(this)).acceptNoneBid({
            borrower: from, // Note: Don't use msg.sender (as it will be the nftContract)
            tokenId: tokenId,
            bidIdx: bidIdx
        });

        // Return required selector
        return this.onERC721Received.selector;
    }
}