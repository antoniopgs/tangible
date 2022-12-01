// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

contract Math2 {

    uint totalDebt;
    uint totalSupply;

    function utilization() private view returns (uint) {
        return totalDebt / totalSupply;
    }

    function interestRate() private view returns(uint) {
        // uses utilization()
    }

    function deposit(uint _deposit) external {
        totalSupply += _deposit;
    }

    function withdraw(uint _withdrawal) external {
        totalSupply -= _withdrawal;
    }

    function borrow(uint _principal) external {
        totalDebt += _principal * (1 + interestRate());
        totalSupply += _principal * (1 + interestRate());
    }

    function repay(uint _repayment) external {
        totalDebt -= _repayment;
    }
}