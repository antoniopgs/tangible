// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

type eResidencyId is uint256;

contract Savings {

    address prospera;

    struct Bid {
        address bidder;
        uint bid;
    }

    struct Auction {
        uint buyoutPrice;
        Bid highestBid;
        uint propertyTokenId;
    }

    mapping(eResidencyId => address) public borrowers;

    // called by supplier
    function supply() external {

    }

    // called by supplier
    function withdraw() external {

    }

    // called by GSP
    function mint(eResidencyId propertyOwner, bytes calldata propertyInfo) external onlyProspera {
        
    }

    function takeoutLoan() external {

    }

    function repay() external {

    }

    modifier onlyProspera {
        require(msg.sender == prospera, "caller not prospera");
        _;
    }
}