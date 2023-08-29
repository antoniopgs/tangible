// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IBorrowing.sol";
import "../interest/Interest.sol";
import "../status/Status.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Borrowing is IBorrowing, Interest, Status {

    // Libs
    using SafeERC20 for IERC20;

    // Functions
    function startNewLoan(address buyer, uint tokenId, uint propertyValue, uint downPayment, uint maxDurationMonths) external /* onlyOwner */ {
        require(prosperaNftContract.isEResident(buyer), "buyer not eResident");
        require(_availableLiquidity() >= propertyValue - downPayment, "insufficient liquidity for loan");

        // Pull downPayment from buyer
        USDC.safeTransferFrom(buyer, address(this), downPayment); // Note: maybe better to separate this from other contracts which also pull USDC, to compartmentalize approvals

        // Get loan
        Loan memory loan = _loans[tokenId];

        // If NFT is ResidentOwned
        if (_status(tokenId) == Status.ResidentOwned) {
            
            // Get nftOwner
            address nftOwner = prosperaNftContract.ownerOf(tokenId);

            // Pull NFT from nftOwner to protocol
            prosperaNftContract.safeTransferFrom(nftOwner, address(this), tokenId); // Note: don't use loan.owner (it doesn't get cleared-out anymore, but NFT could have been transferred)

            // Cover Debts (oldOwner = nftOwner)
            _coverDebt({
                tokenId: tokenId,
                propertyValue: propertyValue,
                oldOwner: nftOwner
            });

        // Else
        } else {

            // Cover Debts (oldOwner = loan.owner)
            _coverDebt({
                tokenId: tokenId,
                propertyValue: propertyValue,
                oldOwner: loan.owner
            });
        }

        // Start New Mortgage
        _startNewMortgage({
            newOwner: buyer,
            tokenId: tokenId,
            principal: propertyValue - downPayment,
            maxDurationMonths: maxDurationMonths
        });
    }

    function _coverDebt(uint tokenId, uint propertyValue, address oldOwner) private {

        // Get loan
        Loan memory loan = _loans[tokenId];

        // 0. Get loan
        uint unpaidPrincipal = loan.unpaidPrincipal;
        uint interest = _accruedInterest(loan); // will be 0 if unpaidPrincipal == 0

        // 1. If loan has debt, Pay Lenders
        if (unpaidPrincipal > 0) {

            // Protocol charges Interest Fee
            uint interestFee = convert(convert(interest).mul(_interestFeeSpread));
            protocolMoney += interestFee;

            // Update Pool
            totalPrincipal -= unpaidPrincipal;
            totalDeposits += interest - interestFee;
            // maxTotalUnpaidInterest -= interest;
        }

        // 2. Protocol charges Sale Fee
        UD60x18 saleFeeSpread = _baseSaleFeeSpread;
        if (_status(tokenId) == Status.Default || _status(tokenId) == Status.Foreclosurable) {
            saleFeeSpread = saleFeeSpread.add(_defaultFeeSpread); // Question: maybe defaultFee should be a boost appplied to interest instead?
        }
        uint saleFee = convert(convert(propertyValue).mul(saleFeeSpread)); // Question: should this be off propertyValue, or defaulterDebt?
        protocolMoney += saleFee;

        // 3. Pay oldOwner his equity (loan.owner)
        uint debt = unpaidPrincipal + interest + saleFee;
        require(propertyValue >= debt, "propertyValue must cover debt");

        USDC.safeTransfer(oldOwner, propertyValue - debt);
    }

    function _startNewMortgage(
        address newOwner,
        uint tokenId,
        uint principal,
        uint maxDurationMonths
    ) private {

        // Get ratePerSecond
        UD60x18 ratePerSecond = borrowerRatePerSecond(_utilization());

        // Calculate maxDurationSeconds
        uint maxDurationSeconds = maxDurationMonths * monthSeconds;

        // Calculate paymentPerSecond
        UD60x18 paymentPerSecond = calculatePaymentPerSecond(principal, ratePerSecond, maxDurationSeconds);
        require(paymentPerSecond.gt(convert(uint(0))), "paymentPerSecond must be > 0");

        // Calculate maxCost
        // uint maxCost = convert(paymentPerSecond.mul(convert(maxDurationSeconds)));
        // assert(maxCost > principal);

        // Calculate maxUnpaidInterest
        // uint maxUnpaidInterest = maxCost - principal;
        
        // Store new Loan
        _loans[tokenId] = Loan({
            owner: newOwner,
            ratePerSecond: ratePerSecond,
            paymentPerSecond: paymentPerSecond,
            startTime: block.timestamp,
            unpaidPrincipal: principal,
            // maxUnpaidInterest: maxUnpaidInterest,
            maxDurationSeconds: maxDurationSeconds,
            lastPaymentTime: block.timestamp // Note: no payment here, but needed so lastPaymentElapsedSeconds only counts from now
        });

        // Update pool
        totalPrincipal += principal;
        // maxTotalUnpaidInterest += maxUnpaidInterest;
        assert(totalPrincipal <= totalDeposits);

        emit StartLoan(newOwner, tokenId, principal, maxDurationMonths, ratePerSecond, maxDurationSeconds, paymentPerSecond, /*maxCost,*/ block.timestamp);
    }
}