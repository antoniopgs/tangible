// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IBorrowing.sol";
import "../../state/status/Status.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../interest/IInterest.sol";
import "../../auctions/IAuctions.sol";

abstract contract Borrowing is IBorrowing, Status {

    // Libs
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    // Functions
    function startLoan(address borrower, uint tokenId, uint principal, uint maxDurationMonths) external {
        require(prosperaNftContract.ownerOf(tokenId) == address(this), "unauthorized"); // Note: nft must be owned must be address(this) because this will be called via delegatecall // Todo: review safety of this require later
        // require(status(tokenId) == Status.None, "nft already in system"); // Note: THIS MIGHT NOT WORK

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
            borrower: borrower, // Note: must be called via delegatecall for this to work
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
    }

    function payLoan(uint tokenId, uint payment) external {
        require(status(tokenId) == Status.Mortgage, "nft has no active mortgage");

        // Calculate interest
        uint interest = accruedInterest(tokenId);

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

        // Update pool
        totalPrincipal -= repayment;
        totalDeposits += interest;
        // maxTotalUnpaidInterest -= interest;

        // If loan is paid off
        if (loan.unpaidPrincipal == 0) {
            
            // Send nft to loan.borrower
            sendNft(loan, loan.borrower, tokenId);
        }
    }

    function redeemLoan(uint tokenId) external {
        require(status(tokenId) == Status.Default, "no default");

        // Get Loan
        Loan storage loan = _loans[tokenId];

        // Calculate interest
        uint interest = accruedInterest(tokenId);

        // Calculate defaulterDebt & redemptionFee
        uint defaulterDebt = loan.unpaidPrincipal + interest;
        uint redemptionFee = convert(convert(defaulterDebt).mul(_redemptionFeeSpread));

        // Redeem (pull defaulter's entire debt + redemptionFee)
        USDC.safeTransferFrom(msg.sender, address(this), defaulterDebt + redemptionFee); // Note: anyone can redeem on behalf of defaulter

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;
        // assert(interest <= loan.maxUnpaidInterest); // Note: actually, if borrower defaults, can't he pay more interest than loan.maxUnpaidInterest? // Note: actually, now that he only has redemptionWindow to redeem, maybe I can bring this assertion back
        //  -= loan.maxUnpaidInterest; // Note: maxTotalUnpaidInterest -= accruedInterest + any remaining unpaid interest (so can use loan.maxUnpaidInterest)

        // Send nft to loan.borrower
        sendNft(loan, loan.borrower, tokenId);
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

    function lenderApy() public view returns(UD60x18) {
    //     if (totalDeposits == 0) {
    //         assert(maxTotalUnpaidInterest == 0);
    //         return convert(0);
    //     }
    //     return convert(maxTotalUnpaidInterest).div(convert(totalDeposits)); // Question: is this missing auto-compounding?
    }

    function sendNft(Loan storage loan, address receiver, uint tokenId) private { // Todo: move to Borrowing

        // Send Nft to receiver
        prosperaNftContract.safeTransferFrom(address(this), receiver, tokenId);

        // Reset loan state to Null (so it can re-enter system later)
        loan.borrower = address(0);

        // Remove tokenId from loansTokenIds
        loansTokenIds.remove(tokenId);
    }
}