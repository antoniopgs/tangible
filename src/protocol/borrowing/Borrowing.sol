// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IBorrowing.sol";
import "../state/state/State.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interest/IInterest.sol";

import "forge-std/console.sol";

contract Borrowing is IBorrowing, State {

    // Libs
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    // Functions
    function startLoan(TokenId tokenId, uint propertyValue, uint downPayment, address borrower) external {
        console.log("s1");
        console.log("msg.sender:", msg.sender);
        console.log("address(this):", address(this));
        require(msg.sender == address(this), "unauthorized"); // Note: msg.sender must be address(this) because this will be called via delegatecall
        console.log("s2");

        // Get Loan
        Loan storage loan = _loans[tokenId];

        // Ensure property has no associated loan
        require(status(loan) == Status.None, "property already has associated loan");

        // Calculate principal
        uint principal = propertyValue - downPayment;

        // Calculate bid ltv
        UD60x18 ltv = toUD60x18(principal).div(toUD60x18(propertyValue));

        // Ensure ltv <= maxLtv
        require(ltv.lte(maxLtv), "ltv can't exceeed maxLtv");

        // Add principal to totalPrincipal
        totalPrincipal += principal;
        
        // Ensure utilization <= utilizationCap
        require(utilization().lte(utilizationCap), "utilization can't exceed utilizationCap");

        // Calculate & decode periodRate
        (bool success, bytes memory data) = logicTargets[IInterest.calculatePeriodRate.selector].delegatecall(
            abi.encodeCall(
                IInterest.calculatePeriodRate,
                (utilization())
            )
        );
        require(success, "calculateYearlyBorrowerRate delegateCall failed");
        UD60x18 periodRate = abi.decode(data, (UD60x18));

        // Calculate installment
        uint installment = calculateInstallment(periodRate, principal);

        // Calculate totalLoanCost
        uint totalLoanCost = installment * installmentCount;

        // Store Loan
        _loans[tokenId] = Loan({
            borrower: borrower,
            balance: principal,
            periodicRate: periodRate,
            installment: installment,
            unpaidInterest: totalLoanCost - principal,
            nextPaymentDeadline: block.timestamp + periodDuration
        });

        // Add tokenId to loansTokenIds
        loansTokenIds.add(TokenId.unwrap(tokenId));

        // Pull downPayment from borrower
        USDC.safeTransferFrom(borrower, address(this), downPayment);
    }
    
    function payLoan(TokenId tokenId) external {

        // Load loan
        Loan storage loan = _loans[tokenId];

        // Ensure caller is borrower
        require(msg.sender == loan.borrower, "only borrower can pay his loan");

        // Ensure property has active mortgage
        require(status(loan) == Status.Mortgage, "property has no active mortgage");

        // Pull installment from borrower
        USDC.safeTransferFrom(loan.borrower, address(this), loan.installment);

        // Calculate interest
        uint interest = fromUD60x18(loan.periodicRate.mul(toUD60x18(loan.balance)));

        // Calculate repayment
        uint repayment = loan.installment - interest;

        // Clamp repayment // Question: will this mess up APY?
        if (repayment > loan.balance) {
            repayment = loan.balance;
        }

        // Remove repayment from loan.balance & totalPrincipal
        loan.balance -= repayment;
        totalPrincipal -= repayment;

        // Clamp interest // Question: will this mess up APY?
        if (interest > loan.unpaidInterest) {
            interest = loan.unpaidInterest;
        }

        // Add interest to deposits
        totalDeposits += interest;

        // Remove interest from loan.unpaidInterest
        loan.unpaidInterest -= interest;

        // If loan completely paid off
        bool loanPaid = loan.balance == 0;
        if (loanPaid) {

            // Send Nft
            sendNft(loan, loan.borrower, TokenId.unwrap(tokenId));

        // If more payments are needed to pay off loan
        } else {

            // Update loan.nextPaymentDeadline
            loan.nextPaymentDeadline += periodDuration;
        }
    }

    function redeemLoan(TokenId tokenId) external {
        
        // Get loan
        Loan storage loan = _loans[tokenId];

        // Ensure caller is borrower
        require(msg.sender == loan.borrower, "only borrower can pay his loan");

        // Ensure borrower has defaulted
        require(status(loan) == Status.Default, "no default");

        // Ensure redemptionWindow has passed
        require(block.timestamp >= loan.nextPaymentDeadline + redemptionWindow);

        // Calculate defaulterDebt
        uint defaulterDebt = loan.balance + loan.unpaidInterest; // should redeemer pay all the interest? or only the interest until redemption time?

        // Redeem (pull defaulter's entire debt)
        USDC.safeTransferFrom(loan.borrower, address(this), defaulterDebt);

        // Remove loan.balance from loan.balance & totalPrincipal
        loan.balance = 0;
        totalPrincipal -= loan.balance;

        // Add unpaidInterest to totalDeposits
        totalDeposits += loan.unpaidInterest;

        // Send Nft to borrower
        sendNft(loan, loan.borrower, TokenId.unwrap(tokenId));
    }

    function forecloseLoan(TokenId tokenId, uint bidIdx) external { // Note: bidders can call this with idx of their bid. shoudn't be a problem

        // Get Loan
        Loan storage loan = _loans[tokenId];

        // Ensure borrower has defaulted
        require(status(loan) == Status.Foreclosurable, "no default");

        // Get Bid
        Bid memory bid = _bids[tokenId][bidIdx];

        // Calculate defaulterDebt
        uint defaulterDebt = loan.balance + loan.unpaidInterest; // Todo: fix defaulterDebt (and in other places too)

        require(bid.propertyValue >= defaulterDebt, "bid.propertyValue doesn't cover defaulterDebt + fees"); // Todo: add fees later

        // Remove loan.balance from loan.balance & totalPrincipal
        loan.balance -= 0;
        totalPrincipal -= loan.balance;

        // Add unpaidInterest to totalDeposits
        totalDeposits += loan.unpaidInterest;

        // Todo: Add Sale fee

        // Calculate defaulterEquity
        uint defaulterEquity = bid.propertyValue - defaulterDebt;

        // Calculate foreclosureFee
        uint foreclosureFee = fromUD60x18(foreclosureFeeRatio.mul(toUD60x18(defaulterEquity)));
        // UD60x18 foreclosureFee = foreclosureFeeRatio.mul(loan.salePrice); // shouldn't the ratio be applied to the salePrice?

        // Calculate foreclosurerCut
        uint foreclosurerCut = fromUD60x18(foreclosurerCutRatio.mul(toUD60x18(foreclosureFee)));

        // Calculate protocolCut
        uint protocolCut = foreclosureFee - foreclosurerCut;

        // Calculate leftover
        uint leftover = defaulterEquity - foreclosureFee;

        // Send foreclosurerCut to foreclosurer/caller
        USDC.safeTransferFrom(address(this), msg.sender, foreclosurerCut);

        // Add protocolCut to protocolMoney
        protocolMoney += protocolCut;

        // Send leftover to defaulter
        USDC.safeTransferFrom(address(this), loan.borrower, leftover);

        // Send Nft to highestBidder
        address highestBidder;
        sendNft(loan, highestBidder, TokenId.unwrap(tokenId));
    }

    // Util Functions
    function calculateInstallment(UD60x18 periodicBorrowerRate, uint principal) private pure returns(uint installment) {

        // Calculate x
        UD60x18 x = toUD60x18(1).add(periodicBorrowerRate).pow(toUD60x18(installmentCount));
        
        // Calculate installment
        installment = fromUD60x18(toUD60x18(principal).mul(periodicBorrowerRate).mul(x).div(x.sub(toUD60x18(1))));
    }

    // Views
    function utilization() public view returns (UD60x18) {
        return toUD60x18(totalPrincipal).div(toUD60x18(totalDeposits));
    }
}
