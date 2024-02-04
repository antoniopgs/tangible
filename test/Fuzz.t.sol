// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Inheritance
import { Test } from "lib/chainlink/contracts/foundry-lib/forge-std/src/Test.sol"; // Todo: fix foundry imports later

// Other
import { Handler } from "./Handler.t.sol";

contract Fuzz is Test {

    enum HandlerFunctions {
        Bid, CancelBid, AcceptBid,
        PayMortgage, Foreclose,
        Deposit, Withdraw,
        SkipTime
    }

    Handler handler;

    constructor() {
        handler = new Handler();
    }

    function test(uint[] calldata randomness) external {
        
        // Loop randomness
        for (uint i = 0; i < randomness.length; i++) {

            // Get functionToCall
            uint functionToCall = randomness[i] % (uint(type(HandlerFunctions).max) + 1);

            if (functionToCall == uint(HandlerFunctions.Bid)) {
                handler.bid(randomness[i]);

            } else if (functionToCall == uint(HandlerFunctions.CancelBid)) {
                handler.cancelBid(randomness[i]);

            } else if (functionToCall == uint(HandlerFunctions.AcceptBid)) {
                handler.acceptBid(randomness[i]);

            } else if (functionToCall == uint(HandlerFunctions.PayMortgage)) {
                handler.payMortgage(randomness[i]);

            } else if (functionToCall == uint(HandlerFunctions.Foreclose)) {
                handler.foreclose(randomness[i]);

            } else if (functionToCall == uint(HandlerFunctions.Deposit)) {
                handler.deposit(randomness[i]);

            }else if (functionToCall == uint(HandlerFunctions.Withdraw)) {
                handler.withdraw(randomness[i]);

            } else if (functionToCall == uint(HandlerFunctions.SkipTime)) {
                handler.skipTime(randomness[i]);
            }
        }
    }
}