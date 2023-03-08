// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@chainlink/contracts/AutomationCompatible.sol"; // Note: imports from ./AutomationBase.sol & ./interfaces/AutomationCompatibleInterface.sol
import "../../config/config/ConfigUser.sol";
import "../foreclosures/IForeclosures.sol";
import "../vault/state/IState.sol";

contract Automation is AutomationCompatibleInterface, ConfigUser {

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) { // Note: maybe implement batch liquidations later

        // Get vault
        IState vault = IState(config.getAddress(VAULT));

        // Loop properties
        for (uint i = 0; i < vault.propertiesLength(); i++) {

            // Load property loan
            Loan memory loan = vault.loanAt(Idx.wrap(i));

            // If loan has been defaulted
            if (vault.state(loan) == IState.PropertyState.Default) {

                // Return
                upkeepNeeded = true;
                performData = abi.encode(loan);
            }
        }
    }

    function performUpkeep(bytes calldata performData) external override {
        
        // Decode loan
        (Loan memory loan) = abi.decode(performData, (Loan));

        // Chainlink foreclose
        IForeclosures(config.getAddress(FORECLOSURES)).chainlinkForeclose(loan);
    }
}
