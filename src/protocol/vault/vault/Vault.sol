// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IVault.sol";
import "../../../config/config/ConfigUser.sol";
import "../../../types/PropertySet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Vault is IVault, ConfigUser {

    // Links
    IERC20 USDC;

    // State
    PropertySet.Set internal properties;

    // Libs
    using PropertySet for PropertySet.Set;
    using SafeERC20 for IERC20;

    function addProperty(TokenId tokenId) external onlyConfigRole(PROPERTY_MANAGER) {
        properties.addProperty(tokenId);
    }

    function removeProperty(TokenId tokenId) external onlyConfigRole(PROPERTY_MANAGER) {
        properties.removeProperty(tokenId);
    }

    function addBid(TokenId tokenId, Bid memory bid) external onlyConfigRole(BID_MANAGER) {

        // Pull downPayment from bidder
        USDC.safeTransferFrom(bid.bidder, address(this), bid.downPayment);

        // Add bid
        properties.addBid(tokenId, bid);
    }

    function removeBid(TokenId tokenId, Idx bidIdx) external onlyConfigRole(BID_MANAGER) {

        // Remove bid
        properties.removeBid(tokenId, bidIdx);

        // Return downPayment to bidder
        // USDC.safeTransferFrom(bid.bidder, address(this), bid.downPayment);
    }

    function updateLoan() external onlyConfigRole(LOAN_MANAGER) {
        
    }

    function propertiesLength() external view returns(uint) {
        return properties.length();
    }

    function propertyAt(Idx _idx) external view returns(Property memory property) {
        return properties.at(_idx);
    }
}
