// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../types/Property.sol";
import "../propertyState/IPropertyState.sol";

interface IVault is IPropertyState {
    function addProperty(TokenId tokenId) external;
    function removeProperty(TokenId tokenId) external;
    function updateLoan() external;
    function propertiesLength() external view returns(uint);
    function loanAt(Idx _idx) external view returns(Loan memory);
    function getBid(TokenId tokenId, Idx bidIdx) external view returns(Bid memory);
}
