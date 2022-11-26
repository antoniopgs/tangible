// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
type eResidencyId is uint256;

contract Savings {

    IERC20 DAI;
    address prospera;

    mapping(eResidencyId => address) public borrowers;
    mapping(address => uint) public supplied;

    using SafeERC20 for IERC20;

    // called by supplier
    function supply(uint deposit) external {

        // Pull deposit from supplier
        DAI.safeTransferFrom(msg.sender, address(this), deposit);

        // Increment caller supplied // should I use receipt tokens instead to reward early suppliers?
        supplied[msg.sender] += deposit;
    }

    // called by supplier
    function withdraw() external {

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