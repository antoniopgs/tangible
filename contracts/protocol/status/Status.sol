// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../state/State.sol";
import { SD59x18, convert } from "@prb/math/src/SD59x18.sol";
import { convert } from "@prb/math/src/UD60x18.sol";
import { intoUD60x18 } from "@prb/math/src/sd59x18/Casting.sol";
import { intoSD59x18 } from "@prb/math/src/ud60x18/Casting.sol";

abstract contract Status is PrevState {
     
}
