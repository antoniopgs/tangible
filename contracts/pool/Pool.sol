// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./PoolLending.sol";
import "./PoolAuctions.sol";

contract Pool is PoolLending, PoolAuctions {

    constructor(string memory name_, string memory symbol_, IERC20 UNDERLYING_/* , address protocol_ */) ERC20(name_, symbol_) {
        UNDERLYING = UNDERLYING_;
        // protocol = protocol_;
        // UNDERLYING.approve(protocol, type(uint).max);
    }

    function deposit(uint underlying) external {
        _deposit(underlying);
    }

    function withdraw(uint underlying) external {
        _withdraw(underlying);
    }

    function bid(uint tokenId, uint propertyValue, uint downPayment, uint loanMonths) external {
        _bid(tokenId, propertyValue, downPayment, loanMonths);
    }

    function cancelBid(uint tokenId, uint idx) external {
        _cancelBid(tokenId, idx);
    }

    function depositAndBid() external {
        // _deposit();
        // _bid();
    }

    function cancelBidAndWithdraw(uint tokenId, uint idx) external {
        // _cancelBid(tokenId, idx);
        // _withdraw();
    }
}