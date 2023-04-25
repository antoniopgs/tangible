// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IForeclosures.sol";
import "../state/state/State.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { fromUD60x18 } from "@prb/math/UD60x18.sol";

contract Foreclosures is IForeclosures, State {

    // Libs
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    function adminForeclose(TokenId tokenId, uint salePrice) external onlyOwner {
        _foreclose({
            tokenId: tokenId,
            salePrice: salePrice,
            foreclosurerCutRatio: UD60x18.wrap(0) // Note: if admin foreclosure: foreclosurerCutRatio is 0
        });
    }

    // function foreclose(TokenId tokenId) external {

    //     // Get highestBid
    //     UD60x18 highestBid;

    //     // Foreclose
    //     _foreclose({
    //         tokenId: tokenId,
    //         salePrice: highestBid,
    //         foreclosurerCutRatio: foreclosurerCutRatio // Note: if regular foreclosure: use foreclosurerCutRatio
    //     });
    // }

    // function chainlinkForeclose(TokenId tokenId) external {
    //     require(msg.sender == address(this), "unauthorized"); // Note: msg.sender must be address(this) because this will be called via delegatecall

    //     // Get highestBid
    //     UD60x18 highestBid;

    //     // Foreclose
    //     _foreclose({
    //         tokenId: tokenId,
    //         salePrice: highestBid,
    //         foreclosurerCutRatio: UD60x18.wrap(0) // Note: if chainlink foreclosure: foreclosurerCutRatio is 0 (because protocol pays LINK for it)
    //     });
    // }

    // in order to make this work, fix functional states, so that once default happens, "defaulted" view always returns true
    function _foreclose(TokenId tokenId, uint salePrice, UD60x18 foreclosurerCutRatio) private {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Ensure borrower has defaulted
        require(status(loan) == Status.Default, "no default");

        // Ensure 45 days have passed since default
        require(block.timestamp >= loan.nextPaymentDeadline + 45 days, "45 days must have passed since default"); // Note: maybe add "Foreclosurable" state afterwards?

        // Calculate defaulterDebt
        uint defaulterDebt = loan.balance + loan.unpaidInterest;

        require(salePrice >= defaulterDebt, "salePrice doesn't cover defaulterDebt + fees"); // Todo: add fees later

        // Remove loan.balance from loan.balance & totalPrincipal
        loan.balance -= 0;
        totalPrincipal -= loan.balance;

        // Add unpaidInterest to totalDeposits
        totalDeposits += loan.unpaidInterest;

        // Todo: Add Sale fee

        // Calculate defaulterEquity
        uint defaulterEquity = salePrice - defaulterDebt;

        // Calculate foreclosureFee
        uint foreclosureFee = fromUD60x18(foreclosureFeeRatio.mul(toUD60x18(defaulterEquity)));
        // UD60x18 foreclosureFee = foreclosureFeeRatio.mul(loan.salePrice); // shouldn't the ratio be applied to the salePrice?

        // Calculate foreclosurerCut
        uint foreclosurerCut = fromUD60x18(foreclosurerCutRatio.mul(toUD60x18(foreclosureFee)));

        // Calculate protocolCut
        uint protocolCut = foreclosureFee - foreclosurerCut;

        // Calculate leftover
        uint leftover = defaulterEquity - foreclosureFee;

        // Send foreclosurerCut to foreclosurer/caller
        USDC.safeTransferFrom(address(this), msg.sender, foreclosurerCut);

        // Add protocolCut to protocolMoney
        protocolMoney += protocolCut;

        // Send leftover to defaulter
        USDC.safeTransferFrom(address(this), loan.borrower, leftover);

        // Send Nft to highestBidder
        address highestBidder;
        sendNft(loan, highestBidder, TokenId.unwrap(tokenId));
    }
}
