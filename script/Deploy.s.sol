// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Proxy
import "../contracts/protocol/proxy/ProtocolProxy.sol";

// Logic
import "../contracts/protocol/logic/Auctions.sol";
import "../contracts/protocol/logic/Borrowing.sol";
import "../contracts/protocol/logic/Info.sol";
import "../contracts/protocol/logic/Initializer.sol";
import "../contracts/protocol/logic/Lending.sol";
import "../contracts/protocol/logic/Residents.sol";
import "../contracts/protocol/logic/Setter.sol";

// Interest
import "../contracts/protocol/logic/interest/InterestCurve.sol";

// Tokens
import "../contracts/mock/MockUsdc.sol";
import "../contracts/tokens/tUsdc.sol";
import "../contracts/tokens/TangibleNft.sol";

// Other
import "forge-std/Script.sol";
import "../interfaces/state/ITargetManager.sol";

contract DeployScript is Script {

    // Proxy
    address payable proxy;

    // Logic
    Auctions auctions;
    Borrowing borrowing;
    Info info;
    Initializer initializer;
    Lending lending;
    Residents residents;
    Setter setter;

    // Chosen Interest Rate Module
    InterestCurve interest;

    // Multi-Sigs
    address _TANGIBLE = vm.addr(1); // Todo: fix later
    address _GSP = vm.addr(2); // Todo: fix later
    address _PAC = vm.addr(3); // Todo: fix later

    // Tokens
    IERC20 USDC; /* = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // Note: ethereum mainnet */
    tUsdc tUSDC; // Todo: proxy later
    TangibleNft nftContract; // Todo: proxy later

    constructor() {

        // Fork (needed for tUSDC's ERC777 registration in the ERC1820 registry) // Note: no longer using ERC777 (replaced it with ERC20)
        // vm.createSelectFork("https://mainnet.infura.io/v3/9a2aca5b5e794f5c929bca9e494fae24"); // Note: Commented for speed

        // Deploy protocolProxy
        proxy = payable(new ProtocolProxy());

        // Deploy Non-Abstract Implementations
        deployImplementations();

        // Deploy chosen interest module
        UD60x18 baseYearlyRate = convert(uint(4)).div(convert(uint(100)));
        UD60x18 optimalUtilization = convert(uint(90)).div(convert(uint(100)));
        interest = new InterestCurve(baseYearlyRate, optimalUtilization);

        // Deploy Tokens
        deployTokens(proxy);

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

    function deployTokens(address _proxy) private {

        // Deploy mockUSDC
        USDC = new MockUsdc();

        // Deploy tUSDC
        tUSDC = new tUsdc(_proxy);

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
        bytes4[] memory borrowingSelectors = new bytes4[](8);
        borrowingSelectors[0] = IBorrowing.payMortgage.selector;
        borrowingSelectors[1] = IBorrowing.redeemMortgage.selector;
        borrowingSelectors[2] = IBorrowing.debtTransfer.selector;
        // borrowingSelectors[] = IBorrowing.refinance.selector;
        borrowingSelectors[3] = IBorrowing.foreclose.selector;
        borrowingSelectors[4] = IBorrowing.increaseOtherDebt.selector;
        borrowingSelectors[5] = IBorrowing.decreaseOtherDebt.selector;
        borrowingSelectors[6] = IBorrowing.borrowerApr.selector;
        borrowingSelectors[7] = IBorrowing.utilization.selector;
        ITargetManager(proxy).setSelectorsTarget(borrowingSelectors, address(borrowing));

        // Set infoSelectors
        bytes4[] memory infoSelectors = new bytes4[](17);
        infoSelectors[0] = IInfo.isResident.selector;
        infoSelectors[1] = IInfo.addressToResident.selector;
        infoSelectors[2] = IInfo.residentToAddress.selector;
        infoSelectors[3] = IInfo.availableLiquidity.selector;
        infoSelectors[4] = IInfo.tUsdcToUsdc.selector;
        infoSelectors[5] = IInfo.bids.selector;
        infoSelectors[6] = IInfo.bidsLength.selector;
        infoSelectors[7] = IInfo.bidActionable.selector;
        infoSelectors[8] = IInfo.userBids.selector;
        infoSelectors[9] = IInfo.minSalePrice.selector;
        infoSelectors[10] = IInfo.unpaidPrincipal.selector;
        infoSelectors[11] = IInfo.accruedInterest.selector;
        infoSelectors[12] = IInfo.status.selector;
        infoSelectors[13] = IInfo.redeemable.selector;
        infoSelectors[14] = IInfo.loanChart.selector;
        infoSelectors[15] = IInfo.maxLtv.selector;
        infoSelectors[16] = IInfo.isNotAmerican.selector;
        ITargetManager(proxy).setSelectorsTarget(infoSelectors, address(info));

        // Set initializerSelectors
        bytes4[] memory initializerSelectors = new bytes4[](1);
        initializerSelectors[0] = Initializer.initialize.selector;
        ITargetManager(proxy).setSelectorsTarget(initializerSelectors, address(initializer));

        // Set lendingSelectors
        bytes4[] memory lendingSelectors = new bytes4[](3);
        lendingSelectors[0] = ILending.deposit.selector;
        lendingSelectors[1] = ILending.withdraw.selector;
        lendingSelectors[2] = ILending.usdcToTUsdc.selector;
        ITargetManager(proxy).setSelectorsTarget(lendingSelectors, address(lending));

        // Set residentSelectors
        bytes4[] memory residentSelectors = new bytes4[](1);
        residentSelectors[0] = IResidents.verifyResident.selector;
        ITargetManager(proxy).setSelectorsTarget(residentSelectors, address(residents));

        // Set setterSelectors
        bytes4[] memory setterSelectors = new bytes4[](9);
        setterSelectors[0] = ISetter.updateOptimalUtilization.selector;
        setterSelectors[1] = ISetter.updateMaxLtv.selector;
        setterSelectors[2] = ISetter.updateMaxLoanMonths.selector;
        setterSelectors[3] = ISetter.updateRedemptionWindow.selector;
        setterSelectors[4] = ISetter.updateBaseSaleFeeSpread.selector;
        setterSelectors[5] = ISetter.updateInterestFeeSpread.selector;
        setterSelectors[6] = ISetter.updateRedemptionFeeSpread.selector;
        setterSelectors[7] = ISetter.updateDefaultFeeSpread.selector;
        setterSelectors[8] = ISetter.updateNotAmerican.selector;
        ITargetManager(proxy).setSelectorsTarget(setterSelectors, address(setter));

        // Set interestSelectors
        bytes4[] memory interestSelectors = new bytes4[](1);
        interestSelectors[0] = IInterest.calculateNewRatePerSecond.selector;
        ITargetManager(proxy).setSelectorsTarget(interestSelectors, address(interest));
    }
}
