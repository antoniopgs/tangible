// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Proxy
import "../contracts/protocol/proxy/ProtocolProxy.sol";

// Logic
import "../contracts/protocol/logic/Auctions.sol";
import "../contracts/protocol/logic/Borrowing.sol";
import "../contracts/protocol/logic/Info.sol";
import "../contracts/protocol/logic/Initializer.sol";
import "../contracts/protocol/logic/Residents.sol";
import "../contracts/protocol/logic/Setter.sol";

// Interest
import "../contracts/protocol/logic/interest/InterestCurve.sol";

// Tokens
import "../contracts/tokens/PropertyNft.sol";

// Other
import { Script } from "lib/chainlink/contracts/foundry-lib/forge-std/src/Script.sol"; // Todo: fix forge imports later
import "../interfaces/state/ITargetManager.sol";
import "../test/mock/MockERC20.sol";
import { console } from "forge-std/console.sol";

contract DeployScript is Script {

    // Addresses
    address constant USDC_ETHEREUM_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Proxy
    address proxy;

    // Logic
    Auctions auctions;
    Borrowing borrowing;
    Info info;
    Initializer initializer;
    Residents residents;
    Setter setter;

    // Chosen Interest Rate Module
    InterestCurve interest;

    // Tokens
    IERC20Metadata UNDERLYING;
    PropertyNft PROPERTY;

    Vault public vault;

    constructor() {

        // Fork
        // vm.createSelectFork("https://mainnet.infura.io/v3/9a2aca5b5e794f5c929bca9e494fae24"); // Note: Commented for speed

        // Deploy protocolProxy
        proxy = payable(new ProtocolProxy());

        // Deploy logic
        auctions = new Auctions();
        borrowing = new Borrowing();
        info = new Info();
        initializer = new Initializer();
        residents = new Residents();
        setter = new Setter();

        // Deploy chosen interest module
        UD60x18 baseYearlyRate = convert(uint(4)).div(convert(uint(100)));
        UD60x18 optimalUtilization = convert(uint(90)).div(convert(uint(100)));
        interest = new InterestCurve(baseYearlyRate, optimalUtilization);

        // Deploy Tokens
        // UNDERLYING = IERC20Metadata(USDC_ETHEREUM_MAINNET);
        UNDERLYING = new MockERC20("Circle USDC Token", "USDC");
        PROPERTY = new PropertyNft({
            name_: "Tangible Prospera Real Estate Token",
            symbol_: "tPROSPERA",
            protocolProxy_: proxy
        });

        vault = new Vault({
            name_: string.concat("Tangible ", UNDERLYING.name()),
            symbol_: string.concat("t", UNDERLYING.symbol()),
            UNDERLYING_: UNDERLYING,
            protocol_: proxy
        });

        // Set Function Selectors
        setSelectors();

        // Initialize proxy
        Initializer(proxy).initialize({
            _UNDERLYING: UNDERLYING,
            _PROPERTY: PROPERTY,
            _VAULT: vault
        });
    }

    function setSelectors() private {

        /// Set auctionSelectors
        bytes4[] memory auctionSelectors = new bytes4[](3);
        auctionSelectors[0] = IAuctions.bid.selector;
        auctionSelectors[1] = IAuctions.cancelBid.selector;
        auctionSelectors[2] = IAuctions.acceptBid.selector;
        ITargetManager(proxy).setSelectorsTarget(auctionSelectors, address(auctions));

        // Set borrowingSelectors
        bytes4[] memory borrowingSelectors = new bytes4[](7);
        borrowingSelectors[0] = IBorrowing.payMortgage.selector;
        borrowingSelectors[2] = IBorrowing.debtTransfer.selector;
        // borrowingSelectors[] = IBorrowing.refinance.selector;
        borrowingSelectors[3] = IBorrowing.foreclose.selector;
        borrowingSelectors[6] = IBorrowing.borrowerApr.selector;
        ITargetManager(proxy).setSelectorsTarget(borrowingSelectors, address(borrowing));

        // Set infoSelectors
        bytes4[] memory infoSelectors = new bytes4[](16);
        infoSelectors[0] = IInfo.isResident.selector;
        infoSelectors[1] = IInfo.addressToResident.selector;
        infoSelectors[2] = IInfo.residentToAddress.selector;
        infoSelectors[5] = IInfo.bids.selector;
        infoSelectors[6] = IInfo.bidsLength.selector;
        infoSelectors[7] = IInfo.bidActionable.selector;
        infoSelectors[10] = IInfo.unpaidPrincipal.selector;
        infoSelectors[11] = IInfo.accruedInterest.selector;
        infoSelectors[12] = IInfo.status.selector;
        infoSelectors[15] = IInfo.maxLtv.selector;
        ITargetManager(proxy).setSelectorsTarget(infoSelectors, address(info));

        // Set initializerSelectors
        bytes4[] memory initializerSelectors = new bytes4[](1);
        initializerSelectors[0] = Initializer.initialize.selector;
        ITargetManager(proxy).setSelectorsTarget(initializerSelectors, address(initializer));

        // Set residentSelectors
        bytes4[] memory residentSelectors = new bytes4[](1);
        residentSelectors[0] = IResidents.verifyResident.selector;
        ITargetManager(proxy).setSelectorsTarget(residentSelectors, address(residents));

        // Set setterSelectors
        bytes4[] memory setterSelectors = new bytes4[](3);
        setterSelectors[1] = ISetter.updateMaxLtv.selector;
        setterSelectors[2] = ISetter.updateMaxLoanMonths.selector;
        ITargetManager(proxy).setSelectorsTarget(setterSelectors, address(setter));

        // Set interestSelectors
        bytes4[] memory interestSelectors = new bytes4[](1);
        interestSelectors[0] = IInterest.calculateNewRatePerSecond.selector;
        ITargetManager(proxy).setSelectorsTarget(interestSelectors, address(interest));
    }
}
