// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IVault.sol";
import "../propertyState/PropertyState.sol";
import "../../../config/config/ConfigUser.sol";
import "../../../types/PropertySet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Vault is IVault, PropertyState, ConfigUser {

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

    function updateLoan() external onlyConfigRole(LOAN_MANAGER) {
        
    }

    function loanAt(Idx _idx) external view returns(Loan memory) {
        return properties.at(_idx).loan;
    }

    function getBid(TokenId tokenId, Idx bidIdx) external view returns(Bid memory) {
        return properties.get(tokenId).bids[Idx.unwrap(bidIdx)];
    }
}
