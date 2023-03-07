// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Property.sol";

library PropertySet {

    struct Set {
        mapping(TokenId => bool) contains;
        mapping(TokenId => Idx) indexes;
        Property[] properties;
    }

    function at(Set storage set, Idx idx) internal view returns(Property storage) {
        return set.properties[Idx.unwrap(idx)];
    }

    function get(Set storage set, TokenId tokenId) internal view returns(Property storage) {
        return at(set, set.indexes[tokenId]);
    }

    function length(Set storage set) internal view returns(uint) {
        return set.properties.length;
    }

    function addProperty(Set storage set, TokenId tokenId) internal {
        require(!set.contains[tokenId], "set already contains property");

        // Build property
        Property memory property;
        property.tokenId = tokenId;

        // Add property to properties
        set.properties.push(property);

        // Store property index
        set.indexes[tokenId] = Idx.wrap(length(set) - 1);

        // Update contains
        set.contains[tokenId] = true;
    }

    function removeProperty(Set storage set, TokenId tokenId) internal {
        require(set.contains[tokenId], "set doesn't contain property");

        // Get idxToRemove
        Idx idxToRemove = set.indexes[tokenId];

        // Get last property
        Property memory lastProperty = at(set, Idx.wrap(length(set) - 1));

        // Write lastProperty over idxToRemove
        set.properties[Idx.unwrap(idxToRemove)] = lastProperty;

        // Update lastProperty idx to idxToRemove
        set.indexes[lastProperty.tokenId] = idxToRemove;

        // Remove lastProperty
        set.properties.pop();

        // Remove removed property from contains mapping
        set.contains[tokenId] = false;
    }

    function addBid(Set storage set, TokenId tokenId, Bid memory bid) external {
        require(set.contains[tokenId], "set doesn't contain property");

        // Get property
        Property storage property = get(set, tokenId);

        // Add bid to property bids
        property.bids.push(bid);
    }

    function removeBid(Set storage set, TokenId tokenId, Idx bidIdx) external {
        require(set.contains[tokenId], "set doesn't contain property");

        // Get property
        Property storage property = get(set, tokenId);

        // Get last propertyLastBid
        Bid memory propertyLastBid = property.bids[property.bids.length - 1];

        // Write propertyLastBid over bidIdx
        property.bids[Idx.unwrap(bidIdx)] = propertyLastBid;

        // Remove lastPropertyBid
        property.bids.pop();
    }

    function updateLoan() external {

    }
}
