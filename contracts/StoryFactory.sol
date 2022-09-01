// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "./IStoryNFT.sol";

contract StoryFactory is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IERC721ReceiverUpgradeable
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
        REJECTED, // not used
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
    event SubmitUpdated(uint256 storyId, uint256 taskId, uint256 submitId);
    event AuthorClaimed(uint256 storyId, uint256 amount);

    mapping(uint256 => StoryTasks) public storyTasks;
    mapping(uint256 => mapping(uint256 => Task)) public tasks; // tasks[storyId][taskId]
    mapping(uint256 => mapping(uint256 => mapping(uint256 => Submit)))
        public submits; // submits[storyId][taskId][submitId]

    modifier onlyAuthor(uint256 id) {
        require(stories[id].author == msg.sender, "only author");
        _;
    }
    modifier onlySaleExist(uint256 id) {
        require(sales[id].id != 0, "sale not exist");
        _;
    }
    modifier onlyTaskExist(uint256 storyId, uint256 taskId) {
        require(tasks[storyId][taskId].id != 0, "task not exist");
        _;
    }
    modifier onlyTaskExistAndStatus(
        uint256 storyId,
        uint256 taskId,
        TaskStatus status
    ) {
        require(tasks[storyId][taskId].id != 0, "task not exist");
        require(tasks[storyId][taskId].status == status, "task status wrong");
        _;
    }
    modifier onlyTaskSubmitExist(
        uint256 storyId,
        uint256 taskId,
        uint256 submitId
    ) {
        require(
            submits[storyId][taskId][submitId].id != 0,
            "task submit not exist"
        );
        _;
    }
    modifier onlyTaskSubmitExistAndStatus(
        uint256 storyId,
        uint256 taskId,
        uint256 submitId,
        SubmitStatus status
    ) {
        require(
            submits[storyId][taskId][submitId].id != 0,
            "task submit not exist"
        );
        require(
            submits[storyId][taskId][submitId].status == status,
            "task submit status wrong"
        );
        _;
    }

    modifier onlyTaskCreator(uint256 storyId, uint256 taskId) {
        require(msg.sender == tasks[storyId][taskId].creator, "not creator");
        _;
    }
    modifier onlySubmitCreator(
        uint256 storyId,
        uint256 taskId,
        uint256 submitId
    ) {
        require(
            msg.sender == submits[storyId][taskId][submitId].creator,
            "not creator"
        );
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

    // TODO author batch claimed
    function claimAuthorReservedNft(uint256 storyId, uint256 amount)
        public
        onlyAuthor(storyId)
        onlySaleExist(storyId)
    {
        require(
            sales[storyId].authorReserved - sales[storyId].authorClaimed >=
                amount,
            "not enough amount"
        );
        sales[storyId].authorClaimed += amount;
        for (uint256 idx = 0; idx < amount; idx++) {
            IStoryNFT(sales[storyId].nft).safeMint(msg.sender);
        }
        emit AuthorClaimed(storyId, amount);
    }

    // TODO author create task
    function createTask(
        uint256 storyId,
        string memory cid,
        address nft,
        uint256[] memory rewardNfts
    ) public onlyAuthor(storyId) {
        // init story tasks if not
        if (storyTasks[storyId].storyId != storyId) {
            storyTasks[storyId].storyId = storyId;
            storyTasks[storyId].nextTaskId = 1;
        }
        // check nft owner
        if (rewardNfts.length > 0) {
            // require(sales[storyId].nft != address(0), "nft not published");
            for (uint256 idx = 0; idx < rewardNfts.length; idx++) {
                require(
                    IStoryNFT(nft).ownerOf(rewardNfts[idx]) == msg.sender,
                    "not nft owner"
                );
                IStoryNFT(nft).safeTransferFrom(
                    msg.sender,
                    address(this),
                    rewardNfts[idx]
                );
            }
        }
        uint256 taskId = storyTasks[storyId].nextTaskId++;
        tasks[storyId][taskId].id = taskId;
        tasks[storyId][taskId].cid = cid;
        tasks[storyId][taskId].nextSubmitId = 1;
        tasks[storyId][taskId].status = TaskStatus.TODO;
        tasks[storyId][taskId].creator = msg.sender;
        tasks[storyId][taskId].nft = nft;
        tasks[storyId][taskId].rewardNfts = rewardNfts;
        emit TaskUpdated(storyId, taskId);
    }

    // TODO author update task
    function updateTask(
        uint256 storyId,
        uint256 taskId,
        string memory cid
    ) public onlyTaskExist(storyId, taskId) onlyTaskCreator(storyId, taskId) {
        tasks[storyId][taskId].cid = cid;
        emit TaskUpdated(storyId, taskId);
    }

    // TODO author cancel task
    function cancelTask(uint256 storyId, uint256 taskId)
        public
        onlyTaskExistAndStatus(storyId, taskId, TaskStatus.TODO)
        onlyTaskCreator(storyId, taskId)
    {
        Task storage task = tasks[storyId][taskId];

        task.status = TaskStatus.CANCELLED;

        for (uint256 idx = 0; idx < task.rewardNfts.length; idx++) {
            IStoryNFT(task.nft).safeTransferFrom(
                address(this),
                task.creator,
                task.rewardNfts[idx]
            );
        }
        emit TaskUpdated(storyId, taskId);
    }

    // TODO user submit task
    function createTaskSubmit(
        uint256 storyId,
        uint256 taskId,
        string memory cid
    ) public onlyTaskExistAndStatus(storyId, taskId, TaskStatus.TODO) {
        Task storage task = tasks[storyId][taskId];
        uint256 submitId = task.nextSubmitId++;

        submits[storyId][taskId][submitId].id = submitId;
        submits[storyId][taskId][submitId].creator = msg.sender;
        submits[storyId][taskId][submitId].cid = cid;
        submits[storyId][taskId][submitId].status = SubmitStatus.PENDING;

        emit SubmitUpdated(storyId, taskId, submitId);
    }

    // TODO user withdraw task
    function withdrawTaskSubmit(
        uint256 storyId,
        uint256 taskId,
        uint256 submitId
    )
        public
        onlyTaskExistAndStatus(storyId, taskId, TaskStatus.TODO)
        onlyTaskSubmitExistAndStatus(
            storyId,
            taskId,
            submitId,
            SubmitStatus.PENDING
        )
        onlySubmitCreator(storyId, taskId, submitId)
    {
        submits[storyId][taskId][submitId].status = SubmitStatus.WITHDRAWED;
        emit SubmitUpdated(storyId, taskId, submitId);
    }

    // TODO author mark task as done
    function markTaskDone(
        uint256 storyId,
        uint256 taskId,
        uint256 selectedSubmitId
    )
        public
        onlyTaskExistAndStatus(storyId, taskId, TaskStatus.TODO)
        onlyTaskCreator(storyId, taskId)
        onlyTaskSubmitExistAndStatus(
            storyId,
            taskId,
            selectedSubmitId,
            SubmitStatus.PENDING
        )
    {
        Task storage task = tasks[storyId][taskId];
        task.status = TaskStatus.DONE;
        Submit storage selectedSubmit = submits[storyId][taskId][
            selectedSubmitId
        ];
        selectedSubmit.status = SubmitStatus.APPROVED;
        emit SubmitUpdated(storyId, taskId, selectedSubmit.id);

        address submitCreator = selectedSubmit.creator;
        for (uint256 idx = 0; idx < task.rewardNfts.length; idx++) {
            IStoryNFT(task.nft).safeTransferFrom(
                address(this),
                submitCreator,
                task.rewardNfts[idx]
            );
        }
        emit TaskUpdated(storyId, taskId);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function getTask(uint256 sid, uint256 tid)
        public
        view
        returns (Task memory)
    {
        return tasks[sid][tid];
    }

    function getSubmit(
        uint256 storyId,
        uint256 taskId,
        uint256 submitId
    ) public view returns (Submit memory) {
        return submits[storyId][taskId][submitId];
    }
}
