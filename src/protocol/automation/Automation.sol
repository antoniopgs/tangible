// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@chainlink/contracts/AutomationCompatible.sol"; // Note: imports from ./AutomationBase.sol & ./interfaces/AutomationCompatibleInterface.sol
import "../foreclosures/Foreclosures.sol";

contract Automation is AutomationCompatibleInterface, Foreclosures {
    
    // Libs
    using EnumerableSet for EnumerableSet.UintSet;

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) { // Note: maybe implement batch liquidations later

        // Loop loans
        for (uint i = 0; i < loansTokenIds.length(); i++) {

            // Load property loan
            // Loan memory loan = vault.loanAt(Idx.wrap(i));
            Loan memory loan = loans[TokenId.wrap(loansTokenIds.at(i))];

            // If loan has been defaulted
            if (state(loan) == State.Default) {

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
        chainlinkForeclose(loan);
    }

    function chainlinkForeclose(Loan memory loan) internal {

        // Ensure loan is foreclosurable
        require(state(loan) == State.Default, "no default");

        // Calculate foreclosureFee
        UD60x18 foreclosureFee = foreclosureFeeRatio.mul(loan.propertyValue); // Note: for upgradeability purposes, should propertyValue be inside the loan struct?

        // Add foreclosureFee to protocolMoney // Note: Protocol pays for chainlink, so it keeps all the foreclosureFee here
        protocolMoney += foreclosureFee;
    }
}
