// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

type eResidencyId is uint256;

contract Savings {

    address prospera;

    struct Bidder {
        address addr;
        uint bid;
    }

    struct Auction {
        Bidder highestBidder;
        uint buyoutPrice;
        uint propertyTokenId;
    }

    mapping(eResidencyId => address) public borrowers;

    function supply() external {

    }

    function mint(eResidencyId propertyOwner, bytes calldata propertyInfo) external onlyProspera {
        
    }

    function verifyLender(eResidencyId id, address borrowerAddr) external onlyProspera {
        require(borrowers[id] == address(0), "eResidencyId already associated to address");
        borrowers[id] = borrowerAddr;
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