// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

interface DrGreenNFTInterface {
    function addClient(uint16 tokenId, uint256 clientsToAdd) external;

    function addTransaction(
        uint16 tokenId,
        uint256 txsToAdd,
        uint256 txsAmtToAdd,
        bool isRefunded
    ) external;

    function ownerOf(uint256 tokenId) external view returns (address);

    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address, uint256);

    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}
