// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import "../src/protocolProxy/ProtocolProxy.sol";
import "../src/tokens/tUsdc.sol";
import "../src/borrowing/Borrowing.sol";
import "../src/lending/Lending.sol";

contract DeployScript is Script {

    IERC20 USDC;
    tUsdc tUSDC;

    address payable protocol;
    Borrowing borrowing;
    Lending lending;

    constructor() {

        // Fork (needed for tUSDC's ERC777 registration in the ERC1820 registry)
        vm.createSelectFork("https://mainnet.infura.io/v3/f36750d69d314e3695b7fe230bb781af");

        USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // Note: ethereum mainnet

        // Deploy protocol
        protocol = payable(new ProtocolProxy());

        // Build tUsdcDefaultOperators;
        address[] memory tUsdcDefaultOperators = new address[](1);
        tUsdcDefaultOperators[0] = address(protocol);

        // Deploy tUSDC
        tUSDC = new tUsdc(tUsdcDefaultOperators);

        // Initialize protocol
        ProtocolProxy(protocol).initialize(tUSDC);

        // Deploy logic contracts
        borrowing = new Borrowing();
        lending = new Lending();

        // Set borrowingSelectors
        bytes4[] memory borrowingSelectors = new bytes4[](14);
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
        borrowingSelectors[11] = Borrowing.defaulted.selector;
        borrowingSelectors[12] = State.loans.selector;
        borrowingSelectors[13] = Borrowing.accruedInterest.selector;
        ProtocolProxy(protocol).setSelectorsTarget(borrowingSelectors, address(borrowing));

        // Set borrowingSelectors
        bytes4[] memory lendingSelectors = new bytes4[](3);
        lendingSelectors[0] = ILending.deposit.selector;
        lendingSelectors[1] = ILending.withdraw.selector;
        lendingSelectors[2] = Lending.usdcToTUsdc.selector;
        ProtocolProxy(protocol).setSelectorsTarget(lendingSelectors, address(lending));
    }
}
