// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";
import "../state/IState.sol"; // Todo: move types? or maybe move interfaces inside of contracts?

interface IInfo is IState { // Todo: fix later

    // Residents
    function isResident(address addr) external view returns (bool);
    function addressToResident(address addr) external view returns(uint);
    function residentToAddress(uint id) external view returns(address);

    // Auctions
    // function bids(uint tokenId) external view returns(Bid[] memory); // Todo: implement later
    function bids(uint tokenId, uint idx) external view returns(Bid memory);
    function bidsLength(uint tokenId) external view returns(uint);
    function bidActionable(uint tokenId, uint idx) external view returns(bool);

    // Loans
    function unpaidPrincipal(uint tokenId) external view returns(uint);
    function accruedInterest(uint tokenId) external view returns(uint);
    function status(uint tokenId) external view returns(Status);

    // Loan Terms
    function maxLtv() external view returns(UD60x18);
    function maxLoanMonths() external view returns(uint);
}