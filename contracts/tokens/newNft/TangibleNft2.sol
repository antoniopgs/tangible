// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./ITangibleNft2.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./residents/Residents.sol";
import "./debt/Debt.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TangibleNft2 is ITangibleNft2, ERC721URIStorage, ERC721Enumerable, Residents, Debt {

    uint public totalPrincipal;
    uint public totalDeposits;

    // Other Vars
    Counters.Counter private _tokenIds;

    // Libs
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    constructor(address tangible, address gsp, address pac, address usdc)
    /*  Debt(usdc) */ Roles(tangible, gsp, pac)
    ERC721("Prospera Real Estate Token", "PROSPERA") {

    }

    // Note: tokenURI will point to Prospera Property Registry (example: https://prospera-sure.hn/view/27) we might not even need IPFS
    function mint(address to, string memory _tokenURI) external onlyRole(GSP) returns (uint newTokenId) {
        newTokenId = _tokenIds.current();
        _safeMint(to, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
        _tokenIds.increment();
    }

    // ----- Functional View Overrides -----
    // Todo:
    // - require payment of transfer fees & sale fees before transfer? Or just build up debt for later?
    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal override(ERC721, ERC721Enumerable) {
        require(_isResident(to), "receiver not resident");
        require(tokenDebts[firstTokenId].loan.unpaidPrincipal == 0, "can't transfer nft with mortgage debt");
        super._beforeTokenTransfer(from, to, 0, batchSize); // is it fine to pass 0 here?
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view override returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender ||
        hasRole(PAC, spender)); // Note: Overriden to allow PAC to move tokens
    }

    // ----- Inheritance Overrides -----
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable, ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function buyToken(uint tokenId, uint salePrice) external {
        loanBuyToken(tokenId, salePrice, salePrice);
    }

    function sellToken(address buyer, uint tokenId, uint salePrice) external {
        loanSellToken(buyer, tokenId, salePrice, salePrice);
    }

    function loanBuyToken(uint tokenId, uint salePrice, uint downPayment) public {
        debtTransfer(ownerOf(tokenId), msg.sender, tokenId, salePrice, downPayment);
    }

    // Note: pulling everything to address(this) is better because:
    // - easier: buyer only needs to approve address(this), instead of address(this) and seller
    // - safer: no need to approve seller (which could let him run off with money)
    // QUESTION: could I make it more efficient if an active mortage is being sold with a new loan? in said scenario, money flows should be simpler...
    function loanSellToken(address buyer, uint tokenId, uint salePrice, uint downPayment) public { // QUESTION: would loanBuyToken() be better?
        debtTransfer(msg.sender, buyer, tokenId, salePrice, downPayment);
    }

    function debtTransfer(address seller, address buyer, uint tokenId, uint salePrice, uint downPayment) private {

        // 1. Pull downPayment from buyer
        USDC.safeTransferFrom(buyer, address(this), downPayment);

        // 2. Pull principal (salePrice - downPayment) from protocol
        // USDC.safeTransferFrom(protocol, address(this), salePrice - downPayment); // Note: salePrice - downPayment will be 0 if no loan, which is fine

        // 3. Get Loan
        Debt storage debt = tokenDebts[tokenId];
        Loan storage loan = debt.loan;
        uint interest = accruedInterest(loan);

        // Update Pool (pay off lenders)
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;

        // 5. Clear seller/caller debt
        loan.unpaidPrincipal = 0;
        debt.otherDebt = 0;

        // 3. Send sellerEquity (salePrice - unpaidPrincipal - interest - otherDebt) to seller
        USDC.safeTransfer(seller, salePrice - loan.unpaidPrincipal - interest - debt.otherDebt);

        // 3. Send nft from seller to buyer
        safeTransferFrom(seller, buyer, tokenId);

    }
}