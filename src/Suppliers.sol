// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Suppliers is Math {

    mapping(address => PRBMath.UD60x18) public supplied;

    IERC20 DAI;

    using SafeERC20 for IERC20;
    using PRBMathUD60x18Typed for PRBMath.UD60x18;

    // called by supplier
    function supply(PRBMath.UD60x18 memory deposit) external {

        // Pull deposit from supplier to protocol
        DAI.safeTransferFrom(msg.sender, address(this), deposit.toUint());

        // Increase caller supplied // should I use receipt tokens instead to reward early suppliers?
        supplied[msg.sender] = supplied[msg.sender].add(deposit);

        // Increase totalSupplied
        totalSupplied = totalSupplied.add(deposit);
    }

    // called by supplier
    function withdraw(PRBMath.UD60x18 memory withdrawal) external {

        // Decrease caller supplied // should I use receipt tokens instead to reward early suppliers?
        supplied[msg.sender] = supplied[msg.sender].sub(withdrawal);

        // Decrease totalSupplied
        totalSupplied = totalSupplied.sub(withdrawal);

        // Pull deposit from protocol to supplier
        DAI.safeTransfer(msg.sender, withdrawal.toUint());
    }
}