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
    function startLoan(
        address seller,
        address newOwner,
        uint tokenId,
        uint propertyValue,
        uint downPayment,
        uint maxDurationMonths
    ) external onlyOwner {

        // Get loan
        Loan memory loan = _loans[tokenId];

        // Get unpaidPrincipal
        uint unpaidPrincipal = loan.unpaidPrincipal;
        
        // Calculate interest
        uint interest = _accruedInterest(tokenId);

        // 1. If oldOwner has debt, Pay Money Pool/Lenders
        if (unpaidPrincipal > 0) {
            totalPrincipal -= unpaidPrincipal;
            totalDeposits += interest;
            // maxTotalUnpaidInterest -= interest;
        }

        // 2. Protocol charges Sale Fee
        uint saleFee = convert(convert(propertyValue).mul(_saleFeeSpread)); // Question: should this be off propertyValue, or defaulterDebt?
        protocolMoney += saleFee;

        // 3. Protocol charges Default Fee (if needed)
        uint defaultFee;
        if (status(tokenId) == Status.Default || status(tokenId) == Status.Foreclosurable) {
            defaultFee = convert(convert(propertyValue).mul(_defaultFeeSpread)); // Question: should this be off propertyValue, or defaulterDebt?
            protocolMoney += defaultFee;
        }

        // 4. Pay oldOwner (loan.owner)
        uint debt = unpaidPrincipal + interest + saleFee + defaultFee;
        require(propertyValue >= debt, "propertyValue must cover debt");
        uint oldOwnerCut = propertyValue - debt;

        if (loan.owner == address(0)) {
            USDC.safeTransfer(seller, oldOwnerCut);
        } else {
            USDC.safeTransfer(loan.owner, oldOwnerCut);
        }

        // 5. Start Mortgage
        _startMortgage({
            newOwner: newOwner,
            downPayment: downPayment,
            tokenId: tokenId,
            principal: propertyValue - downPayment,
            maxDurationMonths: maxDurationMonths
        });
    }

    function _startMortgage(
        address newOwner,
        uint downPayment,
        uint tokenId,
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
        uint maxCost = convert(paymentPerSecond.mul(convert(maxDurationSeconds)));
        assert(maxCost > principal);

        // Calculate maxUnpaidInterest
        // uint maxUnpaidInterest = maxCost - principal;
        
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

        // Add tokenId to loansTokenIds
        loansTokenIds.add(tokenId);

        emit StartLoan(newOwner, tokenId, principal, maxDurationMonths, ratePerSecond, maxDurationSeconds, paymentPerSecond, maxCost, block.timestamp);

    }

    function payLoan(uint tokenId, uint payment) external {
        require(status(tokenId) == Status.Mortgage, "nft has no active mortgage");

        // Calculate interest
        uint interest = _accruedInterest(tokenId);

        //require(payment <= loan.unpaidPrincipal + interest, "payment must be <= unpaidPrincipal + interest");
        //require(payment => interest, "payment must be => interest"); // Question: maybe don't calculate repayment if payment < interest?

        // Get Loan
        Loan storage loan = _loans[tokenId];

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
        uint interestFee = interest.mul(_interestFeeSpread);
        protocolMoney += interestFee;

        // Update pool
        totalPrincipal -= repayment;
        totalDeposits += interest - interestFee;
        // maxTotalUnpaidInterest -= interest;

        emit PayLoan(msg.sender, tokenId, payment, interest, repayment, block.timestamp, loan.unpaidPrincipal == 0);
    }

    function redeemLoan(uint tokenId) external {
        require(status(tokenId) == Status.Default, "no default");

        // Get Loan
        Loan storage loan = _loans[tokenId];

        // Calculate interest
        uint interest = _accruedInterest(tokenId);

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
}