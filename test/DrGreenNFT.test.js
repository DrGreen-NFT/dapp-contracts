const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DrGreenNFT", function () {
    let DrGreenNFT, drGreenNFT, PlanetsMetadata, planetsMetadata, owner, addr1, addr2;

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();

        // Deploy PlanetsMetadata contract
        const PlanetsMetadataFactory = await ethers.getContractFactory("PlanetsMetadata");
        planetsMetadata = await PlanetsMetadataFactory.deploy();
        await planetsMetadata.deployed();

        // Deploy DrGreenNFT contract
        const DrGreenNFTFactory = await ethers.getContractFactory("DrGreenNFT");
        drGreenNFT = await DrGreenNFTFactory.deploy(
            planetsMetadata.address,
            "baseTokenURI",
            "traitMetadataURI",
            owner.address,
            owner.address
        );
        await drGreenNFT.deployed();
    });

    it("Should allow minting standard NFTs during presale", async function () {
        const planetNo = 1;
        const mintLimit = 2;
        const sig = ethers.utils.randomBytes(65); // Mock signature

        // Set presale active
        await drGreenNFT.setPresaleActive(true);

        // Mint standard NFT
        await expect(drGreenNFT.connect(addr1).standardPreMint(planetNo, mintLimit, sig))
            .to.emit(drGreenNFT, "NFTMinted")
            .withArgs("StandardWhitelisted", addr1.address, 106, 1, 0, 0);

        // Check NFT ownership
        expect(await drGreenNFT.ownerOf(106)).to.equal(addr1.address);
    });

    it("Should allow minting standard NFTs during greenlist round", async function () {
        const planetNo = 1;
        const price = ethers.utils.parseEther("1");
        const merkleRoot = ethers.utils.randomBytes(32); // Mock merkle root
        const merkleProof = []; // Mock merkle proof

        // Create greenlist round
        await drGreenNFT.createRound(
            Math.floor(Date.now() / 1000),
            Math.floor(Date.now() / 1000) + 3600,
            price,
            [planetNo],
            100,
            1, // Greenlist round type
            merkleRoot
        );

        // Mint standard NFT
        await expect(drGreenNFT.connect(addr1).standardMint(planetNo, merkleProof, { value: price }))
            .to.emit(drGreenNFT, "NFTMinted")
            .withArgs("Standard", addr1.address, 107, 2, price, 1);

        // Check NFT ownership
        expect(await drGreenNFT.ownerOf(107)).to.equal(addr1.address);
    });

    it("Should allow minting gold NFTs by admin", async function () {
        const addresses = [addr1.address];
        const metadataIds = [1];

        // Mint gold NFT
        await expect(drGreenNFT.connect(owner).goldMint(addresses, metadataIds))
            .to.emit(drGreenNFT, "NFTMinted")
            .withArgs("Gold", addr1.address, 1, 1, 0, 0);

        // Check NFT ownership
        expect(await drGreenNFT.ownerOf(1)).to.equal(addr1.address);
    });

    it("Should allow minting platinum NFTs by admin", async function () {
        const addresses = [addr1.address];
        const metadataIds = [56];

        // Mint platinum NFT
        await expect(drGreenNFT.connect(owner).platinumMint(addresses, metadataIds))
            .to.emit(drGreenNFT, "NFTMinted")
            .withArgs("Platinum", addr1.address, 56, 56, 0, 0);

        // Check NFT ownership
        expect(await drGreenNFT.ownerOf(56)).to.equal(addr1.address);
    });

    it("Should allow setting royalty", async function () {
        const receiver = addr1.address;
        const feePercent = 900; // 9%

        // Set royalty
        await expect(drGreenNFT.connect(owner).setRoyalty(receiver, feePercent))
            .to.emit(drGreenNFT, "RoyaltyInfoUpdated")
            .withArgs(receiver, feePercent);

        // Check royalty info
        const royaltyInfo = await drGreenNFT.royaltyInfo(1, ethers.utils.parseEther("1"));
        expect(royaltyInfo[0]).to.equal(receiver);
        expect(royaltyInfo[1]).to.equal(ethers.utils.parseEther("0.09"));
    });

    it("Should allow setting token royalty", async function () {
        const tokenId = 1;
        const receiver = addr1.address;
        const feePercent = 900; // 9%

        // Set token royalty
        await expect(drGreenNFT.connect(owner).setTokenRoyalty(tokenId, receiver, feePercent))
            .to.emit(drGreenNFT, "TokenRotaltyUpdated")
            .withArgs(tokenId, receiver, feePercent);

        // Check token royalty info
        const royaltyInfo = await drGreenNFT.royaltyInfo(tokenId, ethers.utils.parseEther("1"));
        expect(royaltyInfo[0]).to.equal(receiver);
        expect(royaltyInfo[1]).to.equal(ethers.utils.parseEther("0.09"));
    });

    it("Should allow withdrawing funds", async function () {
        const price = ethers.utils.parseEther("1");
        const merkleRoot = ethers.utils.randomBytes(32); // Mock merkle root
        const merkleProof = []; // Mock merkle proof

        // Create greenlist round
        await drGreenNFT.createRound(
            Math.floor(Date.now() / 1000),
            Math.floor(Date.now() / 1000) + 3600,
            price,
            [1],
            100,
            1, // Greenlist round type
            merkleRoot
        );

        // Mint standard NFT
        await drGreenNFT.connect(addr1).standardMint(1, merkleProof, { value: price });

        // Withdraw funds
        await expect(drGreenNFT.connect(owner).withdrawFunds(owner.address))
            .to.emit(drGreenNFT, "FundsTransferred")
            .withArgs(owner.address, price);

        // Check contract balance
        expect(await ethers.provider.getBalance(drGreenNFT.address)).to.equal(0);
    });

    it("Should allow adding clients and transactions", async function () {
        const tokenId = 106;
        const clientsToAdd = 10;
        const txsToAdd = 5;
        const txsAmtToAdd = ethers.utils.parseEther("0.5");

        // Mint standard NFT
        const planetNo = 1;
        const mintLimit = 2;
        const sig = ethers.utils.randomBytes(65); // Mock signature
        await drGreenNFT.setPresaleActive(true);
        await drGreenNFT.connect(addr1).standardPreMint(planetNo, mintLimit, sig);

        // Add clients
        await drGreenNFT.connect(owner).addClient(tokenId, clientsToAdd);

        // Add transactions
        await drGreenNFT.connect(owner).addTransaction(tokenId, txsToAdd, txsAmtToAdd, false);

        // Check dynamic traits
        const clientCount = await drGreenNFT.getTraitValue(tokenId, "clientCount");
        const txCount = await drGreenNFT.getTraitValue(tokenId, "txCount");
        const txVolume = await drGreenNFT.getTraitValue(tokenId, "txVolume");

        expect(clientCount).to.equal(clientsToAdd.toString());
        expect(txCount).to.equal(txsToAdd.toString());
        expect(txVolume).to.equal(txsAmtToAdd.toString());
    });

    it("Should allow updating token URI", async function () {
        const tokenId = 106;
        const newMetadataUri = "newMetadataUri";
        const sig = ethers.utils.randomBytes(65); // Mock signature

        // Mint standard NFT
        const planetNo = 1;
        const mintLimit = 2;
        const mintSig = ethers.utils.randomBytes(65); // Mock signature
        await drGreenNFT.setPresaleActive(true);
        await drGreenNFT.connect(addr1).standardPreMint(planetNo, mintLimit, mintSig);

        // Update token URI
        await expect(drGreenNFT.connect(addr1).updateTokenURI(tokenId, newMetadataUri, sig))
            .to.emit(drGreenNFT, "UpdateTokenURI")
            .withArgs(tokenId, newMetadataUri, Math.floor(Date.now() / 1000));

        // Check token URI
        expect(await drGreenNFT.tokenURI(tokenId)).to.equal(newMetadataUri);
    });
});