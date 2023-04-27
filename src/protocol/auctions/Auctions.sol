// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IAuctions.sol";
import "../state/state/State.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../borrowing/IBorrowing.sol";
import { fromUD60x18 } from "@prb/math/UD60x18.sol";

contract Auctions is IAuctions, State {

    using SafeERC20 for IERC20;

    function bid(TokenId tokenId, uint propertyValue, uint downPayment) external {
        require(downPayment <= propertyValue, "downPayment cannot exceed propertyValue");

        // Calculate bid ltv
        UD60x18 ltv = toUD60x18(1).sub(toUD60x18(downPayment).div(toUD60x18(propertyValue)));

        // Ensure bid ltv <= maxLtv
        require(ltv.lte(maxLtv), "ltv cannot exceed maxLtv");

        // Todo: Ensure tokenId exists?

        // Pull downPayment from caller to protocol
        USDC.safeTransferFrom(msg.sender, address(this), downPayment);

        // Add bid to tokenId bids
        _bids[tokenId].push(
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
        Bid[] storage propertyBids = _bids[tokenId];

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
        USDC.safeTransfer(bidToRemove.bidder, bidToRemove.downPayment);
    }

    function acceptBid(TokenId tokenId, Idx bidIdx) external {

        // Get nftOwner
        address nftOwner = prosperaNftContract.ownerOf(TokenId.unwrap(tokenId));

        // Ensure caller is nft owner
        require(msg.sender == nftOwner, "only nft owner can accept bids");

        // Get bid
        Bid memory _bid = _bids[tokenId][Idx.unwrap(bidIdx)];

        // Todo: if State == Null vs if State == Mortgage

        // Calculate saleFee
        uint saleFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_saleFeeSpread));

        // Add saleFee to protocolMoney
        protocolMoney += saleFee;

        // Send (bid.propertyValue - saleFee) to nftOwner
        USDC.safeTransfer(nftOwner, _bid.propertyValue - saleFee);

        // If regular bid
        if (_bid.downPayment == _bid.propertyValue) {

            // Send NFT from nftOwner to bidder
            prosperaNftContract.safeTransferFrom(nftOwner, _bid.bidder, TokenId.unwrap(tokenId));
        
        // If loan bid
        } else {

            // Ensure loan bid is actionable
            require(loanBidActionable(_bid), "loanBid not actionable");

            // Pull NFT from nftOwner to protocol
            prosperaNftContract.safeTransferFrom(nftOwner, address(this), TokenId.unwrap(tokenId));

            // Start Loan (via delegate call)
            (bool success, ) = logicTargets[IBorrowing.startLoan.selector].delegatecall(
                abi.encodeCall(
                    IBorrowing.startLoan,
                    (tokenId, _bid.propertyValue, _bid.downPayment, _bid.bidder)
                )
            );
            require(success, "startLoan delegateCall failed");
        }
    }
}