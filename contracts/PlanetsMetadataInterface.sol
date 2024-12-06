// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface PlanetsMetadataInterface {
    function setRandomTokenMetadata(uint8 planetNo, uint256 tokenId)
        external
        returns (uint16);

    function setTokenMetadataId(uint256 tokenId, uint16 metadataId) external;

    function getMetadataIdByToken(uint256 tokenId)
        external
        view
        returns (uint256);

    function getAvailableNFTsbyPlanet(uint8 planetNo)
        external
        view
        returns (uint256);
}