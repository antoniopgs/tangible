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

    // Functions
    function foreclose(TokenId tokenId, uint bidIdx) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Ensure borrower has defaulted
        require(status(loan) == Status.Foreclosurable, "no default");

        // Get Bid
        Bid memory bid = bids[tokenId][bidIdx];

        // Calculate defaulterDebt
        uint defaulterDebt = loan.balance + loan.unpaidInterest; // Todo: fix defaulterDebt (and in other places too)

        require(bid.propertyValue >= defaulterDebt, "bid.propertyValue doesn't cover defaulterDebt + fees"); // Todo: add fees later

        // Remove loan.balance from loan.balance & totalPrincipal
        loan.balance -= 0;
        totalPrincipal -= loan.balance;

        // Add unpaidInterest to totalDeposits
        totalDeposits += loan.unpaidInterest;

        // Todo: Add Sale fee

        // Calculate defaulterEquity
        uint defaulterEquity = bid.propertyValue - defaulterDebt;

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
    
    // Views
    function findHighestActionableBidIdx(TokenId tokenId) external view returns (uint highestActionableIdx) {

        // Get propertyBids
        Bid[] memory propertyBids = bids[tokenId];

        // Loop propertyBids
        for (uint i = 0; i < propertyBids.length; i++) {

            // Get bid
            Bid memory bid = propertyBids[i];

            // If bid has higher propertyValue and is actionable
            if (bid.propertyValue > propertyBids[highestActionableIdx].propertyValue && bidActionable(bid)) {

                // Update highestActionableIdx // Note: might run into problems if nothing is returned and it defaults to 0
                highestActionableIdx = i;
            }    
        }
    }
}
