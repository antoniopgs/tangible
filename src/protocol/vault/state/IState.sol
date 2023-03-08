// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../types/Property.sol";
import "../vault/IVault.sol";

interface IState is IVault {

    enum PropertyState { None, Mortgage, Default } // Note: maybe switch to: enum NftOwner { Seller, Borrower, Protocol }

    function state(Loan calldata loan) external view returns (PropertyState);
}
