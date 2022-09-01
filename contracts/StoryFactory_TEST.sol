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

    // Tasks
    enum TaskStatus {
        TODO,
        DONE,
        CANCELLED
    }
    enum SubmitStatus {
        PENDING,
        APPROVED,
        REJECTED,
        WITHDRAWED
    }

    struct StoryTasks {
        uint256 storyId;
        uint256 nextTaskId;
        // mapping(uint256 => Task) tasks;
    }
    struct Submit {
        uint256 id;
        address creator;
        SubmitStatus status;
        string cid;
    }
    struct Task {
        uint256 id;
        string cid;
        address creator;
        address nft;
        uint256[] rewardNfts;
        TaskStatus status;
        uint256 nextSubmitId;
        // mapping(uint256 => Submit) submits;
    }
    event TaskUpdated(uint256 storyId, uint256 taskId);
    event AuthorClaimed(uint256 storyId, uint256 amount);

    mapping(uint256 => StoryTasks) public storyTasks;
    mapping(uint256 => mapping(uint256 => Task)) public tasks; // tasks[storyId][taskId]
    mapping(uint256 => mapping(uint256 => mapping(uint256 => Submit)))
        public submits; // submits[storyId][taskId][submitId]

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
