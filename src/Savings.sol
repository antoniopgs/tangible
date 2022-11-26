// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Math.sol";
type eResidencyId is uint256;

contract Savings is Math {

    mapping(eResidencyId => address) public borrowers;
    mapping(address => PRBMath.UD60x18) public supplied;

    IERC20 DAI;
    address prospera;

    using SafeERC20 for IERC20;
    using PRBMathUD60x18Typed for PRBMath.UD60x18;

    // called by supplier
    function supply(PRBMath.UD60x18 memory deposit) external {

        // Pull deposit from supplier
        DAI.safeTransferFrom(msg.sender, address(this), deposit.toUint());

        // Increase caller supplied // should I use receipt tokens instead to reward early suppliers?
        supplied[msg.sender] = supplied[msg.sender].add(deposit);

        // Increase totalSupplied
        totalSupplied = totalSupplied.add(deposit);
    }

    // called by supplier
    function withdraw(PRBMath.UD60x18 memory withdrawal) external {

        // Decrease totalSupplied
        totalSupplied = totalSupplied.sub(withdrawal);
    }

    // called by GSP
    function mint(eResidencyId propertyOwner, bytes calldata propertyInfo) external onlyProspera {
        
    }

    modifier onlyProspera {
        require(msg.sender == prospera, "caller not prospera");
        _;
    }
}