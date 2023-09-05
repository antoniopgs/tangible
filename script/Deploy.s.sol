// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

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

// Other Imports
import "forge-std/Script.sol";
import "../contracts/protocol/state/targetManager/ITargetManager.sol";

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
    address _TANGIBLE = vm.addr(1); // Todo: fix later
    address _GSP = vm.addr(2); // Todo: fix later
    address _PAC = vm.addr(3); // Todo: fix later

    // Tokens
    IERC20 USDC; /* = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // Note: ethereum mainnet */
    tUsdc tUSDC; // Todo: proxy later
    TangibleNft nftContract; // Todo: proxy later

    constructor() {

        // Fork (needed for tUSDC's ERC777 registration in the ERC1820 registry)
        vm.createSelectFork("https://mainnet.infura.io/v3/f36750d69d314e3695b7fe230bb781af");

        // Deploy protocolProxy
        proxy = payable(new ProtocolProxy());

        // Deploy Non-Abstract Implementations
        deployImplementations();

        // Deploy Tokens
        deployTokens();

        // Set Function Selectors
        setSelectors();

        // Initialize proxy
        Initializer(proxy).initialize(address(USDC), address(tUSDC), address(nftContract), _TANGIBLE, _GSP, _PAC);
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
        bytes4[] memory auctionSelectors = new bytes4[](3);
        auctionSelectors[0] = IAuctions.bid.selector;
        auctionSelectors[1] = IAuctions.cancelBid.selector;
        auctionSelectors[2] = IAuctions.acceptBid.selector;
        ITargetManager(proxy).setSelectorsTarget(auctionSelectors, address(auctions));

        // Set borrowingSelectors
        bytes4[] memory borrowingSelectors = new bytes4[](6);
        borrowingSelectors[0] = IBorrowing.payMortgage.selector;
        borrowingSelectors[1] = IBorrowing.redeemMortgage.selector;
        borrowingSelectors[2] = IBorrowing.debtTransfer.selector;
        // borrowingSelectors[] = IBorrowing.refinance.selector;
        borrowingSelectors[3] = IBorrowing.foreclose.selector;
        borrowingSelectors[4] = IBorrowing.increaseOtherDebt.selector;
        borrowingSelectors[5] = IBorrowing.decreaseOtherDebt.selector;
        ITargetManager(proxy).setSelectorsTarget(borrowingSelectors, address(borrowing));

        // Set infoSelectors
        bytes4[] memory infoSelectors = new bytes4[](19);
        infoSelectors[0] = IInfo.isResident.selector;
        infoSelectors[1] = IInfo.addressToResident.selector;
        infoSelectors[2] = IInfo.residentToAddress.selector;
        infoSelectors[3] = IInfo.availableLiquidity.selector;
        infoSelectors[4] = IInfo.utilization.selector;
        infoSelectors[5] = IInfo.usdcToTUsdc.selector;
        infoSelectors[6] = IInfo.tUsdcToUsdc.selector;
        infoSelectors[7] = IInfo.borrowerApr.selector;
        infoSelectors[8] = IInfo.bids.selector;
        infoSelectors[9] = IInfo.bidsLength.selector;
        infoSelectors[10] = IInfo.bidActionable.selector;
        infoSelectors[11] = IInfo.userBids.selector;
        infoSelectors[12] = IInfo.minSalePrice.selector;
        infoSelectors[13] = IInfo.unpaidPrincipal.selector;
        infoSelectors[14] = IInfo.accruedInterest.selector;
        infoSelectors[15] = IInfo.status.selector;
        infoSelectors[16] = IInfo.redeemable.selector;
        infoSelectors[17] = IInfo.loanChart.selector;
        infoSelectors[18] = IInfo.maxLtv.selector;
        ITargetManager(proxy).setSelectorsTarget(infoSelectors, address(info));

        // Set initializerSelectors
        bytes4[] memory initializerSelectors = new bytes4[](1);
        initializerSelectors[0] = Initializer.initialize.selector;
        ITargetManager(proxy).setSelectorsTarget(initializerSelectors, address(initializer));

        // Set lendingSelectors
        bytes4[] memory lendingSelectors = new bytes4[](2);
        lendingSelectors[0] = ILending.deposit.selector;
        lendingSelectors[1] = ILending.withdraw.selector;
        ITargetManager(proxy).setSelectorsTarget(lendingSelectors, address(lending));

        // Set residentSelectors
        bytes4[] memory residentSelectors = new bytes4[](1);
        residentSelectors[0] = IResidents.verifyResident.selector;
        ITargetManager(proxy).setSelectorsTarget(residentSelectors, address(residents));

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
        ITargetManager(proxy).setSelectorsTarget(setterSelectors, address(setter));
    }
}
