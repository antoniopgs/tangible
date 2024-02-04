// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Inheritance
import { StdInvariant } from "lib/openzeppelin-contracts/lib/forge-std/src/StdInvariant.sol"; // Todo: fix foundry imports later
import { Test } from "lib/chainlink/contracts/foundry-lib/forge-std/src/Test.sol"; // Todo: fix foundry imports later

// Other
import { Handler } from "./Handler.t.sol";
import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";

contract Invariant is StdInvariant, Test {

    Handler handler;

    function setUp() external {

        // Deploy handler
        handler = new Handler();

        // Build handlerSelectors
        bytes4[] memory handlerSelectors = new bytes4[](8);
        handlerSelectors[0] = Handler.bid.selector;
        handlerSelectors[1] = Handler.cancelBid.selector;
        handlerSelectors[2] = Handler.acceptBid.selector;
        handlerSelectors[3] = Handler.payMortgage.selector;
        handlerSelectors[4] = Handler.foreclose.selector;
        handlerSelectors[5] = Handler.deposit.selector;
        handlerSelectors[6] = Handler.withdraw.selector;
        handlerSelectors[7] = Handler.skipTime.selector;

        // Target selectors
        targetSelector(
            FuzzSelector({
                addr: address(handler),
                selectors: handlerSelectors
            })
        );

        // Target handler contract
        targetContract(address(handler));
    }

    function invariant_vaultDebt() external {
        // assertEq(handler.expectedVaultDeposits(), handler.actualVaultDeposits());
    }

    function invariant_vaultDeposits() external {
        assertEq(handler.expectedVaultDeposits(), handler.actualVaultDeposits());
    }

    function statefulFuzz_utilization() external {
        assertLt(convert(handler.actualVaultUtilization()), 1 + 1);
    }
}