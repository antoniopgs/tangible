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
import "../src/protocol/protocolProxy/ProtocolProxy.sol";

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
    ProtocolProxy protocol;

    // Tokens
    // TangibleNft prosperaNftContract; // Note: v2
    tUsdc tUSDC;

    // Functions
    function run() public {

        // Deploy Contracts
        // auctions = new Auctions(); // Note: v2
        // automation = new Automation(); // Note: v2
        borrowing = new Borrowing();
        foreclosures = new Foreclosures();
        interest = new Interest();
        lending = new Lending();
        protocol = new ProtocolProxy();

        // Deploy Tokens
        // prosperaNftContract = new TangibleNft(); // Note: v2
        address[] memory tUsdcDefaultOperators = new address[](1);
        tUsdcDefaultOperators[0] = address(protocol);
        console.log("tUsdcDefaultOperators[0]:", tUsdcDefaultOperators[0]);
        console.log("tUsdcDefaultOperators.length:", tUsdcDefaultOperators.length);
        tUSDC = new tUsdc(tUsdcDefaultOperators);
        console.log(4);

        // Set borrowingSigs
        bytes4[] memory borrowingSigs = new bytes4[](4);
        borrowingSigs[0] = IBorrowing.adminStartLoan.selector;
        borrowingSigs[1] = IBorrowing.acceptBidStartLoan.selector;
        borrowingSigs[2] = IBorrowing.payLoan.selector;
        borrowingSigs[3] = IBorrowing.redeemLoan.selector;
        protocol.setSelectorsTarget(borrowingSigs, address(borrowing));

        console.log(5);

        // Set foreclosureSigs
        bytes4[] memory foreclosureSigs = new bytes4[](1);
        foreclosureSigs[0] = IForeclosures.adminForeclose.selector;
        protocol.setSelectorsTarget(foreclosureSigs, address(foreclosures));

        console.log(6);

        // Set interestSigs
        bytes4[] memory interestSigs = new bytes4[](1);
        interestSigs[0] = IInterest.calculatePeriodRate.selector;
        protocol.setSelectorsTarget(interestSigs, address(interest));

        console.log(7);

        // Set lendingSigs
        bytes4[] memory lendingSigs = new bytes4[](2);
        lendingSigs[0] = ILending.deposit.selector;
        lendingSigs[1] = ILending.withdraw.selector;
        protocol.setSelectorsTarget(lendingSigs, address(lending));

        console.log(8);
    }
}
