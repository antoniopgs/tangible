// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IForeclosures.sol";
import "../state/state/State.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Foreclosures is IForeclosures, State {

    // Libs
    using SafeERC20 for IERC20;

    // in order to make this work, fix functional states, so that once default happens, "defaulted" view always returns true
    function foreclose(TokenId tokenId, UD60x18 salePrice) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Ensure borrower has defaulted
        require(defaulted(loan), "no default"); 

        // Remove loan.balance from loan.balance & totalBorrowed
        loan.balance = loan.balance.sub(loan.balance);
        totalBorrowed = totalBorrowed.sub(loan.balance);

        // Add unpaidInterest to totalDeposits
        totalDeposits = totalDeposits.add(loan.unpaidInterest);

        // Calculate defaulterDebt
        UD60x18 defaulterDebt = loan.balance.add(loan.unpaidInterest);

        // Calculate defaulterEquity
        UD60x18 defaulterEquity = salePrice.sub(defaulterDebt);

        // Calculate foreclosureFee
        UD60x18 foreclosureFee = foreclosureFeeRatio.mul(defaulterEquity);

        // Calculate foreclosurerCut
        UD60x18 foreclosurerCut = foreclosurerCutRatio.mul(foreclosureFee);

        // Send foreclosurerCut to foreclosurer/caller
        USDC.safeTransferFrom(address(this), msg.sender, foreclosurerCut);

        // Add rest of foreclosureFee (foreclosureFee - foreclosurerCut) to protocolMoney
        protocolMoney += foreclosureFee.sub(foreclosurerCut);

        // Send rest (defaulterEquity - foreclosureFee) to defaulter
        USDC.safeTransferFrom(address(this), loan.borrower, fromUD60x18(defaulterEquity.sub(foreclosureFee)));

        // Reset loan state to Null (so it can re-enter system later)
        loan.borrower = address(0);
    }
}
