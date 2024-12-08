// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./PlanetsMetadataInterface.sol";
import {DynamicTraits} from "./DynamicTraits.sol";
import {IERC7496} from "./IERC7496.sol";

contract DrGreenNFT is
    ERC721,
    ERC2981,
    AccessControl,
    ERC721Pausable,
    DynamicTraits
{
    PlanetsMetadataInterface _planetsMetadata;

    event NFTMinted(
        string mintType,
        address indexed to,
        uint256 tokenId,
        uint16 metadataId,
        uint256 price,
        uint8 roundId
    );
    event NFTTransferred(
        address indexed from,
        address indexed to,
        uint256 tokenId
    );
    event FundsTransferred(address indexed to, uint256 amount);
    event UpdateTokenURI(uint16 indexed tokenId, string newUri, uint256 time);
    event RoundCreated(uint8 indexed roundId, Round round);
    event RoundUpdated(uint8 indexed roundId, Round round);
    event InventoryContractAddressUpdated(
        address indexed inventoryContractAddr
    );
    event RoyaltyInfoUpdated(address indexed receiver, uint96 feePercent);
    event TokenRotaltyUpdated(
        uint256 indexed tokenId,
        address indexed receiver,
        uint96 feePercent
    );
    event OwnershipRenounced(
        address indexed oldOwner,
        address indexed newOwner
    );
    event BaseTokenURIUpdated(string baseTokenUri);

    bytes32 public constant WHITELIST_SIGNER_ROLE =
        keccak256("WHITELIST_SIGNER_ROLE");
    bytes32 public constant NFT_UPDATE_SIGNER_ROLE =
        keccak256("NFT_UPDATE_SIGNER_ROLE");

    using Strings for uint256;
    using ECDSA for bytes32;

    struct NftMinted {
        uint8 goldMinted;
        uint8 platinumMinted;
        uint8 standardMinted;
    }

    enum RoundType {
        Presale,
        Greenlist,
        Public
    }

    struct Round {
        uint256 startTime;
        uint256 endTime;
        uint256 price;
        uint8[] planets;
        uint16 supply;
        RoundType roundType;
        bytes32 merkleRoot;
        bool isPaused;
    }

    uint8 private _goldCurrIndex = 1;
    uint8 private _platinumCurrIndex = 56;
    uint16 private _standardCurrIndex = 106;
    uint8 private _currentRoundId = 0;
    string public _baseTokenURI;
    bool public _isPresaleActive = false;
    address public _inventoryContractAddr;

    //mappings
    mapping(address => NftMinted) private _numberMinted;
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => Round) private _rounds;
    mapping(uint8 => bool) private _planetEnabled;
    mapping(bytes => bool) private _usedSignatures;
    mapping(uint16 => bool) private _usedMetadataIds;

    // constants
    uint8 private constant _platinumStartIndex = 56;
    uint16 private constant _standardStartIndex = 106;
    uint16 private constant MAX_SUPPLY = 5145;
    uint8 private constant GOLD_MAX_SUPPLY = 55;
    uint8 private constant PLATINUM_MAX_SUPPLY = 50;
    uint16 private constant NFTS_PER_PLANET = 252;
    bytes32 private constant CLIENT_COUNT_KEY =
        0x636c69656e74436f756e74000000000000000000000000000000000000000000;
    bytes32 private constant TX_COUNT_KEY =
        0x7478436f756e7400000000000000000000000000000000000000000000000000;
    bytes32 private constant TX_VOLUME_KEY =
        0x7478566f6c756d65000000000000000000000000000000000000000000000000;

    constructor(
        address planetsMetadataAddr,
        string memory baseTokenURI,
        string memory traitMetadataURI,
        address ownerAddress,
        address royaltyReceiver
    ) ERC721("Dr Green Digital Key", "DRGDK") {
        require(
            planetsMetadataAddr != address(0),
            "metadata addr cant be empty"
        );
        require(bytes(baseTokenURI).length > 0, "base URI cant be empty");
        require(bytes(traitMetadataURI).length > 0, "trait URI cant be empty");
        require(ownerAddress != address(0), "ownerAddress cant be empty");
        require(royaltyReceiver != address(0), "royaltyReceiver cant be empty");
        _planetsMetadata = PlanetsMetadataInterface(planetsMetadataAddr);
        _baseTokenURI = baseTokenURI;
        _setTraitMetadataURI(traitMetadataURI);
        _setDefaultRoyalty(royaltyReceiver, 900);
        _grantRole(DEFAULT_ADMIN_ROLE, ownerAddress);
        _grantRole(WHITELIST_SIGNER_ROLE, ownerAddress);
        _grantRole(NFT_UPDATE_SIGNER_ROLE, ownerAddress);
    }

    // This is the modifier for the whitelisted user
    modifier isWhitelistedUser(
        string memory mintType,
        uint8 limit,
        bytes memory sig
    ) {
        require(_standardCurrIndex <= MAX_SUPPLY, "Max supply reached");
        require(
            _isWhitelisted(mintType, limit, sig),
            "Signature failed or user not whitelisted"
        );
        _;
    }

    modifier onlyOwner() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Caller is not a owner"
        );
        _;
    }

    // set modifier to call the function by order management contract only
    modifier onlyInventoryContract() {
        require(
            msg.sender == _inventoryContractAddr,
            "only inventory contract can call this function."
        );
        _;
    }

    // function to create round by admin
    function createRound(
        uint256 startTime,
        uint256 endTime,
        uint256 price,
        uint8[] calldata planets,
        uint16 supply,
        RoundType roundType,
        bytes32 merkleRoot
    ) external onlyOwner {
        require(
            block.timestamp < startTime,
            "Start date must be later than the current time"
        );
        // if there is any round already created we need to make sure we can only create next round once current is finished
        if (_currentRoundId > 0) {
            Round storage round = _rounds[_currentRoundId];
            require(
                block.timestamp > round.endTime,
                "Current round is not yet ended."
            );
        }
        _currentRoundId++;
        _manageRound(
            _currentRoundId,
            startTime,
            endTime,
            price,
            planets,
            supply,
            roundType,
            merkleRoot,
            false
        );
        emit RoundCreated(_currentRoundId, _rounds[_currentRoundId]);
    }

    // Function to update round by admin
    function updateRound(
        uint8 roundId,
        uint256 startTime,
        uint256 endTime,
        uint256 price,
        uint8[] calldata planets,
        uint16 supply,
        RoundType roundType,
        bytes32 merkleRoot,
        bool isPaused
    ) external onlyOwner {
        require(roundId > 0 && roundId == _currentRoundId, "Invalid round ID");
        _manageRound(
            roundId,
            startTime,
            endTime,
            price,
            planets,
            supply,
            roundType,
            merkleRoot,
            isPaused
        );
        emit RoundUpdated(roundId, _rounds[roundId]);
    }

    // function to set inventory smart contract address by admin
    function setInventoryContractAddress(
        address inventoryContractAddress
    ) external onlyOwner {
        require(
            inventoryContractAddress != address(0),
            "cannot set zero address"
        );
        _inventoryContractAddr = inventoryContractAddress;
        emit InventoryContractAddressUpdated(inventoryContractAddress);
    }

    // This function is used to mint standard NFTs when whitelisted round is open and address is whitelisted
    /*
     * @dev
     * Requirements:
     * `planetNo` should be in uin8. Example: 2.
     * `mintLimit` should be in uin8. Example: 2.
     * `sig` should be in bytes. Example: 0x4418f..........d43e6b174571b.
     */
    function standardPreMint(
        uint8 planetNo,
        uint8 mintLimit,
        bytes memory sig
    ) external isWhitelistedUser("Standard", mintLimit, sig) {
        require(_isPresaleActive, "Presale is not active");
        require(_planetEnabled[planetNo], "Planet not enabled for this round");
        require(
            _numberMinted[msg.sender].standardMinted < mintLimit,
            "mint limit reached"
        );
        _numberMinted[msg.sender].standardMinted += 1;
        uint256 tokenId = _standardCurrIndex++;
        uint16 metadataId = _planetsMetadata.setRandomTokenMetadata(
            planetNo,
            tokenId
        );
        _safeMint(msg.sender, tokenId);
        emit NFTMinted(
            "StandardWhitelisted",
            msg.sender,
            tokenId,
            metadataId,
            0,
            0
        );
    }

    // @dev This function is used to mint standard NFTs
    /*
     * @dev
     * Requirements:
     * `roundId` should be in uin8.
     * `planetNo` should be in uin8.
     * `merkleProof` merkleProof.
     */
    function standardMint(
        uint8 planetNo,
        bytes32[] calldata merkleProof
    ) external payable {
        require(_standardCurrIndex <= MAX_SUPPLY, "Max supply reached");
        Round storage round = _rounds[_currentRoundId];
        require(
            round.roundType == RoundType.Greenlist ||
                round.roundType == RoundType.Public,
            "Only for greenlist and public mint"
        );
        require(round.startTime != 0, "No active round");
        require(
            block.timestamp >= round.startTime &&
                block.timestamp <= round.endTime &&
                !round.isPaused,
            "Minting is not active or paused"
        );
        require(_planetEnabled[planetNo], "Planet not enabled for this round");
        require(msg.value == round.price, "Incorrect payment amount");
        if (round.roundType == RoundType.Greenlist) {
            require(
                merkleProof.length > 0,
                "Merkle proof is required for Greenlist"
            );
            require(
                MerkleProof.verify(
                    merkleProof,
                    round.merkleRoot,
                    keccak256(abi.encodePacked(msg.sender))
                ),
                "You are not Greenlisted for this round"
            );
        }
        uint256 tokenId = _standardCurrIndex++;
        uint16 metadataId = _planetsMetadata.setRandomTokenMetadata(
            planetNo,
            tokenId
        );
        _safeMint(msg.sender, tokenId);
        emit NFTMinted(
            "Standard",
            msg.sender,
            tokenId,
            metadataId,
            msg.value,
            _currentRoundId
        );
    }

    /*
     * @dev
     * Requirements:
     * `addresses` Array of addresses to mint gold Nfts.
     * `metedataIds` Array of metedataIds which needs to be associated with NFT.
     */
    function goldMint(
        address[] calldata addresses,
        uint16[] calldata metedataIds
    ) external onlyOwner {
        uint8 totalGoldMinted = _goldCurrIndex - 1;
        require(totalGoldMinted < GOLD_MAX_SUPPLY, "all gold NFTs are minted.");
        require(
            addresses.length == metedataIds.length && addresses.length > 0,
            "Addresses and metedataIds must be the same length and non-empty"
        );
        uint256 totalToMint = addresses.length;
        require(
            totalGoldMinted + totalToMint <= GOLD_MAX_SUPPLY,
            "Total amount exceeds the gold NFT supply limit."
        );
        for (uint8 index = 0; index < totalToMint; index++) {
            require(
                addresses[index] != address(0),
                "address can not be empty."
            );
            uint16 metadataId = metedataIds[index];
            require(
                !_usedMetadataIds[metadataId],
                "MetadataId is already associated with NFT."
            );
            // Allowed metadataIds are between range 1 to 55
            require(
                metadataId > 0 && metadataId <= GOLD_MAX_SUPPLY,
                "metadataId must be between 1 to 55."
            );
        }
        for (uint8 i = 0; i < totalToMint; i++) {
            address addr = addresses[i];
            uint16 metadataId = metedataIds[i];
            _numberMinted[addr].goldMinted += 1;
            uint256 tokenId = _goldCurrIndex++;
            _planetsMetadata.setTokenMetadataId(tokenId, metadataId);
            _safeMint(addr, tokenId);
            _usedMetadataIds[metadataId] = true;
            emit NFTMinted("Gold", addr, tokenId, metadataId, 0, 0);
        }
    }

    // This function is used to mint platinum NFTs by admin
    /*
     * @dev
     * Requirements:
     * `addresses` Array of addresses to mint platinum Nfts.
     * `metedataIds` Array of metedataIds which needs to be associated with NFT.
     */
    function platinumMint(
        address[] calldata addresses,
        uint16[] calldata metedataIds
    ) external onlyOwner {
        uint8 totalPlatinumMinted = _platinumCurrIndex - _platinumStartIndex;
        require(
            totalPlatinumMinted < PLATINUM_MAX_SUPPLY,
            "all platinum NFTs are minted."
        );
        require(
            addresses.length == metedataIds.length && addresses.length > 0,
            "Addresses and metedataIds must be the same length and non-empty"
        );
        uint256 totalToMint = addresses.length;
        require(
            totalPlatinumMinted + totalToMint <= PLATINUM_MAX_SUPPLY,
            "Total amount exceeds the platinum NFT supply limit."
        );
        for (uint8 index = 0; index < totalToMint; index++) {
            require(
                addresses[index] != address(0),
                "address can not be empty."
            );
            uint16 metadataId = metedataIds[index];
            require(
                !_usedMetadataIds[metadataId],
                "MetadataId is already associated with NFT."
            );
            // Allowed metadataIds are between range 56 to 105
            require(
                metadataId >= _platinumStartIndex &&
                    metadataId < _platinumStartIndex + PLATINUM_MAX_SUPPLY,
                "metadataId must be between 56 to 105."
            );
        }
        for (uint8 i = 0; i < totalToMint; i++) {
            address addr = addresses[i];
            uint16 metadataId = metedataIds[i];
            _numberMinted[addr].platinumMinted += 1;
            uint256 tokenId = _platinumCurrIndex++;
            _planetsMetadata.setTokenMetadataId(tokenId, metadataId);
            _safeMint(addr, tokenId);
            _usedMetadataIds[metadataId] = true;
            emit NFTMinted("Platinum", addr, tokenId, metadataId, 0, 0);
        }
    }

    // Function to set royalty which is paid to the given address
    /*
     * @dev
     * Requirements:
     * - `receiver` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     * - `feePercent` should be given as multiplied by 100. Example: 9.5% should be as 950.
     */
    function setRoyalty(
        address receiver,
        uint96 feePercent
    ) external onlyOwner {
        if (receiver == address(0)) {
            receiver = msg.sender;
        }
        _setDefaultRoyalty(receiver, feePercent);
        emit RoyaltyInfoUpdated(receiver, feePercent);
    }

    // Function to set royalty for the specific tokenID
    /*
     * @dev
     * Requirements:
     * - `receiver` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     * - `feePercent` should be given as multiplied by 100. Example: 9.5% should be as 950.
     */
    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feePercent
    ) external onlyOwner {
        if (receiver == address(0)) {
            receiver = msg.sender;
        }
        _setTokenRoyalty(tokenId, receiver, feePercent);
        emit TokenRotaltyUpdated(tokenId, receiver, feePercent);
    }

    // function to withdraw ethers to admin account or other acocunt
    function withdrawFunds(address to) external onlyOwner {
        require(to != address(0), "address can not be empty.");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available for withdrawal.");
        emit FundsTransferred(to, balance); // Emit event before transfer for accurate logging
        (bool success, ) = to.call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    // Function to add client with NFT tokenID
    /*
     * @dev
     * Requirements:
     * - `tokenId` NFT tokenId for which clients to add.
     * - `clientsToAdd` number of clients to add
     */
    function addClient(
        uint16 tokenId,
        uint256 clientsToAdd
    ) external onlyInventoryContract {
        _requireOwned(tokenId);
        require(clientsToAdd > 0, "clientsToAdd must be greater than 0");

        // Retrieve and parse current client count
        uint256 clientCount = _stringToUint256(
            string(
                abi.encodePacked(
                    DynamicTraits.getTraitValue(tokenId, CLIENT_COUNT_KEY)
                )
            )
        );

        // Add new clients and convert directly to bytes32
        clientCount += clientsToAdd;

        bytes32 clientCountBytes = bytes32(bytes(clientCount.toString()));

        // Call the internal function to set the trait.
        DynamicTraits.setTrait(tokenId, CLIENT_COUNT_KEY, clientCountBytes);
    }

    // Function to add transaction count with NFT tokenID
    /*
     * @dev
     * Requirements:
     * - `tokenId` NFT tokenId for which clients to add.
     * - `txsToAdd` number of txs to add
     * - `txsAmtToAdd` total amount for txs
     * - `isRefunded` is this refund?
     */
    function addTransaction(
        uint16 tokenId,
        uint256 txsToAdd,
        uint256 txsAmtToAdd,
        bool isRefunded
    ) external onlyInventoryContract {
        _requireOwned(tokenId);
        require(
            txsToAdd > 0 && txsAmtToAdd > 0,
            "txsToAdd & txsAmtToAdd must be greater than 0"
        );
        // Get current transaction count and volume
        uint256 txCount = _stringToUint256(
            string(
                abi.encodePacked(
                    DynamicTraits.getTraitValue(tokenId, TX_COUNT_KEY)
                )
            )
        );
        uint256 txVolume = _stringToUint256(
            string(
                abi.encodePacked(
                    DynamicTraits.getTraitValue(tokenId, TX_VOLUME_KEY)
                )
            )
        );

        // Calculate new values based on isRefunded
        txCount = isRefunded ? txCount - txsToAdd : txCount + txsToAdd;
        txVolume = isRefunded ? txVolume - txsAmtToAdd : txVolume + txsAmtToAdd;

        bytes32 txCountBytes = bytes32(bytes(txCount.toString()));
        bytes32 txVolumeBytes = bytes32(bytes(txVolume.toString()));

        // Set the updated values
        DynamicTraits.setTrait(tokenId, TX_COUNT_KEY, txCountBytes);
        DynamicTraits.setTrait(tokenId, TX_VOLUME_KEY, txVolumeBytes);
    }

    function setTraitMetadataURI(string calldata uri) external onlyOwner {
        // Set the new metadata URI.
        _setTraitMetadataURI(uri);
    }

    function pauseMinting() public onlyOwner {
        _pause();
    }

    function unpauseMinting() public onlyOwner {
        _unpause();
    }

    function setBaseTokenURI(string memory baseTokenURI) external onlyOwner {
        require(
            bytes(baseTokenURI).length > 0,
            "Base token URI cannot be empty"
        );
        _baseTokenURI = baseTokenURI;
        emit BaseTokenURIUpdated(baseTokenURI);
    }

    // Renounce Ownership
    function renounceOwnership() external onlyOwner {
        // Renounce admin role
        renounceRole(DEFAULT_ADMIN_ROLE, msg.sender);
        emit OwnershipRenounced(msg.sender, address(0));
    }

    // Override the grantRole function
    function grantRole(
        bytes32 role,
        address account
    ) public virtual override(AccessControl) {
        // Check if the role is one of the predefined roles
        require(
            role == WHITELIST_SIGNER_ROLE || role == NFT_UPDATE_SIGNER_ROLE,
            "Invalid role"
        );

        // Check if the account is not the zero address
        require(account != address(0), "Account cant be the zero address");
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "you are not authorized."
        );
        _grantRole(role, account);
    }

    function updateTokenURI(
        uint16 tokenId,
        string calldata newMetadataUri,
        bytes calldata sig
    ) external {
        require(!_usedSignatures[sig], "Signature already used");
        require(
            _requireOwned(tokenId) == msg.sender,
            "you are not owner of the token."
        );
        require(bytes(newMetadataUri).length > 0, "Token URI cannot be empty");
        bytes32 digest = keccak256(abi.encodePacked(tokenId, newMetadataUri));
        require(
            hasRole(NFT_UPDATE_SIGNER_ROLE, digest.recover(sig)),
            "signature validation failed"
        );
        _tokenURIs[tokenId] = newMetadataUri;
        _usedSignatures[sig] = true;
        emit UpdateTokenURI(tokenId, newMetadataUri, block.timestamp);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721) returns (string memory) {
        _requireOwned(tokenId);
        if (bytes(_tokenURIs[tokenId]).length > 0) {
            return _tokenURIs[tokenId];
        }
        return
            string(
                abi.encodePacked(
                    _baseURI(),
                    _planetsMetadata.getMetadataIdByToken(tokenId).toString(),
                    ".json"
                )
            );
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, DynamicTraits, ERC2981, AccessControl)
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId || // ERC-721 interface
            interfaceId == type(IERC721Metadata).interfaceId || // ERC-721 Metadata interface
            interfaceId == type(IERC7496).interfaceId || // Dynamic Trait
            interfaceId == type(IERC2981).interfaceId || // ERC-2981 Royalty interface
            interfaceId == type(IAccessControl).interfaceId || // AccessControl interface
            super.supportsInterface(interfaceId);
    }

    function maxSupply()
        external
        view
        virtual
        returns (uint8 gold, uint8 platinum, uint16 total)
    {
        return (GOLD_MAX_SUPPLY, PLATINUM_MAX_SUPPLY, MAX_SUPPLY);
    }

    // total current supply of gold+platinum+standard
    function totalSupply() public view returns (uint256) {
        return
            (_goldCurrIndex - 1) +
            (_platinumCurrIndex - _platinumStartIndex) +
            (_standardCurrIndex - _standardStartIndex);
    }

    function numberMinted(
        address walletAddress
    ) external view virtual returns (NftMinted memory) {
        return _numberMinted[walletAddress];
    }

    function totalMinted()
        external
        view
        returns (
            uint8 gold,
            uint8 platinum,
            uint16 standard,
            uint256[20] memory planetMinted
        )
    {
        uint256[20] memory planetMintedArray;
        for (uint8 i = 1; i <= 20; i++) {
            planetMintedArray[i - 1] =
                NFTS_PER_PLANET -
                _planetsMetadata.getAvailableNFTsbyPlanet(i);
        }
        return (
            _goldCurrIndex - 1,
            _platinumCurrIndex - _platinumStartIndex,
            _standardCurrIndex - _standardStartIndex,
            planetMintedArray
        );
    }

    // function to get current round
    function getCurrentRound() external view returns (Round memory) {
        return _rounds[_currentRoundId];
    }

    // function to get the minted count by planet
    function getMintedbyPlanet(
        uint8 planetNo
    ) external view virtual returns (uint256) {
        return
            NFTS_PER_PLANET -
            _planetsMetadata.getAvailableNFTsbyPlanet(planetNo);
    }

    //Internal Functions

    // The following functions are overrides required by Solidity.
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Pausable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function _stringToUint256(
        string memory s
    ) internal pure returns (uint256 result) {
        bytes memory b = bytes(s);
        result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
    }

    function _isWhitelisted(
        string memory mintType,
        uint8 limit,
        bytes memory sig
    ) internal view returns (bool) {
        require(msg.sender != address(0), "Caller can't be null address");
        require(limit > 0, "Limit must be greater than 0");
        require(sig.length == 65, "Invalid signature length");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(mintType, msg.sender, limit, address(this))
                )
            )
        );
        return hasRole(WHITELIST_SIGNER_ROLE, digest.recover(sig));
    }

    // Internal function for managing round creation and updates
    function _manageRound(
        uint8 roundId,
        uint256 startTime,
        uint256 endTime,
        uint256 price,
        uint8[] memory planets,
        uint16 supply,
        RoundType roundType,
        bytes32 merkleRoot,
        bool isPaused
    ) internal {
        require(startTime < endTime, "Start date must be before end date");
        require(price > 0, "Price must be greater than zero");
        require(planets.length > 0, "At least one planet must be specified");
        require(supply > 0, "Supply must be greater than zero");

        // Validate merkle root for Greenlist rounds.
        if (roundType == RoundType.Greenlist) {
            require(
                merkleRoot != bytes32(0),
                "Merkle root is required for Greenlist round"
            );
        }

        // Validate planet numbers and update their status.
        for (uint8 i = 0; i < planets.length; i++) {
            uint8 planetNo = planets[i];
            require(
                planetNo > 0 && planetNo <= 20,
                "Planet must be between 1 to 20."
            );
            _planetEnabled[planetNo] = true;
        }

        // Create or update the round.
        _rounds[roundId] = Round(
            startTime,
            endTime,
            price,
            planets,
            supply,
            roundType,
            merkleRoot,
            isPaused
        );

        // Set presale status for Presale rounds.
        if (roundType == RoundType.Presale) {
            _isPresaleActive = true;
        }
    }
}
