// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ProsperaNft is ERC721URIStorage, AccessControl {

    // Structs
    struct Inspection {
        address inspector;
        string inspectionURI;
        uint inspectionTime;
    }

    // Vars
    Counters.Counter private _tokenIds;
    mapping(uint => Inspection[]) public tokenIdInspections;
    mapping(uint => uint) public tokenIdLastURIUpdateTime;
    mapping(address => bool) public isEResident;
    mapping(uint => address) public eResidentAddress;

    // Roles
    bytes32 public constant PAC = keccak256("PAC");
    bytes32 public constant GSP = keccak256("GSP");
    bytes32 public constant INSPECTOR = keccak256("INSPECTOR");

    // Libs
    using Counters for Counters.Counter;

    constructor() ERC721("Prospera Real Estate Token", "PROSPERA") {}

    function addInspection(uint tokenId, string memory newInspectionURI) external onlyRole(INSPECTOR) {
        tokenIdInspections[tokenId].push(
            Inspection({
                inspector: msg.sender,
                inspectionURI: newInspectionURI,
                inspectionTime: block.timestamp
            })
        );
    }

    function updateTokenURI(uint tokenId, string memory newTokenURI) external {
        require(msg.sender == ownerOf(tokenId), "only token owner can update its metadata");
        _setTokenURI(tokenId, newTokenURI);
        tokenIdLastURIUpdateTime[tokenId] = block.timestamp;
    }

    function mint(address to, string memory _tokenURI) external onlyRole(GSP) returns (uint newTokenId) {
        newTokenId = _tokenIds.current();
        _safeMint(to, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
        _tokenIds.increment();
    }

    function lastUpdateInspected(uint tokenId) external view returns (bool) {
        Inspection[] memory _tokenIdInspections = tokenIdInspections[tokenId];
        return _tokenIdInspections[_tokenIdInspections.length - 1].inspectionTime > tokenIdLastURIUpdateTime[tokenId];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256, /* firstTokenId */ uint256 batchSize) internal override {
        require(isEResident[to], "receiver not eResident");
        super._beforeTokenTransfer(from, to, 0, batchSize); // is it fine to pass 0 here?
    }

    // maybe just replace the "eResidentAddr" param with msg.sender, and allow the caller to verify himself?
    function verifyEResident(uint eResidentId, address eResidentAddr) external onlyRole(PAC) { // is it the PAC that verifies eResidents?
        require(!isEResident[eResidentAddr], "address already associated to an eResident");
        require(eResidentAddress[eResidentId] == address(0), "eResidentId already associated to an address");
        isEResident[eResidentAddr] = true;
        eResidentAddress[eResidentId] = eResidentAddr;
    }

    // function createDispute() external {
    //     require(isEResident[msg.sender], "caller not eResident. only eResidents can create disputes");

    //     block.timestamp
    // }

    function resolveDispute() external onlyRole(PAC) {

    }
}