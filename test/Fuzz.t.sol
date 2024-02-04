// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Inheritance
import { Test } from "lib/chainlink/contracts/foundry-lib/forge-std/src/Test.sol"; // Todo: fix foundry imports later

// Other
import { Handler } from "./Handler.t.sol";
import { console } from "forge-std/console.sol";
import { PRBMath_MulDiv18_Overflow } from "lib/prb-math/src/Common.sol";

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
                try handler.bid(randomness[i]) {
                    // suceeded (continue)
                } catch PRBMath_MulDiv18_Overflow(uint x, uint y) {
                    console.log("PRBMath_MulDiv18_Overflow");
                }

            } else if (functionToCall == uint(HandlerFunctions.CancelBid)) {
                console.log("\nCancelBid");
                try handler.cancelBid(randomness[i]) {
                    // suceeded (continue)
                } catch PRBMath_MulDiv18_Overflow(uint x, uint y) {
                    console.log("PRBMath_MulDiv18_Overflow");
                }

            } else if (functionToCall == uint(HandlerFunctions.AcceptBid)) {
                console.log("\nAcceptBid");
                try handler.acceptBid(randomness[i]) {
                    // suceeded (continue)
                } catch PRBMath_MulDiv18_Overflow(uint x, uint y) {
                    console.log("PRBMath_MulDiv18_Overflow");
                }

            } else if (functionToCall == uint(HandlerFunctions.PayMortgage)) {
                console.log("\nPayMortgage");
                try handler.payMortgage(randomness[i]) {
                    // suceeded (continue)
                } catch PRBMath_MulDiv18_Overflow(uint x, uint y) {
                    console.log("PRBMath_MulDiv18_Overflow");
                }

            } else if (functionToCall == uint(HandlerFunctions.Foreclose)) {
                console.log("\nForeclose");
                try handler.foreclose(randomness[i]) {
                    // suceeded (continue)
                } catch PRBMath_MulDiv18_Overflow(uint x, uint y) {
                    console.log("PRBMath_MulDiv18_Overflow");
                }

            } else if (functionToCall == uint(HandlerFunctions.Deposit)) {
                console.log("\nDeposit");
                try handler.deposit(randomness[i]) {
                    // suceeded (continue)
                } catch PRBMath_MulDiv18_Overflow(uint x, uint y) {
                    console.log("PRBMath_MulDiv18_Overflow");
                }

            }else if (functionToCall == uint(HandlerFunctions.Withdraw)) {
                console.log("\nWithdraw");
                try handler.withdraw(randomness[i]) {
                    // suceeded (continue)
                } catch PRBMath_MulDiv18_Overflow(uint x, uint y) {
                    console.log("PRBMath_MulDiv18_Overflow");
                }

            } else if (functionToCall == uint(HandlerFunctions.SkipTime)) {
                console.log("\nSkipTime");
                try handler.skipTime(randomness[i]) {
                    // suceeded (continue)
                } catch PRBMath_MulDiv18_Overflow(uint x, uint y) {
                    console.log("PRBMath_MulDiv18_Overflow");
                }
            }
        }
    }
}