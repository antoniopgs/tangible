// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@chainlink/contracts/AutomationCompatible.sol"; // Note: imports from ./AutomationBase.sol & ./interfaces/AutomationCompatibleInterface.sol
import "../state/state/State.sol";
import "../borrowing/IBorrowing.sol";

contract Automation is AutomationCompatibleInterface, State {
    
    // Libs
    using EnumerableSet for EnumerableSet.UintSet;

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) { // Note: maybe implement batch foreclosures later

        // Loop loans
        for (uint i = 0; i < loansTokenIds.length(); i++) {

            // Get tokenId
            TokenId tokenId = TokenId.wrap(loansTokenIds.at(i));

            // Get loan 
            Loan memory loan = loans[tokenId];

            // If loan is foreclosurable
            if (status(loan) == Status.Foreclosurable) {
                
                // Find highestActionableBidIdx
                uint highestActionableBidIdx = findHighestActionableBidIdx(tokenId);

                // Update return vars
                upkeepNeeded = true;
                performData = abi.encode(tokenId, highestActionableBidIdx);

                // Break // Note: For now, exit as soon as one is found
                break;
            }
        }
    }

    function performUpkeep(bytes calldata performData) external override {
        
        // Decode tokenId
        (TokenId tokenId, uint highestActionableBidIdx) = abi.decode(performData, (TokenId, uint));

        // Foreclose (via delegatecall)
        (bool success, ) = logicTargets[IBorrowing.forecloseLoan.selector].delegatecall(
            abi.encodeCall(
                IBorrowing.forecloseLoan,
                (tokenId, highestActionableBidIdx)
            )
        );
        require(success, "chainlinkForeclose delegateCall failed");
    }

    // Views
    function findHighestActionableBidIdx(TokenId tokenId) private view returns (uint highestActionableIdx) {

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
