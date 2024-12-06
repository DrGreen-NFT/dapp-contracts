const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DrGreenMarketplace", function () {
    let DrGreenMarketplace, drGreenMarketplace, DrGreenNFT, drGreenNFT, owner, addr1, addr2;

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();

        // Deploy DrGreenNFT contract
        const DrGreenNFTFactory = await ethers.getContractFactory("DrGreenNFT");
        drGreenNFT = await DrGreenNFTFactory.deploy();
        await drGreenNFT.deployed();

        // Deploy DrGreenMarketplace contract
        const DrGreenMarketplaceFactory = await ethers.getContractFactory("DrGreenMarketplace");
        drGreenMarketplace = await DrGreenMarketplaceFactory.deploy(drGreenNFT.address);
        await drGreenMarketplace.deployed();

        // Mint an NFT to addr1
        await drGreenNFT.connect(addr1).mint(1);
    });

    it("Should allow buying an NFT with a valid signature", async function () {
        const tokenId = 1;
        const price = ethers.utils.parseEther("1");
        const salt = ethers.utils.randomBytes(32);

        // Generate signature
        const message = ethers.utils.solidityKeccak256(
            ["address", "uint256", "uint256"],
            [addr1.address, tokenId, price]
        );
        const signature = await addr1.signMessage(ethers.utils.arrayify(message));

        // Approve marketplace to transfer NFT
        await drGreenNFT.connect(addr1).setApprovalForAll(drGreenMarketplace.address, true);

        // Buy NFT
        await expect(drGreenMarketplace.connect(addr2).buyNFT(tokenId, signature, salt, { value: price }))
            .to.emit(drGreenMarketplace, "Bought")
            .withArgs(tokenId, drGreenNFT.address, price, addr1.address, addr2.address);

        // Check NFT ownership
        expect(await drGreenNFT.ownerOf(tokenId)).to.equal(addr2.address);
    });

    it("Should allow canceling a listing with a valid signature", async function () {
        const tokenId = 1;
        const price = ethers.utils.parseEther("1");
        const salt = ethers.utils.randomBytes(32);

        // Generate signature
        const message = ethers.utils.solidityKeccak256(
            ["address", "uint256", "uint256"],
            [addr1.address, tokenId, price]
        );
        const signature = await addr1.signMessage(ethers.utils.arrayify(message));

        // Cancel listing
        await expect(drGreenMarketplace.connect(addr1).cancelListing(tokenId, price, signature, salt))
            .to.emit(drGreenMarketplace, "ListingCancelled")
            .withArgs(addr1.address, tokenId, signature, await ethers.provider.getBlockNumber());
    });

    it("Should revert if signature is already used", async function () {
        const tokenId = 1;
        const price = ethers.utils.parseEther("1");
        const salt = ethers.utils.randomBytes(32);

        // Generate signature
        const message = ethers.utils.solidityKeccak256(
            ["address", "uint256", "uint256"],
            [addr1.address, tokenId, price]
        );
        const signature = await addr1.signMessage(ethers.utils.arrayify(message));

        // Approve marketplace to transfer NFT
        await drGreenNFT.connect(addr1).setApprovalForAll(drGreenMarketplace.address, true);

        // Buy NFT
        await drGreenMarketplace.connect(addr2).buyNFT(tokenId, signature, salt, { value: price });

        // Try to buy NFT again with the same signature
        await expect(drGreenMarketplace.connect(addr2).buyNFT(tokenId, signature, salt, { value: price }))
            .to.be.revertedWith("signature already used");
    });

    it("Should revert if signature is invalid", async function () {
        const tokenId = 1;
        const price = ethers.utils.parseEther("1");
        const salt = ethers.utils.randomBytes(32);

        // Generate signature with wrong owner
        const message = ethers.utils.solidityKeccak256(
            ["address", "uint256", "uint256"],
            [addr2.address, tokenId, price]
        );
        const signature = await addr2.signMessage(ethers.utils.arrayify(message));

        // Approve marketplace to transfer NFT
        await drGreenNFT.connect(addr1).setApprovalForAll(drGreenMarketplace.address, true);

        // Try to buy NFT with invalid signature
        await expect(drGreenMarketplace.connect(addr2).buyNFT(tokenId, signature, salt, { value: price }))
            .to.be.revertedWith("signature validation failed");
    });
});