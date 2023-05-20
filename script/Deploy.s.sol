// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Main Imports
import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

// Contract Imports
import "../contracts/protocol/auctions/Auctions.sol"; // Note: v2
import "../contracts/protocol/borrowing/automation/Automation.sol"; // Note: v2
// import "../contracts/protocol/borrowing/borrowing/Borrowing.sol";
import "../contracts/protocol/interest/Interest.sol";
import "../contracts/protocol/lending/Lending.sol";
import "../contracts/protocol/info/Info.sol";
import "../contracts/protocol/protocolProxy/ProtocolProxy.sol";

// Token Imports
import "../contracts/mock/MockUsdc.sol";
import "../contracts/tokens/tUsdc.sol";
import "../contracts/tokens/TangibleNft.sol"; // Note: v2


contract DeployScript is Script {

    // Tokens
    IERC20 USDC; /* = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // Note: ethereum mainnet */
    tUsdc tUSDC;
    TangibleNft nftContract;

    // Protocol
    address payable protocol;

    // Logic Contracts
    Auctions auctions;
    Automation automation;
    // Borrowing borrowing;
    Interest interest;
    Lending lending;
    Info info;

    // Bid acceptance contracts
    AcceptNone acceptNone;
    AcceptMortgage acceptMortgage;
    AcceptDefault acceptDefault;
    AcceptForeclosurable acceptForeclosurable;

    constructor() {

        // Fork (needed for tUSDC's ERC777 registration in the ERC1820 registry)
        vm.createSelectFork("https://mainnet.infura.io/v3/f36750d69d314e3695b7fe230bb781af");

        // Deploy protocol
        protocol = payable(new ProtocolProxy());

        // Build tUsdcDefaultOperators;
        address[] memory tUsdcDefaultOperators = new address[](1);
        tUsdcDefaultOperators[0] = address(protocol);

        // Deploy mockUSDC
        USDC = new MockUsdc();

        // Deploy tUSDC
        tUSDC = new tUsdc(tUsdcDefaultOperators);

        // Deploy nftContract
        nftContract = new TangibleNft(protocol);

        // Initialize protocol
        ProtocolProxy(protocol).initialize(USDC, tUSDC, nftContract);

        // Deploy logic contracts
        auctions = new Auctions();
        automation = new Automation();
        // borrowing = new Borrowing();
        interest = new Interest();
        lending = new Lending();
        info = new Info();

        // Deploy bid acceptance contracts
        acceptNone = new AcceptNone();
        acceptMortgage = new AcceptMortgage();
        acceptDefault = new AcceptDefault();
        acceptForeclosurable = new AcceptForeclosurable();

        // Set auctionSelectors
        bytes4[] memory auctionSelectors = new bytes4[](3);
        auctionSelectors[0] = IAuctions.bid.selector;
        auctionSelectors[1] = IAuctions.cancelBid.selector;
        auctionSelectors[2] = IAuctions.acceptBid.selector;
        ProtocolProxy(protocol).setSelectorsTarget(auctionSelectors, address(auctions));

        // Set automationSelectors
        bytes4[] memory automationSelectors = new bytes4[](8);
        automationSelectors[0] = IBorrowing.startLoan.selector;
        automationSelectors[1] = IBorrowing.payLoan.selector;
        automationSelectors[2] = IBorrowing.redeemLoan.selector;
        automationSelectors[4] = IBorrowing.utilization.selector;
        automationSelectors[5] = Status.status.selector;
        automationSelectors[7] = Automation.findHighestActionableBidIdx.selector;
        ProtocolProxy(protocol).setSelectorsTarget(automationSelectors, address(automation));

        // Set borrowingSelectors
        // bytes4[] memory borrowingSelectors = new bytes4[](5);
        // borrowingSelectors[0] = IBorrowing.startLoan.selector;
        // borrowingSelectors[1] = IBorrowing.payLoan.selector;
        // borrowingSelectors[2] = IBorrowing.redeemLoan.selector;
        // borrowingSelectors[3] = IBorrowing.forecloseLoan.selector;
        // borrowingSelectors[4] = IBorrowing.utilization.selector;
        // ProtocolProxy(protocol).setSelectorsTarget(borrowingSelectors, address(borrowing));

        // Set interestSelectors
        bytes4[] memory interestSelectors = new bytes4[](1);
        interestSelectors[0] = IInterest.borrowerRatePerSecond.selector;
        ProtocolProxy(protocol).setSelectorsTarget(interestSelectors, address(interest));

        // Set lendingSelectors
        bytes4[] memory lendingSelectors = new bytes4[](3);
        lendingSelectors[0] = ILending.deposit.selector;
        lendingSelectors[1] = ILending.withdraw.selector;
        lendingSelectors[2] = Lending.usdcToTUsdc.selector;
        ProtocolProxy(protocol).setSelectorsTarget(lendingSelectors, address(lending));

        // Set infoSelectors
        bytes4[] memory infoSelectors = new bytes4[](13);
        infoSelectors[0] = IInfo.loans.selector;
        infoSelectors[1] = IInfo.bids.selector;
        infoSelectors[2] = IInfo.availableLiquidity.selector;
        infoSelectors[3] = IInfo.myLoans.selector;
        infoSelectors[4] = IInfo.myBids.selector;
        infoSelectors[5] = IInfo.loansTokenIdsLength.selector;
        infoSelectors[6] = IInfo.loansTokenIdsAt.selector;
        infoSelectors[7] = IInfo.redemptionFeeSpread.selector;
        infoSelectors[8] = IInfo.defaultFeeSpread.selector;
        infoSelectors[9] = IInfo.accruedInterest.selector;
        infoSelectors[10] = IInfo.lenderApy.selector;
        infoSelectors[11] = IInfo.tUsdcToUsdc.selector;
        infoSelectors[12] = IInfo.bidActionable.selector;
        ProtocolProxy(protocol).setSelectorsTarget(infoSelectors, address(info));

        // ---------- BID ACCEPTANCE SELECTORS ----------

        // Set acceptNoneSelectors
        bytes4[] memory acceptNoneSelectors = new bytes4[](1);
        acceptNoneSelectors[0] = AcceptNone.acceptNoneBid.selector;
        ProtocolProxy(protocol).setSelectorsTarget(acceptNoneSelectors, address(acceptNone));
        
        // Set acceptMortageSelectors
        bytes4[] memory acceptMortageSelectors = new bytes4[](1);
        acceptMortageSelectors[0] = AcceptMortgage.acceptMortgageBid.selector;
        ProtocolProxy(protocol).setSelectorsTarget(acceptMortageSelectors, address(acceptMortgage));

        // Set acceptDefaultSelectors
        bytes4[] memory acceptDefaultSelectors = new bytes4[](1);
        acceptDefaultSelectors[0] = AcceptDefault.acceptDefaultBid.selector;
        ProtocolProxy(protocol).setSelectorsTarget(acceptDefaultSelectors, address(acceptDefault));

        // Set acceptForeclosurableSelectors
        bytes4[] memory acceptForeclosurableSelectors = new bytes4[](1);
        acceptForeclosurableSelectors[0] = AcceptForeclosurable.acceptForeclosurableBid.selector;
        ProtocolProxy(protocol).setSelectorsTarget(acceptForeclosurableSelectors, address(acceptForeclosurable));
    }
}
