// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.15;

// import "./IBorrowing.sol";
// import "../state/state/State.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "../interest/IInterest.sol";

// contract Borrowing is IBorrowing, State {

//     // Functions
//     function startLoan(TokenId tokenId, uint propertyValue, uint downPayment, address borrower) external {    

//         // Calculate & decode periodRate
//         (bool success, bytes memory data) = logicTargets[IInterest.calculatePeriodRate.selector].call(
//             abi.encodeCall(
//                 IInterest.calculatePeriodRate,
//                 (utilization())
//             )
//         );
//         require(success, "calculateYearlyBorrowerRate delegateCall failed");
//         UD60x18 periodRate = abi.decode(data, (UD60x18));
//     }
// }
