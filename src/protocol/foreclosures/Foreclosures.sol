// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IForeclosures.sol";
import "../state/state/State.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Foreclosures is IForeclosures, State {

    // Libs
    using SafeERC20 for IERC20;

    function adminForeclose(TokenId tokenId, UD60x18 salePrice) external onlyOwner {
        _foreclose({
            tokenId: tokenId,
            salePrice: salePrice,
            foreclosurerCutRatio: UD60x18.wrap(0) // Note: if admin foreclosure: foreclosurerCutRatio is 0
        });
    }

    function foreclose(TokenId tokenId) external {

        // Get highestBid
        UD60x18 highestBid;

        // Foreclose
        _foreclose({
            tokenId: tokenId,
            salePrice: highestBid,
            foreclosurerCutRatio: foreclosurerCutRatio // Note: if regular foreclosure: use foreclosurerCutRatio
        });
    }

    function chainlinkForeclose(TokenId tokenId) external {

        // Get highestBid
        UD60x18 highestBid;

        // Foreclose
        _foreclose({
            tokenId: tokenId,
            salePrice: highestBid,
            foreclosurerCutRatio: UD60x18.wrap(0) // Note: if chainlink foreclosure: foreclosurerCutRatio is 0 (because protocol pays LINK for it)
        });
    }

    // in order to make this work, fix functional states, so that once default happens, "defaulted" view always returns true
    function _foreclose(TokenId tokenId, UD60x18 salePrice, UD60x18 foreclosurerCutRatio) private {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Ensure borrower has defaulted
        require(state(loan) == State.Default, "no default");

        // Calculate defaulterDebt
        UD60x18 defaulterDebt = loan.balance.add(loan.unpaidInterest);

        require(salePrice.gte(defaulterDebt), "salePrice doesn't cover defaulterDebt + fees"); // Todo: add fees later

        // Remove loan.balance from loan.balance & totalBorrowed
        loan.balance = loan.balance.sub(loan.balance);
        totalBorrowed = totalBorrowed.sub(loan.balance);

        // Add unpaidInterest to totalDeposits
        totalDeposits = totalDeposits.add(loan.unpaidInterest);

        // Todo: Add Sale fee

        // Calculate defaulterEquity
        UD60x18 defaulterEquity = salePrice.sub(defaulterDebt);

        // Calculate foreclosureFee
        UD60x18 foreclosureFee = foreclosureFeeRatio.mul(defaulterEquity);
        // UD60x18 foreclosureFee = foreclosureFeeRatio.mul(loan.salePrice); // shouldn't the ratio be applied to the salePrice?

        // Calculate foreclosurerCut
        UD60x18 foreclosurerCut = foreclosurerCutRatio.mul(foreclosureFee);

        // Calculate protocolCut
        UD60x18 protocolCut = foreclosureFee.sub(foreclosurerCut);

        // Calculate leftover
        UD60x18 leftover = defaulterEquity.sub(foreclosureFee);

        // Send foreclosurerCut to foreclosurer/caller
        USDC.safeTransferFrom(address(this), msg.sender, fromUD60x18(foreclosurerCut));

        // Add protocolCut to protocolMoney
        protocolMoney = protocolMoney.add(protocolCut);

        // Send leftover to defaulter
        USDC.safeTransferFrom(address(this), loan.borrower, fromUD60x18(leftover));

        // Reset loan state to Null (so it can re-enter system later)
        loan.borrower = address(0);
    }
}
