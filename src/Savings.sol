// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
type eResidencyId is uint256;

contract Savings {

    mapping(eResidencyId => address) public borrowers;
    mapping(address => uint) public supplied;

    IERC20 DAI;
    address prospera;
    uint totalSupplied;
    uint totalLoaned;

    using SafeERC20 for IERC20;

    function utilization() private view returns(uint) {
        return totalLoaned / totalSupplied;
    }

    // this might be wrong.
    // due to interest, suppliers will withdraw more than they initially supply.
    // totalSupplied might underflow
    function availableToBorrow() private view returns (uint) {
        totalSupplied - totalLoaned;
    }

    // called by supplier
    function supply(uint deposit) external {

        // Pull deposit from supplier
        DAI.safeTransferFrom(msg.sender, address(this), deposit);

        // Increase caller supplied // should I use receipt tokens instead to reward early suppliers?
        supplied[msg.sender] += deposit;

        // Increase totalSupplied
        totalSupplied += deposit;
    }

    // called by supplier
    function withdraw(uint withdrawal) external {

        // Decrease totalSupplied
        totalSupplied -= withdrawal;
    }

    // called by GSP
    function mint(eResidencyId propertyOwner, bytes calldata propertyInfo) external onlyProspera {
        
    }

    function takeoutLoan() external {

    }

    function repay() external {

    }

    modifier onlyProspera {
        require(msg.sender == prospera, "caller not prospera");
        _;
    }
}