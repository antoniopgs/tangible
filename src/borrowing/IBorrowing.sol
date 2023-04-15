// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/IState.sol";

interface IBorrowing is IState {

    // Functions
    function startLoan(uint tokenId, uint principal, /* uint borrowerAprPct, */ uint maxDurationMonths) external;
    function payLoan(uint tokenId, uint payment) external;
    function redeem(uint tokenId) external;
    function foreclose(uint tokenId, uint salePrice) external;

    // Views
    function borrowerApr() public view returns(UD60x18 apr);
    function lenderApy() public view returns(UD60x18);
    function principalCap(Loan memory loan, uint month) public pure returns(uint cap);
    function state(uint tokenId) public view returns (Status);
    function utilization() public view returns(UD60x18);
    function availableLiquidity() /* private */ public view returns(uint);
}