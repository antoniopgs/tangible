// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IBorrowing.sol";
import "../state/status/Status.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interest/IInterest.sol";

import "forge-std/console.sol";

contract Borrowing is IBorrowing, Status {

    // Libs
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    // Functions
    function startNewLoan(address buyer, uint tokenId, uint propertyValue, uint downPayment, uint maxDurationMonths) external onlyOwner {

        // Get loan
        Loan memory loan = _loans[tokenId];

        // If NFT is ResidentOwned
        if (status(tokenId) == Status.ResidentOwned) {
            
            // Get nftOwner
            address nftOwner = prosperaNftContract.ownerOf(tokenId);

            // Pull NFT from nftOwner to protocol
            prosperaNftContract.safeTransferFrom(nftOwner, address(this), tokenId); // Note: don't use loan.owner (it doesn't get cleared-out anymore, but NFT could have been transferred)

            // Add tokenId to loansTokenIds
            loansTokenIds.add(tokenId);

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
            downPayment: downPayment,
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
        if (status(tokenId) == Status.Default || status(tokenId) == Status.Foreclosurable) {
            saleFeeSpread = saleFeeSpread.add(_defaultFeeSpread); // Question: maybe defaultFee should be a boost appplied to interest instead?
        }
        uint saleFee = convert(convert(propertyValue).mul(saleFeeSpread)); // Question: should this be off propertyValue, or defaulterDebt?
        protocolMoney += saleFee;

        // 4. Pay oldOwner his equity (loan.owner)
        uint debt = unpaidPrincipal + interest + saleFee;
        require(propertyValue >= debt, "propertyValue must cover debt");
        USDC.safeTransfer(oldOwner, propertyValue - debt); //// DONT FORGET THIS!!!
    }

    function _startNewMortgage(
        address newOwner,
        uint tokenId,
        uint downPayment,
        uint principal,
        uint maxDurationMonths
    ) private {

        // Pull downPayment from newOwner
        USDC.safeTransferFrom(newOwner, address(this), downPayment);

        // Get ratePerSecond
        (bool success, bytes memory data) = logicTargets[IInterest.borrowerRatePerSecond.selector].call(
            abi.encodeCall(
                IInterest.borrowerRatePerSecond,
                (utilization())
            )
        );
        require(success, "couldn't get borrowerRatePerSecond");
        UD60x18 ratePerSecond = abi.decode(data, (UD60x18));

        // Calculate maxDurationSeconds
        uint maxDurationSeconds = maxDurationMonths * monthSeconds;

        // Calculate paymentPerSecond
        UD60x18 paymentPerSecond = calculatePaymentPerSecond(principal, ratePerSecond, maxDurationSeconds);
        assert(paymentPerSecond.gt(convert(uint(0))));

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

    function payLoan(uint tokenId, uint payment) external {
        require(status(tokenId) == Status.Mortgage, "nft has no active mortgage");

        // Get Loan
        Loan storage loan = _loans[tokenId];

        // Calculate interest
        uint interest = _accruedInterest(loan);

        //require(payment <= loan.unpaidPrincipal + interest, "payment must be <= unpaidPrincipal + interest");
        //require(payment => interest, "payment must be => interest"); // Question: maybe don't calculate repayment if payment < interest?

        // Bound payment
        if (payment > loan.unpaidPrincipal + interest) {
            payment = loan.unpaidPrincipal + interest;
        }

        // Pull payment from msg.sender
        USDC.safeTransferFrom(msg.sender, address(this), payment);

        // Calculate repayment
        uint repayment = payment - interest; // Todo: Add payLoanFee // Question: should payLoanFee come off the interest to lenders? Or only come off the borrower's repayment?

        // Update loan
        loan.unpaidPrincipal -= repayment;
        // loan.maxUnpaidInterest -= interest;
        loan.lastPaymentTime = block.timestamp;

        // Protocol charges interestFee
        uint interestFee = convert(convert(interest).mul(_interestFeeSpread));
        protocolMoney += interestFee;

        // Update pool
        totalPrincipal -= repayment;
        totalDeposits += interest - interestFee;
        // maxTotalUnpaidInterest -= interest;

        // If loan is paid off
        if (loan.unpaidPrincipal == 0) {
            
            // Release NFT
            releaseNft(tokenId);
        }

        emit PayLoan(msg.sender, tokenId, payment, interest, repayment, block.timestamp, loan.unpaidPrincipal == 0);
    }

    function redeemLoan(uint tokenId) external {
        require(status(tokenId) == Status.Default, "no default");

        // Get Loan
        Loan memory loan = _loans[tokenId];

        // Calculate interest
        uint interest = _accruedInterest(loan);

        // Calculate defaulterDebt & redemptionFee
        uint defaulterDebt = loan.unpaidPrincipal + interest;
        uint redemptionFee = convert(convert(defaulterDebt).mul(_redemptionFeeSpread));

        // Redeem (pull defaulter's entire debt + redemptionFee)
        USDC.safeTransferFrom(msg.sender, address(this), defaulterDebt + redemptionFee); // Note: anyone can redeem on behalf of defaulter // Question: actually, shouldn't the defaulter be the only one able to redeem?

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;
        // assert(interest <= loan.maxUnpaidInterest); // Note: actually, if borrower defaults, can't he pay more interest than loan.maxUnpaidInterest? // Note: actually, now that he only has redemptionWindow to redeem, maybe I can bring this assertion back
        //  -= loan.maxUnpaidInterest; // Note: maxTotalUnpaidInterest -= accruedInterest + any remaining unpaid interest (so can use loan.maxUnpaidInterest)

        // Release NFT
        releaseNft(tokenId);

        emit RedeemLoan(msg.sender, tokenId, interest, defaulterDebt, redemptionFee, block.timestamp);
    }

    function calculatePaymentPerSecond(uint principal, UD60x18 ratePerSecond, uint maxDurationSeconds) /*private*/ public pure returns(UD60x18 paymentPerSecond) {

        // Calculate x
        // - (1 + ratePerSecond) ** maxDurationSeconds <= MAX_UD60x18
        // - (1 + ratePerSecond) ** (maxDurationMonths * monthSeconds) <= MAX_UD60x18
        // - maxDurationMonths * monthSeconds <= log_(1 + ratePerSecond)_MAX_UD60x18
        // - maxDurationMonths * monthSeconds <= log(MAX_UD60x18) / log(1 + ratePerSecond)
        // - maxDurationMonths <= (log(MAX_UD60x18) / log(1 + ratePerSecond)) / monthSeconds // Note: ratePerSecond depends on util (so solve for maxDurationMonths)
        // - maxDurationMonths <= log(MAX_UD60x18) / (monthSeconds * log(1 + ratePerSecond))
        UD60x18 x = convert(uint(1)).add(ratePerSecond).powu(maxDurationSeconds);

        // principal * ratePerSecond * x <= MAX_UD60x18
        // principal * ratePerSecond * (1 + ratePerSecond) ** maxDurationSeconds <= MAX_UD60x18
        // principal * ratePerSecond * (1 + ratePerSecond) ** (maxDurationMonths * monthSeconds) <= MAX_UD60x18
        // (1 + ratePerSecond) ** (maxDurationMonths * monthSeconds) <= MAX_UD60x18 / (principal * ratePerSecond)
        // maxDurationMonths * monthSeconds <= log_(1 + ratePerSecond)_(MAX_UD60x18 / (principal * ratePerSecond))
        // maxDurationMonths * monthSeconds <= log(MAX_UD60x18 / (principal * ratePerSecond)) / log(1 + ratePerSecond)
        // maxDurationMonths <= (log(MAX_UD60x18 / (principal * ratePerSecond)) / log(1 + ratePerSecond)) / monthSeconds
        // maxDurationMonths <= log(MAX_UD60x18 / (principal * ratePerSecond)) / (monthSeconds * log(1 + ratePerSecond))
        
        // Calculate paymentPerSecond
        paymentPerSecond = convert(principal).mul(ratePerSecond).mul(x).div(x.sub(convert(uint(1))));
    }

    function utilization() public view returns(UD60x18) {
        if (totalDeposits == 0) {
            assert(totalPrincipal == 0);
            return convert(uint(0));
        }
        return convert(totalPrincipal).div(convert(totalDeposits));
    }

    function releaseNft(uint tokenId) private { // Todo: move to Borrowing

        // Send NFT to loan.owner
        prosperaNftContract.safeTransferFrom(address(this), _loans[tokenId].owner, tokenId);

        // Remove tokenId from loansTokenIds
        loansTokenIds.remove(tokenId);
    }
}