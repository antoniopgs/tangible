// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IAuctions.sol";
import "../state/state/State.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../borrowing/IBorrowing.sol";

contract Auctions is IAuctions, State {

    using SafeERC20 for IERC20;

    function bid(TokenId tokenId, UD60x18 propertyValue, UD60x18 downPayment) external {

        // Calculate bid ltv
        UD60x18 ltv = toUD60x18(1).sub(downPayment.div(propertyValue));

        // Ensure bid ltv <= maxLtv
        require(ltv.lte(maxLtv), "ltv cannot exceed maxLtv");

        // Todo: Ensure tokenId exists?

        // Pull downPayment from caller to protocol
        USDC.safeTransferFrom(msg.sender, address(this), fromUD60x18(downPayment));

        // Add bid to tokenId bids
        bids[tokenId].push(
            Bid({
                bidder: msg.sender,
                propertyValue: propertyValue,
                downPayment: downPayment
            })
        );
    }

    function cancelBid(TokenId tokenId, Idx bidIdx) external {

        // Todo: Ensure tokenId exists?

        // Get propertyBids
        Bid[] storage propertyBids = bids[tokenId];

        // Get bidToRemove
        Bid memory bidToRemove = propertyBids[Idx.unwrap(bidIdx)];

        // Ensure caller is bidder
        require(msg.sender == bidToRemove.bidder, "only bidder can remove his bid");

        // Get last propertyLastBid
        Bid memory propertyLastBid = propertyBids[propertyBids.length - 1];

        // Write propertyLastBid over bidToRemove
        propertyBids[Idx.unwrap(bidIdx)] = propertyLastBid;

        // Remove lastPropertyBid
        propertyBids.pop();

        // Send bidToRemove's downPayment from protocol to bidder
        USDC.safeTransferFrom(address(this), bidToRemove.bidder, fromUD60x18(bidToRemove.downPayment));
    }

    function acceptBid(TokenId tokenId, Idx bidIdx) external {

        // Get nftOwner
        address nftOwner = prosperaNftContract.ownerOf(TokenId.unwrap(tokenId));

        // Ensure caller is nft owner
        require(msg.sender == nftOwner, "only nft owner can accept bids");

        // Get bid
        Bid memory _bid = bids[tokenId][Idx.unwrap(bidIdx)];

        // Todo: if State == Null vs if State == Mortgage

        // Calculate saleFee
        UD60x18 saleFee = _bid.propertyValue.mul(saleFeeRatio);

        // Add saleFee to protocolMoney
        protocolMoney = protocolMoney.add(saleFee);

        // Send (bid.propertyValue - saleFee) to nftOwner
        USDC.safeTransferFrom(address(this), nftOwner, fromUD60x18(_bid.propertyValue.sub(saleFee)));

        // If regular bid
        if (_bid.downPayment.eq(_bid.propertyValue)) {

            // Send NFT from protocol to bidder
            prosperaNftContract.safeTransferFrom(address(this), _bid.bidder, TokenId.unwrap(tokenId)); // Note: NFT COMES LATER
        
        // If loan bid
        } else {

            // Ensure loan bid is actionable
            require(loanBidActionable(_bid), "loanBid not actionable");

            // Start Loan (via delegate call)
            (bool success, bytes memory data) = logicTargets[IBorrowing.startLoan.selector].delegatecall(
                abi.encodeCall(
                    IBorrowing.startLoan,
                    (tokenId, _bid.propertyValue, _bid.downPayment, _bid.bidder)
                )
            );
            require(success, "startLoan delegateCall failed");
            // Todo: return data
        }
    }

    function loanBidActionable(Bid memory _bid) public view returns(bool) {

        // Calculate loanBid principal
        UD60x18 principal = _bid.propertyValue.sub(_bid.downPayment);

        // Calculate loanBid ltv
        UD60x18 ltv = principal.div(_bid.propertyValue);

        // Return actionability
        return ltv.lte(maxLtv) && availableLiquidity().gte(principal);
    }

    function availableLiquidity() private view returns(UD60x18) {
        return totalDeposits.sub(totalBorrowed);
    }
}