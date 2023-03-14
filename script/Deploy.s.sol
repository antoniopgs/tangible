// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Main Imports
import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

// Contract Imports
// import "../src/protocol/auctions/Auctions.sol"; // Note: v2
// import "../src/protocol/automation/Automation.sol"; // Note: v2
import "../src/protocol/borrowing/Borrowing.sol";
import "../src/protocol/foreclosures/Foreclosures.sol";
import "../src/protocol/interest/Interest.sol";
import "../src/protocol/lending/Lending.sol";
import "../src/protocol/protocol/Protocol.sol";

// Token Imports
// import "../src/tokens/TangibleNft.sol"; // Note: v2
import "../src/tokens/tUsdc.sol";


contract DeployScript is Script {

    // Contracts
    // Auctions auctions; // Note: v2
    // Automation automation; // Note: v2
    Borrowing borrowing;
    Foreclosures foreclosures;
    Interest interest;
    Lending lending;
    Protocol protocol;

    // Tokens
    // TangibleNft prosperaNftContract; // Note: v2
    tUsdc tUSDC;

    // Functions
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

        // Set borrowingSigs
        bytes4[] memory borrowingSigs;
        borrowingSigs[0] = IBorrowing.adminStartLoan.selector;
        borrowingSigs[1] = IBorrowing.acceptBidStartLoan.selector;
        borrowingSigs[2] = IBorrowing.payLoan.selector;
        borrowingSigs[3] = IBorrowing.redeemLoan.selector;
        protocol.setSigsTarget(borrowingSigs, address(borrowing));

        // Set foreclosureSigs
        bytes4[] memory foreclosureSigs;
        foreclosureSigs[0] = IForeclosures.adminForeclose.selector;
        protocol.setSigsTarget(foreclosureSigs, address(foreclosures));

        // Set interestSigs
        bytes4[] memory interestSigs;
        interestSigs[0] = IInterest.calculatePeriodRate.selector;
        protocol.setSigsTarget(interestSigs, address(interest));

        // Set lendingSigs
        bytes4[] memory lendingSigs;
        lendingSigs[0] = ILending.deposit.selector;
        lendingSigs[1] = ILending.withdraw.selector;
        protocol.setSigsTarget(lendingSigs, address(lending));
    }
}
