// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";
import { Loan } from "../../types/Types.sol";
import "../state/state/State.sol";

abstract contract BorrowingInfo is State {

    function _utilization() internal view returns(UD60x18) {
        if (_totalDeposits == 0) {
            assert(_totalPrincipal == 0);
            return convert(uint(0));
        }
        return convert(_totalPrincipal).div(convert(_totalDeposits));
    }
}