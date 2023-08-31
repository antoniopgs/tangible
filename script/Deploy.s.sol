// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Main Imports
import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

// ProtocolProxy
import "../contracts/protocol/protocolProxy/ProtocolProxy.sol";

// Non-Abstract Implementations
import "../contracts/protocol/auctions/Auctions.sol";
import "../contracts/protocol/borrowing/Borrowing.sol";
import "../contracts/protocol/info/Info.sol";
import "../contracts/protocol/initializer/Initializer.sol";
import "../contracts/protocol/lending/Lending.sol";
import "../contracts/protocol/residents/Residents.sol";
import "../contracts/protocol/setter/Setter.sol";

// Tokens
import "../contracts/mock/MockUsdc.sol";
import "../contracts/tokens/tUsdc.sol";
import "../contracts/tokens/tangibleNft/TangibleNft.sol";

contract DeployScript is Script {

    // ProtocolProxy
    address payable proxy;

    // Non-Abstract Implementations
    Auctions auctions;
    Borrowing borrowing;
    Info info;
    Initializer initializer;
    Lending lending;
    Residents residents;
    Setter setter;

    // Multi-Sigs
    address _TANGIBLE = address(0); // Todo: fix later
    address _GSP = address(0); // Todo: fix later
    address _PAC = address(0); // Todo: fix later

    // Tokens
    IERC20 USDC; /* = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // Note: ethereum mainnet */
    tUsdc tUSDC;
    TangibleNft nftContract;

    constructor() {

        // Fork (needed for tUSDC's ERC777 registration in the ERC1820 registry)
        vm.createSelectFork("https://mainnet.infura.io/v3/f36750d69d314e3695b7fe230bb781af");

        // Deploy protocolProxy
        proxy = payable(new ProtocolProxy());

        // Deploy Non-Abstract Implementations
        deployImplementations();

        // Deploy Tokens
        deployTokens();

        // Initialize proxy
        Initializer(proxy).initialize(address(USDC), address(tUSDC), address(nftContract), _TANGIBLE, _GSP, _PAC);

        // Set Function Selectors
        setSelectors();
    }

    function deployImplementations() private {

        // Deploy non-abstract implementations
        auctions = new Auctions();
        borrowing = new Borrowing();
        info = new Info();
        initializer = new Initializer();
        lending = new Lending();
        residents = new Residents();
        setter = new Setter();
    }

    function deployTokens() private {

        // Deploy mockUSDC
        USDC = new MockUsdc();

        // Deploy tUSDC
        address[] memory tUsdcDefaultOperators = new address[](1);
        tUsdcDefaultOperators[0] = address(proxy);
        tUSDC = new tUsdc(tUsdcDefaultOperators);

        // Deploy nftContract
        nftContract = new TangibleNft(proxy);
    }

    function setSelectors() private {

        /// Set auctionSelectors
        bytes4[] memory auctionSelectors = new bytes4[](4);
        auctionSelectors[0] = IAuctions.bid.selector;
        auctionSelectors[1] = IAuctions.loanBid.selector;
        auctionSelectors[2] = IAuctions.cancelBid.selector;
        auctionSelectors[3] = IAuctions.acceptBid.selector;
        ProtocolProxy(proxy).setSelectorsTarget(auctionSelectors, address(auctions));

        // Set borrowingSelectors
        bytes4[] memory borrowingSelectors = new bytes4[](6);
        borrowingSelectors[0] = IBorrowing.payMortgage.selector;
        borrowingSelectors[1] = IBorrowing.redeemMortgage.selector;
        borrowingSelectors[2] = IBorrowing.debtTransfer.selector;
        // borrowingSelectors[] = IBorrowing.refinance.selector;
        borrowingSelectors[3] = IBorrowing.foreclose.selector;
        borrowingSelectors[4] = IBorrowing.increaseOtherDebt.selector;
        borrowingSelectors[5] = IBorrowing.decreaseOtherDebt.selector;
        ProtocolProxy(proxy).setSelectorsTarget(borrowingSelectors, address(borrowing));

        // Set infoSelectors
        bytes4[] memory infoSelectors = new bytes4[](8);
        infoSelectors[0] = IInfo.isResident.selector;
        infoSelectors[1] = IInfo.availableLiquidity.selector;
        infoSelectors[2] = IInfo.utilization.selector;
        infoSelectors[3] = IInfo.usdcToTUsdc.selector;
        infoSelectors[4] = IInfo.tUsdcToUsdc.selector;
        // infoSelectors[] = IInfo.borrowerApr.selector;
        infoSelectors[5] = IInfo.bidActionable.selector;
        infoSelectors[6] = IInfo.unpaidPrincipal.selector;
        infoSelectors[7] = IInfo.accruedInterest.selector;
        ProtocolProxy(proxy).setSelectorsTarget(infoSelectors, address(info));

        // Set initializerSelectors
        bytes4[] memory initializerSelectors = new bytes4[](1);
        initializerSelectors[0] = Initializer.initialize.selector;
        ProtocolProxy(proxy).setSelectorsTarget(initializerSelectors, address(initializer));

        // Set lendingSelectors
        bytes4[] memory lendingSelectors = new bytes4[](2);
        lendingSelectors[0] = ILending.deposit.selector;
        lendingSelectors[1] = ILending.withdraw.selector;
        ProtocolProxy(proxy).setSelectorsTarget(lendingSelectors, address(lending));

        // Set residentSelectors
        bytes4[] memory residentSelectors = new bytes4[](1);
        residentSelectors[0] = IResidents.verifyResident.selector;
        ProtocolProxy(proxy).setSelectorsTarget(residentSelectors, address(residents));

        // Set setterSelectors
        bytes4[] memory setterSelectors = new bytes4[](11);
        setterSelectors[0] = ISetter.updateOptimalUtilization.selector;
        setterSelectors[1] = ISetter.updateMaxLtv.selector;
        setterSelectors[2] = ISetter.updateMaxLoanMonths.selector;
        setterSelectors[3] = ISetter.updateRedemptionWindow.selector;
        setterSelectors[4] = ISetter.updateM1.selector;
        setterSelectors[5] = ISetter.updateB1.selector;
        setterSelectors[6] = ISetter.updateM2.selector;
        setterSelectors[7] = ISetter.updateBaseSaleFeeSpread.selector;
        setterSelectors[8] = ISetter.updateInterestFeeSpread.selector;
        setterSelectors[9] = ISetter.updateRedemptionFeeSpread.selector;
        setterSelectors[10] = ISetter.updateDefaultFeeSpread.selector;
        ProtocolProxy(proxy).setSelectorsTarget(setterSelectors, address(setter));
    }
}
