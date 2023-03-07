// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../types/Property.sol";

interface IState {

    enum PropertyState { None, Mortgage, Default } // Note: maybe switch to: enum NftOwner { Seller, Borrower, Protocol }

    function state(TokenId _tokenId) external view returns (PropertyState);
}
