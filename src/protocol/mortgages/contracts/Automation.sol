// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@chainlink/contracts/AutomationCompatible.sol"; // Note: imports from ./AutomationBase.sol & ./interfaces/AutomationCompatibleInterface.sol
import "./Foreclosures.sol";

abstract contract Automation is Foreclosures, AutomationCompatibleInterface {

    function checkUpkeep(bytes calldata checkData) external view override returns (bool upkeepNeeded, bytes memory performData) { // Note: maybe implement batch liquidations later

        // Loop loans
        for (uint i = 0; i < loans.length(); i++) {

            // Load loan
            Loan memory loan = loans.at(i);

            // If loan has been defaulted
            if (state(loan) == State.Default) {

                // Return
                upkeepNeeded = true;
                performData = abi.encode(loan);
                return;
            }
        }
    }

    function performUpkeep(bytes calldata performData) external override {
        
        // Decode loan
        (Loan memory loan) = abi.decode(performData, (Loan));

        // Chainlink foreclose
        chainlinkForeclose(loan);
    }
}
