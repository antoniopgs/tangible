// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

type tokenId is uint;
type idx is uint;

library PropertySet {

    struct Bid {
        address bidder;
        uint propertyValue;
        uint downPayment;
    }

    struct Loan {
        address borrower;
        UD60x18 balance;
        UD60x18 installment;
        UD60x18 unpaidInterest;
        uint nextPaymentDeadline;
    }

    struct Property {
        Bid[] bids;
        Loan loan;
    }

    struct Set {
        mapping(tokenId => bool) contains;
        mapping(tokenId => idx) indexes;
        Property[] properties;
    }

    function get(Set storage set, tokenId _tokenId) internal view returns(Property memory) {
        return set.properties[idx.unwrap(set.indexes[_tokenId])];
    }

    function at(Set storage set, idx _idx) internal view returns(Property memory) {
        return set.properties[idx.unwrap(_idx)];
    }

    function length(Set storage set) internal view returns(uint) {
        return set.properties.length;
    }

    function add(Set storage set, Property memory property) internal {
        require(!set.contains[_tokenId], "set already contains property");

        // Push property into properties
        set.properties.push(property);

        // Store property idx
        set.indexes[_tokenId] = set.length() - 1;

        // Update contains
        set.contains[tokenId] = true;
    }

    function remove(Set storage set, Property memory property) internal {
        require(set.contains[tokenId], "set doesn't contain property");

        // Get index of property to remove
        uint idxToRemove = set.indexes[tokenId];

        // Get last property
        Property memory lastProperty = set.properties[set.length() - 1];

        // Write lastProperty over idxToRemove
        set.values[idxToRemove] = lastProperty;

        // Update lastProerty idx to idxToRemove
        set.indexes[lastProperty.tokenId] = idxToRemove;

        // Remove lastProperty
        set.property.pop();

        // Remove removed property from contains mapping
        set.contains[tokenId] = false;
    }
}
