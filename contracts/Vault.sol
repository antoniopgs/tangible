// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// Inheritance
import "../interfaces/IVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Other
import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";

contract Vault is IVault, ERC20, Ownable(msg.sender) {

    // Links
    IERC20 immutable UNDERLYING;

    // Debt
    uint public totalPrincipal;

    // Eligibility
    mapping(address user => bool eligible) public userEligible; // Note: Can avoid SEC Regulations by banning Americans

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {

    }

    function deposit(uint underlying) external {

        // Calulate caller shares
        uint shares = underlyingToShares(underlying);
        
        // Pull underlying from caller
        UNDERLYING.safeTransferFrom(msg.sender, address(this), underlying); // Note: must come after underlyingToShares()

        // Mint shares to caller
        _mint(msg.sender, shares);

        // Log
        emit Deposit(msg.sender, underlying, shares);
    }

    function withdraw(uint underlying) external {
        require(underlying <= availableLiquidity(), "not enough available liquidity");

        // Calulate caller shares
        uint shares = underlyingToShares(underlying);

        // Burn caller shares
        _burn(msg.sender, shares);

        // Send underlying to caller
        UNDERLYING.safeTransfer(msg.sender, underlying); // Note: must come after underlyingToShares
        
        // Log
        emit Withdraw(msg.sender, underlying, shares);
    }

    function utilization() public view returns(UD60x18) {

        // Get underlyingBalance
        uint underlyingBalance = UNDERLYING.balanceOf(address(this));

        if (underlyingBalance == 0) {
            assert(totalPrincipal == 0);
            return convert(uint(0));
        }
        return convert(totalPrincipal).div(convert(underlyingBalance));
    }

    // Todo: implement ERC4626 vault to mitigate inflation attack?
    function underlyingToShares(uint underlying) public view returns(uint shares) {
        
        // Get supply
        uint supply = totalSupply();

        // Get underlyingBalance
        uint underlyingBalance = UNDERLYING.balanceOf(address(this));

        // If supply or underlyingBalance = 0, 1:1
        if (supply == 0 || underlyingBalance == 0) {
            shares = underlying * 1e12; // Note: Pool has 12 more decimals than UNDERLYING

        } else {
            shares = underlying * supply / underlyingBalance; // Note: multiplying by supply removes need to add 12 decimals
        }
    }

    function _update(address from, address to, uint256 value) internal override {
        require(userEligible[to] || to == address(0), "receiver not eligible");
        super._update(from, to, value);
    }

    function updateUserEligible(address user, bool eligible) external onlyOwner {
        userEligible[user] = eligible;
    }

    function availableLiquidity() public view returns(uint) {
        return UNDERLYING.balanceOf(address(this)) - totalPrincipal; // - protocolMoney?
    }

    function payDebt(uint repayment, uint interest) external { // Note: should I restrict access?

        // Update state
        totalPrincipal -= repayment;
        totalDeposits += interest;

        // Pull underlying
        UNDERLYING.safeTransferFrom(msg.sender, address(this), repayment + interest);
    }
}