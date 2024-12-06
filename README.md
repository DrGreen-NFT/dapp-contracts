<p align="center">
  <a href="https://www.cosmostation.io" target="_blank" rel="noopener noreferrer"><img width="100" src="https://avatars.githubusercontent.com/u/190770633?s=200&v=4" alt="Cosmostation logo"></a>
</p>
<h1 align="center">Dr. Green NFT</h1>
<h3 align="center">Join the world’s first legal cannabis on-demand delivery business with Dr. Green!</h3>

## About

Dr. Green simplifies the way cannabis is bought and sold worldwide. Using Ethereum blockchain and NFT technology as an authentication key ensures that every transaction is transparent and secure.

With Dr. Green, anyone can join the cannabis industry safely. Our digital key, stored on the blockchain, includes our medical cannabis license and through smart contracts, holders of the digital key can drop ship cannabis legally wherever it's accepted - this includes recreational and medical cannabis.

## Dr Green Community

[Website](https://drgreennft.com/)

[Marketplace](https://marketplace.drgreennft.com/)

[Telegram](https://t.me/DrGreenNFTentry)

[Discord](https://discord.com/invite/drgreen)

[Twitter](https://x.com/DrGreen_nft)

[Instagram](https://www.instagram.com/drgreen/)

[Whitepaper](https://drgreennft.com/assets/drgreen_whitepaper_2024.pdf)

## Overview

This project is built using Hardhat, an Ethereum smart contract development environment. It includes a different smart contract required for NFT Mining and Trading, a deployment script, and a testing framework.

## Project Structure

```
my-hardhat-project/
├── contracts/          # Solidity smart contracts
│   └── MyContract.sol  # Your custom contract
├── scripts/            # Deployment scripts
│   └── deploy.js       # Sample deployment script
├── test/               # Test scripts for smart contracts
│   └── MyContract.js   # Sample test for MyContract
├── artifacts/          # Compiled contract files (auto-generated)
├── cache/              # Cache files (auto-generated)
├── hardhat.config.js   # Hardhat configuration file
└── package.json        # Project dependencies and scripts
```

## Prerequisites

Ensure the following are installed:

1. Node.js (v16 or later)
2. npm (Node Package Manager)

## Setup Instructions

1. Clone the Repository
```
git clone <repository-url>
cd my-hardhat-project
```

2. Install Dependencies
```
npm install
```

3. Compile the Contracts
```
npx hardhat compile
```

4. Run Tests
Run the test scripts in the test/ directory:
```
npx hardhat test
```

5. Deploy the Contracts
To deploy the contracts on a local network:
```
npx hardhat run scripts/deploy.js
```
To deploy on a specific network (e.g., Ethereum Testnets):

Configure your hardhat.config.js with the desired network.
Deploy using:
```
npx hardhat run scripts/deploy.js --network <network-name>
```

6. Run a Local Node
To simulate a blockchain locally:
```
npx hardhat node
```

## Configuration
Customize your hardhat.config.js for additional settings:

- Adding networks (e.g., Rinkeby, Goerli).
- Adjusting Solidity versions.
- Configuring plugins like Etherscan or Gas Reporter.

## Dependencies
This project uses:

- Hardhat: Ethereum development environment.
- Ethers.js: Ethereum interaction library.
- Mocha and Chai: Testing framework.
Install additional plugins if required:
```
npm install --save-dev @nomiclabs/hardhat-ethers ethers
npm install --save-dev @nomiclabs/hardhat-waffle
npm install --save-dev @nomiclabs/hardhat-etherscan
```

## License
Copyright © Dr. Green NFT. All rights reserved.

Licensed under the [MIT](LICENSE.md).
