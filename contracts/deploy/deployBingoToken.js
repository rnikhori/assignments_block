const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer);

  const BingoToken = await ethers.getContractFactory("BingoToken");

  // Deploy the contract
  const bingoToken = await BingoToken.deploy();
  console.log("Waiting for contract to be mined...");
  //await bingoToken.deployTransaction.wait();

  console.log("BingoToken deployed to address:", bingoToken.address);

  // Optionally mint tokens if required
  await bingoToken.mint();
  console.log("Minted 1 token to the deployer address");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });
