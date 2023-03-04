// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IPool.sol";
import "../types/PropertySet.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777.sol";

contract Pool is IPool {

    // Links
    IERC777 tUSDC;

    // Math Vars
    UD60x18 internal totalBorrowed;
    UD60x18 internal totalDeposits;

    // Properties storage
    PropertySet.Set internal properties;

    function utilization() public view returns (UD60x18) {
        return totalBorrowed.div(totalDeposits);
    }

    function availableLiquidity() external view returns(uint) {
        return fromUD60x18(totalDeposits.sub(totalBorrowed));
    }

    function usdcToTusdcRatio() private view returns(UD60x18) {
        
        // Get tusdcSupply
        uint tusdcSupply = tUSDC.totalSupply();

        if (tusdcSupply == 0 || totalDeposits.eq(ud(0))) {
            return toUD60x18(1);

        } else {
            return toUD60x18(tusdcSupply).div(totalDeposits);
        }
    }

    function usdcToTusdc(uint usdc) internal view returns(uint tusdc) {
        tusdc = fromUD60x18(toUD60x18(usdc).mul(usdcToTusdcRatio()));
    }

    function lenderApy() external view returns (UD60x18) {
        // return perfectLenderApy.mul(utilization());
    }

    function propertiesLength() external view returns(uint) {
        return properties.length();
    }

    function propertyAt(idx _idx) external returns(Property memory property) {
        return properties.at(_idx);
    }
}
