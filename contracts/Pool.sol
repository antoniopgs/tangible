// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// Inheritance
import "../interfaces/IPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Other
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";

contract Pool is IPool, ERC20, Ownable(msg.sender) {

    IERC20 immutable UNDERLYING;
    address immutable protocol;

    uint public debt;
    uint public deposits;

    mapping(address user => bool eligible) public userEligible; // Note: Can avoid SEC Regulations by banning Americans

    using SafeERC20 for IERC20;

    constructor(string memory name_, string memory symbol_, IERC20 UNDERLYING_, address protocol_) ERC20(name_, symbol_) {
        UNDERLYING = UNDERLYING_;
        protocol = protocol_;
        UNDERLYING.approve(protocol, type(uint).max);
    }

    function deposit(uint underlying) external {

        // Calulate caller shares
        uint shares = underlyingToShares(underlying);

        // Update deposits
        deposits += underlying;
        
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

        // Update deposits
        deposits -= underlying;

        // Burn caller shares
        _burn(msg.sender, shares);

        // Send underlying to caller
        UNDERLYING.safeTransfer(msg.sender, underlying); // Note: must come after underlyingToShares
        
        // Log
        emit Withdraw(msg.sender, underlying, shares);
    }

    function utilization() public view returns(UD60x18) {
        if (deposits == 0) {
            assert(debt == 0);
            return convert(uint(0));
        }
        return convert(debt).div(convert(deposits));
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
        return deposits - debt;
    }

    // Note: should I restrict access?
    // Note: this probably introduces vulnerabilities
    function payDebt(address user, uint repayment, uint interest) external {

        // Update state
        debt -= repayment;
        deposits += interest;

        // Pull underlying
        UNDERLYING.safeTransferFrom(user, address(this), repayment + interest);
    }

    function fooBar(
        address seller,
        uint sellerRepayment,
        uint sellerInterest,
        uint buyerPrincipal,
        uint buyerDownPayment
    ) external {

        // Update deposits
        deposits += sellerInterest;

        // Settle pool and seller
        if (buyerPrincipal >= sellerRepayment) {

            // Update debts
            debt += buyerPrincipal - sellerRepayment;

        } else {

            // Update debts
            debt -= sellerRepayment - buyerPrincipal;
        }

        // Calculate salePrice & sellerDebt
        uint salePrice = buyerDownPayment + buyerPrincipal;
        uint sellerDebt = sellerRepayment + sellerInterest;
        // require(_bidActionable(_bid, sellerDebt), "bid not actionable");
        require(salePrice >= sellerDebt, "salePrice must cover sellerDebt");
        uint sellerEquity = salePrice - sellerDebt;

        // Push sellerEquity to seller
        UNDERLYING.safeTransfer(seller, sellerEquity);
    }
}