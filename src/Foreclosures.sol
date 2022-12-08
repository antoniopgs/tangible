// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

type TokenId is uint;

contract Foreclosures {

    enum PropertyStatus { Owned, Auction, Mortgage, Foreclosed, Inspected }

    struct Property {
        PropertyStatus status;
    }

    mapping(TokenId => Property) public properties;

    function foreclose(TokenId tokenId) external {

        // Get property
        Property storage property = properties[tokenId];

        // Ensure current property status is Mortgage
        require(property.status == PropertyStatus.Mortgage);

        // Ensure property is foreclosurable
        require(foreclosurable(property));

        // Change property status to Foreclosed
        property.status = PropertyStatus.Foreclosed;
    }

    function foreclosurable(Property memory property) private returns (bool) {

    }
}