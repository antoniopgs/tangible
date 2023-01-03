// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../interfaces/ILending.sol";

abstract contract Foreclosures is ILending {

    enum PropertyStatus { Unowned, Auction, Mortgage, Foreclosed }

    struct Property {
        PropertyStatus status;
    }

    mapping(uint => Property) public properties;

    function foreclose(uint tokenId) external {

        // Get property
        Property storage property = properties[tokenId];

        // Ensure current property status is Mortgage
        require(property.status == PropertyStatus.Mortgage);

        // Ensure property is foreclosurable
        require(foreclosurable(property));

        // Change property status to Foreclosed
        property.status = PropertyStatus.Foreclosed;
    }

    function foreclosurable(Loan calldata loan) private returns (bool) {
        return block.timestamp > loan.nextPaymentDeadline;
    }
}