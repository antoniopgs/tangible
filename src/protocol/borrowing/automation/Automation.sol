// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@chainlink/contracts/AutomationCompatible.sol"; // Note: imports from ./AutomationBase.sol & ./interfaces/AutomationCompatibleInterface.sol
import "../borrowing/Borrowing.sol";
import { SD59x18, toSD59x18 } from "@prb/math/SD59x18.sol";
import { fromUD60x18 } from "@prb/math/UD60x18.sol";

contract Automation is AutomationCompatibleInterface, Borrowing {
    
    // Libs
    using EnumerableSet for EnumerableSet.UintSet;

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) { // Note: maybe implement batch foreclosures later

        // Loop loans
        for (uint i = 0; i < loansTokenIds.length(); i++) {

            // Get tokenId
            uint tokenId = loansTokenIds.at(i);

            // If loan is foreclosurable
            if (status(tokenId) == Status.Foreclosurable) {
                
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
        (uint tokenId, uint highestActionableBidIdx) = abi.decode(performData, (uint, uint));

        // Foreclose (via delegatecall)
        forecloseLoan(tokenId, highestActionableBidIdx);
    }

    // Views
    function findHighestActionableBidIdx(uint tokenId) /*private*/ public view returns (uint highestActionableIdx) { // Note: made public for testing

        // Get propertyBids
        Bid[] memory propertyBids = _bids[tokenId];

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
