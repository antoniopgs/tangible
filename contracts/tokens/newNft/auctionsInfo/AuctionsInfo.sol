// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/State.sol";
import { Bid } from "../../../types/Types.sol";
import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";

abstract contract AuctionsInfo is State {

    function _bidActionable(Bid memory _bid) internal view returns(bool) {
        return _bid.downPayment == _bid.propertyValue || loanBidActionable(_bid);
    }

    function loanBidActionable(Bid memory _bid) private view returns(bool) {

        // Calculate loanBid principal
        uint principal = _bid.propertyValue - _bid.downPayment;

        // Calculate loanBid ltv
        UD60x18 ltv = convert(principal).div(convert(_bid.propertyValue));

        // Return actionability
        return ltv.lte(maxLtv) && principal <= _availableLiquidity(); // Note: LTV already validated in bid(), but re-validate it here (because admin may have updated it)
    }

    function _availableLiquidity() internal view returns(uint) {
        return totalDeposits - totalPrincipal; // - protocolMoney?
    }
}