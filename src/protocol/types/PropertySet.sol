// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Property.sol";

library PropertySet {

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

    function append(Set storage set, tokenId _tokenId, Property memory property) internal {
        require(!set.contains[_tokenId], "set already contains property");

        // Push property into properties
        set.properties.push(property);

        // Store property idx
        set.indexes[_tokenId] = idx.wrap(length(set) - 1);

        // Update contains
        set.contains[_tokenId] = true;
    }

    function remove(Set storage set, tokenId _tokenId) internal {
        require(set.contains[_tokenId], "set doesn't contain property");

        // Get index of property to remove
        idx idxToRemove = set.indexes[_tokenId];

        // Get last property
        Property memory lastProperty = set.properties[length(set) - 1];

        // Write lastProperty over idxToRemove
        set.properties[idx.unwrap(idxToRemove)] = lastProperty;

        // Update lastProperty idx to idxToRemove
        set.indexes[lastProperty.tokenId] = idxToRemove;

        // Remove lastProperty
        set.properties.pop();

        // Remove removed property from contains mapping
        set.contains[_tokenId] = false;
    }
}
