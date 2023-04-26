// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@chainlink/contracts/AutomationCompatible.sol"; // Note: imports from ./AutomationBase.sol & ./interfaces/AutomationCompatibleInterface.sol
import "../state/state/State.sol";
import "../foreclosures/IForeclosures.sol";

contract Automation is AutomationCompatibleInterface, State {
    
    // Libs
    using EnumerableSet for EnumerableSet.UintSet;

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) { // Note: maybe implement batch foreclosures later

        // Loop loans
        for (uint i = 0; i < loansTokenIds.length(); i++) {

            // Get tokenId
            uint tokenId = loansTokenIds.at(i);

            // Get loan 
            Loan memory loan = loans[TokenId.wrap(tokenId)];

            // If loan is foreclosurable
            if (status(loan) == Status.Foreclosurable) {
                
                // Find highestActionableBidIdx
                uint highestActionableBidIdx = findHighestActionableBidIdx(tokenId);

                // Update return vars
                upkeepNeeded = true;
                performData = abi.encode(tokenId, highestActionableBidIdx);

                // Return // Note: For now, exit as soon as one is found
                return;
            }
        }
    }

    function performUpkeep(bytes calldata performData) external override {
        
        // Decode tokenId
        (uint tokenId) = abi.decode(performData, (uint));

        // Chainlink Foreclose (via delegatecall)
        (bool success, ) = logicTargets[IForeclosures.chainlinkForeclose.selector].delegatecall(
            abi.encodeCall(
                IForeclosures.chainlinkForeclose,
                (TokenId.wrap(tokenId))
            )
        );
        require(success, "chainlinkForeclose delegateCall failed");
    }
}
