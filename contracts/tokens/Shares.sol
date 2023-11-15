// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts//access/Ownable.sol";
import "../protocol/Registry.sol";

// TODOs:
// - debt transfers?
contract Shares is ERC1155URIStorage, Ownable {

    enum OwnershipType {
        EconomicBenefits, //
        Ownership, // Actual Onwrship
        Occupation, // Permission to live in the house (time slots with nft supply of 365 days/12 months, etc.)
        Rent, // Permission to rent out the house to someone
        Debt // Mortgage Debt
    }

    struct Debt {
        uint owed;
        address owedTo;
    }

    // Links
    Registry registry;

    // Vars
    uint private constant ONE_HUNDRED_PCT_SHARES = 100 * 1e18;
    uint public tokenCount;

    // Mappings
    mapping(uint propertyId => mapping(OwnershipType => uint tokenId)) propertyTypeTokenIds;
    mapping(address user => mapping(uint tokenId => Debt)) debts;

    constructor(address issuer) ERC1155("") Ownable(issuer) {

    }

    function mint(address to, string memory tokenURI) external onlyOwner {

        // Mint
        _mint(to, tokenCount, ONE_HUNDRED_PCT_SHARES, "");

        // Set URI
        _setURI(tokenCount, tokenURI);

        // Increment tokenCount
        tokenCount++;
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal override {

        // Ensure receiver is resident and non-american
        require(registry.isResident(to), "receiver isn't resident");
        // require(registry.isNotAmerican(to), "receiver might be american"); // Note: Ramona said american eResidents can have mortgages

        // Update
        super._update(from, to, ids, values);
    }

    function transferFullOwnership() external {
        // transfers everything
    }

    function transferFullUse() external {
        // transfers:
        // - economic benefits
        // - occupation
        // - economic benefits
    }

    function confirm2stepTx() external {

    }
}