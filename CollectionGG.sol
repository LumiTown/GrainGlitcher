// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Grain Glitcher is ERC721Enumerable, AccessControlEnumerable {
    uint256 public priceCreators;
    uint256 public priceWhitelist;
    uint256 public pricePublic;
    uint256 public maxSupply;

    mapping(address => mapping(MintPhase => uint256)) public mintLimitsByPhase;

    enum MintPhase {CREATORS, WHITELIST, PUBLIC}
    MintPhase public currentPhase;

    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    string private _baseTokenURI;

    constructor(
        string memory name,
        string memory symbol,
        uint256 _maxSupply
    ) ERC721(name, symbol) {
        _grantRole(CREATOR_ROLE, msg.sender);
        maxSupply = _maxSupply;
        currentPhase = MintPhase.CREATORS; // Default phase
    }

    // ----------------------
    // Admin Configuration
    // ----------------------
    function setPrices(uint256 _priceCreators, uint256 _priceWhitelist, uint256 _pricePublic) external onlyRole(CREATOR_ROLE) {
        priceCreators = _priceCreators;
        priceWhitelist = _priceWhitelist;
        pricePublic = _pricePublic;
    }

    function setMintLimitsByPhase(address[] calldata wallets, MintPhase phase, uint256[] calldata limits) external onlyRole(CREATOR_ROLE) {
        require(wallets.length == limits.length, "Mismatched inputs");
        for (uint256 i = 0; i < wallets.length; i++) {
            mintLimitsByPhase[wallets[i]][phase] = limits[i];
        }
    }

    function startMintingPhase(uint8 phase) external onlyRole(CREATOR_ROLE) {
        require(phase <= uint8(MintPhase.PUBLIC), "Invalid phase");
        currentPhase = MintPhase(phase);
    }

    // ----------------------
    // Metadata Configuration
    // ----------------------
    function setBaseURI(string memory baseURI) external onlyRole(CREATOR_ROLE) {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // ----------------------
    // Minting Logic
    // ----------------------
    function mint(uint256 quantity) external payable {
        require(totalSupply() + quantity <= maxSupply, "Exceeds max supply");
        uint256 price = getPrice() * quantity;

        // Ensure payment is sufficient
        require(msg.value >= price, "Insufficient payment");

        // Validate mint limits for the current phase
        require(quantity <= mintLimitsByPhase[msg.sender][currentPhase], "Exceeds mint limit for this phase");
        mintLimitsByPhase[msg.sender][currentPhase] -= quantity;

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = totalSupply() + 1;
            _safeMint(msg.sender, tokenId);
        }
    }

    function getPrice() public view returns (uint256) {
        if (currentPhase == MintPhase.CREATORS) {
            require(hasRole(CREATOR_ROLE, msg.sender), "Not a creator");
            return priceCreators;
        } else if (currentPhase == MintPhase.WHITELIST) {
            return priceWhitelist;
        } else if (currentPhase == MintPhase.PUBLIC) {
            return pricePublic;
        } else {
            revert("Invalid minting phase");
        }
    }

    // ----------------------
    // Withdraw Funds
    // ----------------------
    function withdraw() external onlyRole(CREATOR_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(msg.sender).transfer(balance);
    }

    // ----------------------
    // Role Management & Metadata
    // ----------------------
    function readRoles() external view returns (uint256) {
        return getRoleMemberCount(CREATOR_ROLE);
    }

    // ----------------------
    // Override supportsInterface
    // ----------------------
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, AccessControlEnumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
