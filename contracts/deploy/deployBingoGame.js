const { ethers, network } = require("hardhat");

async function main() {
    // Get the deployer's account
    const [deployer] = await ethers.getSigners();
   
    console.log("Deploying contracts with the account:", deployer.address);

    // Get the contract factory for Bingo
    const Bingo = await ethers.getContractFactory("Bingo");

    // Deploy the contract with constructor arguments
    const bingo = await Bingo.deploy("0x1708a1a0fB35a88482DedAf78D3784c8D753136c");

    console.log("Waiting for contract to be mined...");

    // Wait for transaction to be confirmed (optional)
    //await bingo.deployTransaction.wait(network.config.blockConfirmations || 1);

   await new Promise((resolve => setTimeout(resolve,10000)));
    console.log("BingoToken deployed to address:", bingo.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Deployment failed:", error);
        process.exit(1);
    });
