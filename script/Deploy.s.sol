// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Main Imports
import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

// Contract Imports
import "../src/protocol/auctions/Auctions.sol"; // Note: v2
import "../src/protocol/automation/Automation.sol"; // Note: v2
import "../src/protocol/borrowing/Borrowing.sol";
import "../src/protocol/foreclosures/Foreclosures.sol";
import "../src/protocol/interest/Interest.sol";
import "../src/protocol/lending/Lending.sol";
import "../src/protocol/protocolProxy/ProtocolProxy.sol";

// Token Imports
import "../src/tokens/TangibleNft.sol"; // Note: v2
import "../src/tokens/tUsdc.sol";


contract DeployScript is Script {

    // Tokens
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // Note: ethereum mainnet
    tUsdc tUSDC;
    TangibleNft nftContract;

    // Protocol
    address payable protocol;

    constructor() {

        // Fork (needed for tUSDC's ERC777 registration in the ERC1820 registry)
        vm.createSelectFork("https://mainnet.infura.io/v3/f36750d69d314e3695b7fe230bb781af");

        // Deploy protocol
        protocol = payable(new ProtocolProxy());

        // Build tUsdcDefaultOperators;
        address[] memory tUsdcDefaultOperators = new address[](1);
        tUsdcDefaultOperators[0] = address(protocol);

        // Deploy tUSDC
        tUSDC = new tUsdc(tUsdcDefaultOperators);

        // Initialize protocol
        ProtocolProxy(protocol).initialize(tUSDC);

        // Deploy nftContract
        nftContract = new TangibleNft();

        // Deploy logic contracts
        Auctions auctions = new Auctions();
        // Automation automation = new Automation();
        Borrowing borrowing = new Borrowing();
        Foreclosures foreclosures = new Foreclosures();
        Interest interest = new Interest();
        Lending lending = new Lending();

        // Set auctionSelectors
        bytes4[] memory auctionSelectors = new bytes4[](3);
        auctionSelectors[0] = IAuctions.bid.selector;
        auctionSelectors[1] = IAuctions.cancelBid.selector;
        auctionSelectors[2] = IAuctions.acceptBid.selector;
        ProtocolProxy(protocol).setSelectorsTarget(auctionSelectors, address(auctions));

        // Set automationSelectors

        // Set borrowingSelectors
        bytes4[] memory borrowingSelectors = new bytes4[](15);
        borrowingSelectors[0] = IBorrowing.startLoan.selector;
        borrowingSelectors[1] = IBorrowing.payLoan.selector;
        borrowingSelectors[2] = IBorrowing.redeem.selector;
        borrowingSelectors[3] = IBorrowing.foreclose.selector;
        borrowingSelectors[4] = IBorrowing.borrowerApr.selector;
        borrowingSelectors[5] = IBorrowing.lenderApy.selector;
        borrowingSelectors[6] = IBorrowing.principalCap.selector;
        borrowingSelectors[7] = IBorrowing.status.selector;
        borrowingSelectors[8] = IBorrowing.utilization.selector;
        borrowingSelectors[9] = IBorrowing.availableLiquidity.selector;
        borrowingSelectors[10] = Borrowing.calculatePaymentPerSecond.selector;
        borrowingSelectors[11] = State.loans.selector;
        borrowingSelectors[12] = Borrowing.accruedInterest.selector;
        borrowingSelectors[13] = State.redemptionFeeSpread.selector;
        borrowingSelectors[14] = State.foreclosureFeeSpread.selector;
        ProtocolProxy(protocol).setSelectorsTarget(borrowingSelectors, address(borrowing));

        // Set foreclosureSelectors
        bytes4[] memory foreclosureSelectors = new bytes4[](1);
        borrowingSelectors[0] = IForeclosures.foreclose.selector;
        ProtocolProxy(protocol).setSelectorsTarget(foreclosureSelectors, address(foreclosures));

        // Set interestSelectors
        bytes4[] memory interestSelectors = new bytes4[](1);
        interestSelectors[0] = IInterest.foreclose.selector;
        ProtocolProxy(protocol).setSelectorsTarget(foreclosureSelectors, address(interest));

        // Set lendingSelectors
        bytes4[] memory lendingSelectors = new bytes4[](3);
        lendingSelectors[0] = ILending.deposit.selector;
        lendingSelectors[1] = ILending.withdraw.selector;
        lendingSelectors[2] = Lending.usdcToTUsdc.selector;
        ProtocolProxy(protocol).setSelectorsTarget(lendingSelectors, address(lending));
    }
}
