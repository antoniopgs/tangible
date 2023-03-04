// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@chainlink/contracts/AutomationCompatible.sol"; // Note: imports from ./AutomationBase.sol & ./interfaces/AutomationCompatibleInterface.sol
import "../pool/IPool.sol";
import "../foreclosures/IForeclosures.sol";

abstract contract Automation is AutomationCompatibleInterface {

    IForeclosures foreclosures;
    IPool pool;

    function checkUpkeep(bytes calldata checkData) external view override returns (bool upkeepNeeded, bytes memory performData) { // Note: maybe implement batch liquidations later

        // Loop properties
        for (uint i = 0; i < pool.propertiesLength(); i++) {

            // Load property loan
            Loan memory loan = pool.propertyAt(i).loan;

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
        foreclosures.chainlinkForeclose(loan);
    }
}
