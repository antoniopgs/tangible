// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@chainlink/contracts/AutomationCompatible.sol"; // Note: imports from ./AutomationBase.sol & ./interfaces/AutomationCompatibleInterface.sol
import "../protocol/foreclosures/IForeclosures.sol";

contract Automation is AutomationCompatibleInterface {

    IForeclosures protocol;
    
    // Libs
    // using EnumerableSet for EnumerableSet.UintSet;

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) { // Note: maybe implement batch liquidations later

        // Loop loans
        for (uint i = 0; i < loansTokenIds.length(); i++) {

            // Get tokenId
            uint tokenId = loansTokenIds.at(i);

            // Get loan 
            Loan memory loan = loans[TokenId.wrap(tokenId)];

            // If loan has been defaulted
            if (state(loan) == State.Default) {

                // Return
                upkeepNeeded = true;
                performData = abi.encode(tokenId);
            }
        }
    }

    function performUpkeep(bytes calldata performData) external override {
        
        // Decode tokenId
        (uint tokenId) = abi.decode(performData, (uint));

        // Chainlink foreclose
        protocol.chainlinkForeclose(tokenId);
    }
}
