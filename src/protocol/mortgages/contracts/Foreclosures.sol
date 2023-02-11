// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Borrowing.sol";

abstract contract Foreclosures is Borrowing {

    function foreclose(string calldata propertyUri) external {

        // Get loan
        Loan storage loan = loans[propertyUri];

        // Ensure current loan status is Mortgage
        require(loan.status == Status.Mortgage);

        // Ensure loan is foreclosurable
        require(foreclosurable(loans[propertyUri]));

        // Change loan status to Foreclosed
        loan.status = Status.Foreclosed;
    }

    function foreclosurable(Loan memory loan) private view returns (bool) {
        return block.timestamp > loan.nextPaymentDeadline + (30 days * allowedDelayedPayments);
    }
}