// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../borrowing/IBorrowing.sol";
import "@prb/math/UD60x18.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../pool/IPool.sol";

contract Foreclosures is IBorrowing {

    // Foreclosure vars
    UD60x18 foreclosureFeeRatio;
    UD60x18 foreclosurerCutRatio;

    // Links
    IERC20 USDC;
    IPool pool;
    address tangibleVault;

    // Libs
    using SafeERC20 for IERC20;

    function chainlinkForeclose(Loan calldata loan) external {

        // Ensure loan is foreclosurable
        require(state(loan) == State.Default, "no default");

        // Calculate foreclosureFee
        UD60x18 foreclosureFee = foreclosureFeeRatio.mul(loan.propertyValue); // Note: for upgradeability purposes, should propertyValue be inside the loan struct?

        // Send foreclosureFee from pool to tangibleVault // Tangible has to pay for chainlink keepers, so it should keep all the foreclosureFee
        USDC.safeTransferFrom(address(pool), address(tangibleVault), foreclosureFee);
    }

    // in order to make this work, fix functional states, so that once default happens, "defaulted" view always returns true
    function foreclose(uint tokenId, UD60x18 salePrice) external {

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

        // Calculate foreclosureCut
        UD60x18 foreclosurerCut = foreclosurerCutRatio.mul(foreclosureFee);

        // Send foreclosurerCut to foreclosurer/caller
        USDC.safeTransferFrom(address(pool), msg.sender, foreclosurerCut);

        // Send rest of foreclosureFee (foreclosureFee - foreclosurerCut) to tangibleVault
        USDC.safeTransferFrom(address(pool), address(tangibleVault), foreclosureFee.sub(foreclosurerCut));

        // Send rest (defaulterEquity - foreclosureFee) from pool to defaulter
        USDC.safeTransferFrom(address(pool), loan.borrower, fromUD60x18(defaulterEquity.sub(foreclosureFee)));

        // Reset loan state to Null (so it can re-enter system later)
        loan.borrower = address(0);
    }

    function defaulted(Loan calldata loan) private view returns(bool) {

    }
}
