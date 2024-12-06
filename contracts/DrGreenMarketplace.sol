// SPDX-License-Identifier:MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./DrGreenNFTInterface.sol";

contract DrGreenMarketplace is ReentrancyGuard {
    DrGreenNFTInterface _NftInterface;

    event Bought(
        uint256 indexed tokenId,
        address indexed nft,
        uint256 price,
        address indexed seller,
        address buyer
    );
    event ListingCancelled(
        address indexed owner,
        uint256 indexed tokenId,
        bytes signature,
        uint256 timestamp
    );

    using ECDSA for bytes32;

    string public constant CONTRACT_NAME = "DrGreenMarketplace";
    string public constant VERSION = "1";

    mapping(bytes => bool) private _usedSignatures;

    constructor(address _NftContractAddress) {
        require(
            _NftContractAddress != address(0),
            "_NftContractAddress can not be empty"
        );
        _NftInterface = DrGreenNFTInterface(_NftContractAddress);
    }

    function buyNFT(
        uint256 tokenId,
        bytes memory sig,
        bytes32 salt
    ) external payable nonReentrant {
        require(sig.length > 0, "signature can not be empty.");
        require(salt.length > 0, "salt can not be empty.");
        require(!_usedSignatures[sig], "signature already used");
        address tokenOwner = _NftInterface.ownerOf(tokenId);

        verifySignature(sig, salt, tokenOwner, tokenId, msg.value);

        // Get royalty information and calculate seller amount
        (address receiver, uint256 royaltyAmount) = _NftInterface.royaltyInfo(
            tokenId,
            msg.value
        );

        uint256 sellerAmount = msg.value - royaltyAmount;

        // Perform payment with checks
        (bool sentToSeller, ) = tokenOwner.call{value: sellerAmount}("");
        require(sentToSeller, "Payment to seller failed");

        (bool sentToReceiver, ) = receiver.call{value: royaltyAmount}("");
        require(sentToReceiver, "Royalty payment failed");

        _usedSignatures[sig] = true;

        // Transfer NFT ownership to buyer
        _NftInterface.safeTransferFrom(tokenOwner, msg.sender, tokenId);

        emit Bought(
            tokenId,
            address(_NftInterface),
            msg.value,
            tokenOwner,
            msg.sender
        );
    }

    function cancelListing(
        uint256 tokenId,
        uint256 amount,
        bytes memory sig,
        bytes32 salt
    ) external {
        require(sig.length > 0, "signature can not be empty.");
        require(salt.length > 0, "salt can not be empty.");
        require(!_usedSignatures[sig], "signature already used");
        address tokenOwner = _NftInterface.ownerOf(tokenId);
        require(tokenOwner == msg.sender, "Owner only.");
        verifySignature(sig, salt, msg.sender, tokenId, amount);
        _usedSignatures[sig] = true;
        emit ListingCancelled(msg.sender, tokenId, sig, block.timestamp);
    }

    function verifySignature(
        bytes memory sig,
        bytes32 salt,
        address owner,
        uint256 tokenId,
        uint256 amount
    ) internal view returns (bool) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _getDomainSeparator(salt),
                keccak256(
                    abi.encode(
                        keccak256(
                            "Sale(address owner,uint256 tokenId,uint256 amount)"
                        ),
                        owner,
                        tokenId,
                        amount
                    )
                )
            )
        );

        // Validate signature directly
        require(digest.recover(sig) == owner, "signature validation failed");
        return true;
    }

    function _getDomainSeparator(bytes32 salt) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"
                    ),
                    keccak256(bytes(CONTRACT_NAME)),
                    keccak256(bytes(VERSION)),
                    block.chainid,
                    address(this),
                    salt
                )
            );
    }
}
