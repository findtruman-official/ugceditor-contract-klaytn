// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IStoryNFT.sol";

contract StoryFactory_TEST is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    struct Sale {
        uint256 id;
        uint256 total;
        uint256 sold;
        uint256 authorReserved;
        uint256 authorClaimed;
        address recv;
        address token;
        uint256 price;
        address nft;
    }

    struct Story {
        uint256 id;
        address author;
        string cid;
    }

    event StoryUpdated(uint256 indexed id, address indexed author);

    event StoryNftPublished(uint256 indexed id);

    event StoryNftMinted(uint256 indexed id, address indexed minter);

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address public nftBeacon;

    uint256 public nextId;
    uint256 public published;
    mapping(uint256 => Story) public stories;
    mapping(uint256 => Sale) public sales;

    modifier onlyAuthor(uint256 id) {
        require(stories[id].author == msg.sender, "only author");
        _;
    }
    modifier onlySaleExist(uint256 id) {
        require(sales[id].id != 0, "sale not exist");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {}

    function magic() public pure returns (uint256) {
        return 523;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
}
