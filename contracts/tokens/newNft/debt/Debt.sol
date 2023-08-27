// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IDebt.sol";
import "../roles/Roles.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { convert } from "@prb/math/src/UD60x18.sol";

abstract contract Debt is IDebt, Roles {

    IERC20 public /* immutable */ USDC;
    mapping(uint => Debt) public tokenDebts;

    // constructor(address usdc) {
    //     USDC = IERC20(usdc);
    // }

    // function startNewMortgage() external {

    //     // 1. Buyer sends downPayment to seller
    //     USDC.safeTransferFrom(msg.sender, seller, downPayment);

    //     // 2. Pool sends principal to seller
    //     USDC.safeTransfer(seller, principal);

    //     // 3. Admin transfers token from seller to buyer
    //     nft.safeTransferFrom(seller, buyer, tokenId);
    // }

    // User Functions
    function startNewMortgage(uint tokenId) external { // Todo: MUST WORK ON TRANSFER

    }

    function payMortgage(uint tokenId, uint payment) external {

    }

    function redeemMortgage(uint tokenId) external {

    }

    // Admin Functions
    function refinance(uint tokenId) external onlyRole(GSP) {

    }

    function foreclose(uint tokenId) external onlyRole(PAC) {

    }

    function updateOtherDebt(uint tokenId, string calldata motive) external onlyRole(GSP) {

    }

    function accruedInterest(Loan memory loan) internal view returns(uint) {
        return convert(convert(loan.unpaidPrincipal).mul(accruedRate(loan)));
    }

    function accruedRate(Loan memory loan) private view returns(UD60x18) {
        return loan.ratePerSecond.mul(convert(secondsSinceLastPayment(loan)));
    }

    function secondsSinceLastPayment(Loan memory loan) private view returns(uint) {
        return block.timestamp - loan.lastPaymentTime;
    }
}