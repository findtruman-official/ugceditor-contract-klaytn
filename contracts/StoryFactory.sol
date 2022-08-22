// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IStoryNFT.sol";

contract StoryFactory is
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

    address nftBeacon;

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
    constructor() {
        _disableInitializers();
    }

    function initialize(address _nftBeacon) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        nextId = 1;
        published = 0;
        nftBeacon = _nftBeacon;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    // functions
    function publishStory(string memory cid) public {
        uint256 id = nextId;
        stories[id].author = msg.sender;
        stories[id].cid = cid;
        stories[id].id = id;
        nextId += 1;
        emit StoryUpdated(id, msg.sender);
    }

    function updateStory(uint256 id, string memory cid) public onlyAuthor(id) {
        stories[id].cid = cid;
        emit StoryUpdated(id, msg.sender);
    }

    function publishStoryNft(
        uint256 id,
        string memory name,
        string memory symbol,
        string memory base,
        address token,
        uint256 price,
        uint256 total,
        uint256 authorReserved
    ) public onlyAuthor(id) {
        require(sales[id].id == 0, "sale exists");

        sales[id].id = id;
        sales[id].total = total;
        sales[id].sold = 0;
        sales[id].authorReserved = authorReserved;
        sales[id].authorClaimed = 0;
        sales[id].recv = stories[id].author;
        sales[id].token = token;
        sales[id].price = price;

        BeaconProxy proxy = new BeaconProxy(nftBeacon, "");

        sales[id].nft = address(proxy);
        IStoryNFT(sales[id].nft).initialize(name, symbol, base);
        emit StoryNftPublished(id);
    }

    function mintStoryNft(uint256 id) public onlySaleExist(id) {
        require(
            sales[id].total - sales[id].authorReserved - sales[id].sold > 0,
            "sold out"
        );

        IERC20 token = IERC20(sales[id].token);
        require(
            token.balanceOf(msg.sender) >= sales[id].price,
            "not enough token"
        );
        sales[id].sold += 1;
        token.transferFrom(msg.sender, sales[id].recv, sales[id].price);

        IStoryNFT(sales[id].nft).safeMint(msg.sender);
        emit StoryNftMinted(id, msg.sender);
    }
}
