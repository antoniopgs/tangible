// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Borrowing.sol";

abstract contract Foreclosures is Borrowing {

    enum PropertyStatus { Unowned, Auction, Mortgage, Foreclosed }

    struct Property {
        PropertyStatus status;
    }

    mapping(string => Property) public properties;

    function foreclose(string calldata propertyUri) external {

        // Get property
        Property storage property = properties[propertyUri];

        // Ensure current property status is Mortgage
        require(property.status == PropertyStatus.Mortgage);

        // Ensure property is foreclosurable
        require(foreclosurable(loans[propertyUri]));

        // Change property status to Foreclosed
        property.status = PropertyStatus.Foreclosed;
    }

    function foreclosurable(Loan memory loan) private view returns (bool) {
        return block.timestamp > loan.nextPaymentDeadline + (30 days * allowedDelayedPayments);
    }
}