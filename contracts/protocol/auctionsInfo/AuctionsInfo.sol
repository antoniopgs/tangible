// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../loanStatus/LoanStatus.sol";
import { Status, Loan, Bid } from "../../types/Types.sol";
import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";

abstract contract AuctionsInfo is LoanStatus {

    function _bidActionable(Loan memory loan, Bid memory _bid) internal view returns(bool) {

        // Calculate bid principal
        uint principal = _bid.propertyValue - _bid.downPayment;

        // Calculate bid ltv
        UD60x18 ltv = convert(principal).div(convert(_bid.propertyValue));

        // Return actionability
        return (
            principal <= _availableLiquidity() &&
            ltv.lte(maxLtv) && // Note: LTV already validated in bid(), but re-validate it here (because admin may have updated it)
            _bid.propertyValue >= minSalePrice(loan)
        );
    }

    function _availableLiquidity() internal view returns(uint) {
        return totalDeposits - totalPrincipal; // - protocolMoney?
    }

    function minSalePrice(Loan memory loan) private view returns(uint) {
        UD60x18 saleFeeSpread = status(loan) == Status.Default ? _baseSaleFeeSpread.add(_defaultFeeSpread) : _baseSaleFeeSpread; // Question: maybe defaultFee should be a boost appplied to interest instead?
        return convert(convert(loan.unpaidPrincipal + _accruedInterest(loan)).div(convert(uint(1)).sub(saleFeeSpread)));
    }
}