// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Borrowing.sol";

abstract contract Foreclosures is Borrowing {

    UD60x18 foreclosureFee;
    UD60x18 foreclosurerCut;
    UD60x18 tangibleUsdc;

    // Libs
    using SafeERC20 for IERC20;

    function chainlinkForeclose(Loan calldata loan) internal {

        // Ensure loan is foreclosurable
        require(state(loan) == State.Default, "no default");

        // Calculate foreclosureFeeAmount
        UD60x18 foreclosureFeeAmount = foreclosureFee.mul(loan.propertyValue); // Note: for upgradeability purposes, should propertyValue be inside the loan struct?

        // Tangible has to pay for chainlink keepers, so it keeps all the foreclosureFeeAmount
        tangibleUsdc = tangibleUsdc.add(foreclosureFeeAmount);
    }

    function foreclose(string calldata propertyUri) external {

        // Get loan
        Loan storage loan = loans[propertyUri];

        // Ensure borrower has defaulted
        require(state(loan) == State.Default, "no default");

        // Zero-out nextPaymentDeadline
        loan.nextPaymentDeadline = 0;

        // Calculate foreclosureFeeAmount
        UD60x18 foreclosureFeeAmount = foreclosureFee.mul(loan.propertyValue);

        // Calculate foreclosureCutAmount
        UD60x18 foreclosurerCutAmount = foreclosurerCut.mul(foreclosureFeeAmount);

        // Give foreclosurerCutAmount to foreclosurer/caller
        USDC.safeTransferFrom(address(this), msg.sender, foreclosurerCutAmount);

        // Tangible keeps rest of foreclosureFeeAmount
        tangibleUsdc = tangibleUsdc.add(foreclosureFeeAmount.sub(foreclosureFeeAmount));
    }

    function completeForeclosure(string calldata propertyUri, UD60x18 salePrice) external onlyOwner {

        // Get Loan
        Loan storage loan = loans[propertyUri];

        // Ensure property has been foreclosed
        require(state(loan) == State.Foreclosed, "no foreclosure");       

        // Remove loan.balance from loan.balance & totalBorrowed
        loan.balance = loan.balance.sub(loan.balance);
        totalBorrowed = totalBorrowed.sub(loan.balance);

        // Add unpaidInterest to totalDeposits
        totalDeposits = totalDeposits.add(loan.unpaidInterest);

        // Calculate defaulterDebt
        UD60x18 defaulterDebt = loan.balance.add(loan.unpaidInterest);

        // Calculate defaulterEquity
        UD60x18 defaulterEquity = salePrice.sub(defaulterDebt);

        // Send defaulterEquity to defaulter
        USDC.safeTransferFrom(address(this), loan.borrower, fromUD60x18(defaulterEquity));

        // Reset loan state to Null (so it can re-enter system later)
        loan.borrower = address(0);
    }
}
