// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

type eResidencyId is uint256;

contract PoolRenting {

    struct Property {
        address nftContract;
        uint tokenId;
    }

    function supply() external {

    }

    // Only executable via dao proposal
    function buy(Property calldata property) private {
        
    }

    // Only executable via dao proposal
    function sell(Property calldata property) private {

    }

    // Called by tenant
    function payRent() external {

    }

    // should this be pull payment or xLiq type token accrual?
    // and does that have full reserve vs fractional reserve implications?
    function collect() external {

    }
}