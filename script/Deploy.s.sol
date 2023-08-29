// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.15;

// // Main Imports
// import "forge-std/Script.sol";
// import { console } from "forge-std/console.sol";

// // Contract Imports
// import "../contracts/protocol/borrowing/borrowing/Borrowing.sol";
// import "../contracts/protocol/interest/Interest.sol";
// import "../contracts/protocol/lending/Lending.sol";
// import "../contracts/protocol/info/Info.sol";
// import "../contracts/protocol/protocolProxy/ProtocolProxy.sol";

// // Token Imports
// import "../contracts/mock/MockUsdc.sol";
// import "../contracts/tokens/tUsdc.sol";


// contract DeployScript is Script {

//     // Tokens
//     IERC20 USDC; /* = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // Note: ethereum mainnet */
//     tUsdc tUSDC;
//     TangibleNft nftContract;

//     // Proxy
//     address payable proxy;

//     // Logic Contracts
//     Lending lending;
//     Borrowing borrowing;
//     Info info;

//     // Multi-Sig
//     address PAC;

//     constructor() {

//         // Fork (needed for tUSDC's ERC777 registration in the ERC1820 registry)
//         vm.createSelectFork("https://mainnet.infura.io/v3/f36750d69d314e3695b7fe230bb781af");

//         // Deploy proxy
//         proxy = payable(new ProtocolProxy());

//         // Build tUsdcDefaultOperators;
//         address[] memory tUsdcDefaultOperators = new address[](1);
//         tUsdcDefaultOperators[0] = address(proxy);

//         // Deploy mockUSDC
//         USDC = new MockUsdc();

//         // Deploy tUSDC
//         tUSDC = new tUsdc(tUsdcDefaultOperators);

//         // Deploy PAC Multi-Sig
//         PAC = address(0); // Todo: fix later

//         // Deploy nftContract
//         nftContract = new TangibleNft(proxy, PAC);

//         // Initialize proxy
//         ProtocolProxy(proxy).initialize(USDC, tUSDC, nftContract);

//         // Deploy logic contracts
//         lending = new Lending();
//         borrowing = new Borrowing();
//         info = new Info();

//         // Set lendingSelectors
//         bytes4[] memory lendingSelectors = new bytes4[](2);
//         lendingSelectors[0] = ILending.deposit.selector;
//         lendingSelectors[1] = ILending.withdraw.selector;
//         ProtocolProxy(proxy).setSelectorsTarget(lendingSelectors, address(lending));

//         // Set borrowingSelectors
//         bytes4[] memory borrowingSelectors = new bytes4[](3);
//         borrowingSelectors[0] = IBorrowing.startNewLoan.selector;
//         borrowingSelectors[1] = IBorrowing.payLoan.selector;
//         borrowingSelectors[2] = IBorrowing.redeemLoan.selector;
//         ProtocolProxy(proxy).setSelectorsTarget(borrowingSelectors, address(borrowing));

//         // Set infoSelectors
//         bytes4[] memory infoSelectors = new bytes4[](15);
//         infoSelectors[0] = IInfo.loans.selector;
//         infoSelectors[1] = IInfo.availableLiquidity.selector;
//         infoSelectors[2] = IInfo.userLoans.selector;
//         infoSelectors[3] = IInfo.loansTokenIdsLength.selector;
//         infoSelectors[4] = IInfo.loansTokenIdsAt.selector;
//         infoSelectors[5] = IInfo.redemptionFeeSpread.selector;
//         infoSelectors[6] = IInfo.defaultFeeSpread.selector;
//         infoSelectors[7] = IInfo.unpaidPrincipal.selector;
//         infoSelectors[8] = IInfo.accruedInterest.selector;
//         infoSelectors[9] = IInfo.lenderApy.selector;
//         infoSelectors[10] = IInfo.usdcToTUsdc.selector;
//         infoSelectors[11] = IInfo.tUsdcToUsdc.selector;
//         infoSelectors[12] = IInfo.status.selector;
//         infoSelectors[13] = IInfo.utilization.selector;
//         infoSelectors[14] = IInfo.borrowerApr.selector;
//         ProtocolProxy(proxy).setSelectorsTarget(infoSelectors, address(info));
//     }
// }
