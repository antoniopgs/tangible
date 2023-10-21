// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";
import "./Registry.sol";
import "../tokens/Shares.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// - auctions (where valuation depends on bid amounts and equity %s)?
contract Auctions {

    Registry registry;
    Shares sharesToken;
    IERC20 USDC;

    uint _maxLoanMonths = 10 * 12; // 10 years
    UD60x18 _maxLtv;

    struct Bid {
        address bidder;
        uint shares;
        uint propertyValue;
        uint downPayment;
        uint loanMonths;
    }

    mapping(uint => Bid[]) internal _bids; // Todo: figure out multiple bids by same bidder on same nft late

    // Question: what if nft has no debt? it could still use an auction mechanism, right? openSea could be used, but so could this...
    function bid(uint tokenId, uint shares, uint propertyValue, uint downPayment, uint loanMonths) external {
        require(exists(tokenId), "tokenId doesn't exist");
        require(registry.isResident(msg.sender), "only residents can bid"); // Note: shares transfer to non-resident bidder would fail anyways (but I think its best to avoid invalid bids for sellers)
        require(registry.isNotAmerican(msg.sender), "only non-americans can bid"); // Note: shares transfer to american bidder would fail anyways (but I think its best to avoid invalid bids for sellers)
        require(downPayment <= propertyValue, "downPayment cannot exceed propertyValue");
        require(loanMonths > 0 && loanMonths <= _maxLoanMonths, "unallowed loanMonths");

        // Validate ltv
        require(propertyValue > 0, "propertyValue must be > 0");
        UD60x18 ltv = convert(uint(1)).sub(convert(downPayment).div(convert(propertyValue)));
        require(ltv.lte(_maxLtv), "ltv cannot exceed maxLtv");

        // Validate minSalePrice
        require(propertyValue >= _minSalePrice(_debts[tokenId].loan), "propertyValue must cover minSalePrice");

        // Pull downPayment from bidder
        USDC.safeTransferFrom(msg.sender, address(this), downPayment);

        // Add bid to tokenId bids
        _bids[tokenId].push(
            Bid({
                bidder: msg.sender,
                propertyValue: propertyValue,
                downPayment: downPayment,
                loanMonths: loanMonths
            })
        );
    }
    
    function cancelBid(uint tokenId, uint idx) external {

    }

    function acceptBid(uint tokenId, uint idx) external {

    }

    function exists(uint id) public view virtual returns (bool) {
        return id < sharesToken.tokenCount();
    }
}