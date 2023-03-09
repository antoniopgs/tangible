// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Property.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library PropertySet {
    
    // Structs
    struct Set {
        mapping(TokenId => bool) contains;
        mapping(TokenId => Idx) indexes;
        Property[] properties;
    }

    // Constants
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // Libs
    using SafeERC20 for IERC20;

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

    function addBid(Set storage set, address caller, TokenId tokenId, Bid memory bid) external {
        require(set.contains[tokenId], "set doesn't contain property");

        // Pull downPayment from caller/bidder to protocol
        USDC.safeTransferFrom(caller, address(this), bid.downPayment);

        // Get property
        Property storage property = get(set, tokenId);

        // Add bid to property bids
        property.bids.push(bid);
    }

    function removeBid(Set storage set, address caller, TokenId tokenId, Idx bidIdx) external {
        require(set.contains[tokenId], "set doesn't contain property");

        // Get propertyBids
        Bid[] storage propertyBids = get(set, tokenId).bids;

        // Get bidToRemove
        Bid memory bidToRemove = propertyBids[Idx.unwrap(bidIdx)];

        // Ensure caller is bidder
        require(caller == bidToRemove.bidder, "only bidder can remove his bid");

        // Get last propertyLastBid
        Bid memory propertyLastBid = propertyBids[propertyBids.length - 1];

        // Write propertyLastBid over bidToRemove
        propertyBids[Idx.unwrap(bidIdx)] = propertyLastBid;

        // Remove lastPropertyBid
        propertyBids.pop();

        // Send bidToRemove's downPayment from protocol to bidder
        USDC.safeTransferFrom(address(this), bidToRemove.bidder, bidToRemove.downPayment);
    }

    function updateLoan() external {

    }
}
