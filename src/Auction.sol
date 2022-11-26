// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";

library AuctionLib {

    struct Bid {
        address bidder;
        uint bid;
    }

    struct Auction {
        uint buyoutPrice;
        Bid highestBid;
        uint propertyTokenId;
    }

    function auction() public {

        // Pull NFT from seller


    }

    function buyout() public {
        
        // Transfer buyout money to 

    }

    function bid(Auction storage auction, uint _bid) public {
        require(_bid > auction.highestBid.bid, "new bid must be greater than current highest bid");

        // Update auction's highestBid
        auction.highestBid = Bid({
            bidder: msg.sender,
            bid: _bid
        });
    }

    function acceptBid() public {

    }
}