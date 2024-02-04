// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Inheritance
import { Test } from "lib/chainlink/contracts/foundry-lib/forge-std/src/Test.sol"; // Todo: fix foundry imports later

// Other
import { Handler } from "./Handler.t.sol";
import { console } from "forge-std/console.sol";

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
        
        // Mint 100 NFTs
        handler.mintNfts(100);
        
        // Loop randomness
        for (uint i = 0; i < randomness.length; i++) {

            // Get functionToCall
            uint functionToCall = randomness[i] % (uint(type(HandlerFunctions).max) + 1);

            if (functionToCall == uint(HandlerFunctions.Bid)) {
                console.log("\nBid");
                handler.bid(randomness[i]);

            } else if (functionToCall == uint(HandlerFunctions.CancelBid)) {
                console.log("\nCancelBid");
                handler.cancelBid(randomness[i]);

            } else if (functionToCall == uint(HandlerFunctions.AcceptBid)) {
                console.log("\nAcceptBid");
                handler.acceptBid(randomness[i]);

            } else if (functionToCall == uint(HandlerFunctions.PayMortgage)) {
                console.log("\nPayMortgage");
                handler.payMortgage(randomness[i]);

            } else if (functionToCall == uint(HandlerFunctions.Foreclose)) {
                console.log("\nForeclose");
                // handler.foreclose(randomness[i]);

            } else if (functionToCall == uint(HandlerFunctions.Deposit)) {
                console.log("\nDeposit");
                handler.deposit(randomness[i]);

            }else if (functionToCall == uint(HandlerFunctions.Withdraw)) {
                console.log("\nWithdraw");
                handler.withdraw(randomness[i]);

            } else if (functionToCall == uint(HandlerFunctions.SkipTime)) {
                console.log("\nSkipTime");
                handler.skipTime(randomness[i]);
            }
        }
    }
}