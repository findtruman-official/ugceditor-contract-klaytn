// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IStoryNFT {
    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _base
    ) external;

    function safeMint(address to) external;
}
