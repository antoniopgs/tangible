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

        // Set borrowingSigs
        bytes4[] memory borrowingSigs = [
            IBorrowing.startLoan.selector,
            IBorrowing.payLoan.selector,
            IBorrowing.redeem.selector,
            IBorrowing.foreclose.selector
        ];
        ProtocolProxy(protocol).setSelectorsTarget(borrowingSigs, address(borrowing));

        // Set borrowingSigs
        bytes4[] memory lendingSigs = [
            ILending.deposit.selector,
            ILending.withdraw.selector
        ];
        ProtocolProxy(protocol).setSelectorsTarget(lendingSigs, address(lending));
    }
}
