// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IAuctions.sol";
import "../state/status/Status.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../borrowing/borrowing/IBorrowing.sol";
import { convert } from "@prb/math/src/UD60x18.sol";

contract AcceptNone is Status {

    using SafeERC20 for IERC20;

    function acceptNoneBid(uint tokenId, uint bidIdx) external {

        // Get nftOwner
        address nftOwner = prosperaNftContract.ownerOf(tokenId);
        
        require(status(tokenId) == Status.None, "status not none"); // Question: maybe remove this? (since it's checked in acceptBid() and this function is private?)
        require(msg.sender == nftOwner, "caller not nftOwner");

        // Get bid
        Bid memory _bid = _bids[tokenId][bidIdx];

        // Calculate fees
        uint saleFee = convert(convert(_bid.propertyValue).mul(_saleFeeSpread));

        // Protocol takes fees
        protocolMoney += saleFee;

        // Ensure propertyValue covers saleFee
        require(_bid.propertyValue >= saleFee, "propertyValue doesn't cover saleFee"); // Question: interest will rise over time. Too risky?

        // Calculate equity
        uint equity = _bid.propertyValue - saleFee;

        // Send equity to nftOwner
        USDC.safeTransfer(nftOwner, equity);

        // If bid
        if (_bid.propertyValue == _bid.downPayment) {
            
            // Send NFT from nftOwner to bidder
            prosperaNftContract.safeTransferFrom(nftOwner, _bid.bidder, tokenId);

        // If loan bid
        } else {

            // Pull NFT from nftOwner to protocol
            prosperaNftContract.safeTransferFrom(nftOwner, address(this), tokenId);

            // Calculate principal
            uint principal = _bid.propertyValue - _bid.downPayment;

            // start new loan
            (bool success, ) = logicTargets[IBorrowing.startLoan.selector].delegatecall(
                abi.encodeCall(
                    IBorrowing.startLoan,
                    (_bid.bidder, tokenId, principal, _bid.maxDurationMonths)
                )
            );
            require(success, "startLoan delegateCall failed");
        }
    }
}