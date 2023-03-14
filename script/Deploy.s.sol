// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// ----- MAIN IMPORTS -----
import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

// ----- CONTRACT IMPORTS -----
// import "../src/protocol/auctions/Auctions.sol"; // Note: v2
// import "../src/protocol/automation/Automation.sol"; // Note: v2
import "../src/protocol/borrowing/Borrowing.sol";
import "../src/protocol/foreclosures/Foreclosures.sol";
import "../src/protocol/interest/Interest.sol";
import "../src/protocol/lending/Lending.sol";
import "../src/protocol/protocol/Protocol.sol";

// ----- TOKEN IMPORTS -----
// import "../src/tokens/TangibleNft.sol"; // Note: v2
import "../src/tokens/tUsdc.sol";


contract DeployScript is Script {

    // ----- CONTRACTS -----
    // Auctions auctions; // Note: v2
    // Automation automation; // Note: v2
    Borrowing borrowing;
    Foreclosures foreclosures;
    Interest interest;
    Lending lending;
    Protocol protocol;

    // ----- TOKENS -----
    // TangibleNft prosperaNftContract; // Note: v2
    tUsdc tUSDC;

    // ----- FUNCTIONS -----
    function run() external {

        // Deploy Contracts
        // auctions = new Auctions(); // Note: v2
        // automation = new Automation(); // Note: v2
        borrowing = new Borrowing();
        foreclosures = new Foreclosures();
        interest = new Interest();
        lending = new Lending();
        protocol = new Protocol();

        // Deploy Tokens
        // prosperaNftContract = new TangibleNft(); // Note: v2
        address[] memory tUsdcDefaultOperators;
        tUSDC = new tUsdc(tUsdcDefaultOperators);
    }
}
