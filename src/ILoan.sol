// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "lib/prb-math/contracts/PRBMathUD60x18Typed.sol";

interface ILoan {

    struct Loan {
        PRBMath.UD60x18 propertyValue;
        PRBMath.UD60x18 monthlyRate;
        PRBMath.UD60x18 monthlyPayment;
        PRBMath.UD60x18 balance;
        address borrower;
    }    
}
