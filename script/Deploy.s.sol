// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Main Imports
import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

// Contract Imports
import "../contracts/protocol/borrowing/borrowing/Borrowing.sol";
import "../contracts/protocol/interest/Interest.sol";
import "../contracts/protocol/lending/Lending.sol";
import "../contracts/protocol/info/Info.sol";
import "../contracts/protocol/protocolProxy/ProtocolProxy.sol";

// Token Imports
import "../contracts/mock/MockUsdc.sol";
import "../contracts/tokens/tUsdc.sol";


contract DeployScript is Script {

    // Tokens
    IERC20 USDC; /* = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // Note: ethereum mainnet */
    tUsdc tUSDC;
    TangibleNft nftContract;

    // Protocol
    address payable protocol;

    // Logic Contracts
    Borrowing borrowing;
    Interest interest;
    Lending lending;
    Info info;

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
        borrowing = new Borrowing();
        interest = new Interest();
        lending = new Lending();
        info = new Info();

        // Set borrowingSelectors
        bytes4[] memory borrowingSelectors = new bytes4[](3);
        borrowingSelectors[0] = IBorrowing.startNewLoan.selector;
        borrowingSelectors[1] = IBorrowing.payLoan.selector;
        borrowingSelectors[2] = IBorrowing.redeemLoan.selector;
        // borrowingSelectors[3] = IBorrowing.forecloseLoan.selector; // Note: maybe I don't even need a foreclosure function, because startLoan() could take care of it
        ProtocolProxy(protocol).setSelectorsTarget(borrowingSelectors, address(borrowing));

        // Set interestSelectors
        bytes4[] memory interestSelectors = new bytes4[](1);
        interestSelectors[0] = IInterest.borrowerRatePerSecond.selector;
        ProtocolProxy(protocol).setSelectorsTarget(interestSelectors, address(interest));

        // Set lendingSelectors
        bytes4[] memory lendingSelectors = new bytes4[](2);
        lendingSelectors[0] = ILending.deposit.selector;
        lendingSelectors[1] = ILending.withdraw.selector;
        ProtocolProxy(protocol).setSelectorsTarget(lendingSelectors, address(lending));

        // Set infoSelectors
        bytes4[] memory infoSelectors = new bytes4[](14);
        infoSelectors[0] = IInfo.loans.selector;
        infoSelectors[1] = IInfo.availableLiquidity.selector;
        infoSelectors[2] = IInfo.userLoans.selector;
        infoSelectors[3] = IInfo.loansTokenIdsLength.selector;
        infoSelectors[4] = IInfo.loansTokenIdsAt.selector;
        infoSelectors[5] = IInfo.redemptionFeeSpread.selector;
        infoSelectors[6] = IInfo.defaultFeeSpread.selector;
        infoSelectors[7] = IInfo.unpaidPrincipal.selector;
        infoSelectors[8] = IInfo.accruedInterest.selector;
        infoSelectors[9] = IInfo.lenderApy.selector;
        infoSelectors[10] = IInfo.usdcToTUsdc.selector;
        infoSelectors[11] = IInfo.tUsdcToUsdc.selector;
        infoSelectors[12] = IInfo.status.selector;
        infoSelectors[13] = IInfo.utilization.selector;
        ProtocolProxy(protocol).setSelectorsTarget(infoSelectors, address(info));
    }
}
