require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy");
require('dotenv').config();

/** @type import('hardhat/config').HardhatUserConfig */
const DEPLOYER_PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY;
ARCHIVE_NODE_sepolia="https://eth-sepolia.g.alchemy.com/v2/zh1DkqIB68yovl-K3hBVFa9Wo09DVYWe"
module.exports = {
  solidity: "0.8.27",
  networks: {
    sepolia: {
      url: process.env.ARCHIVE_NODE_sepolia || "https://ethereum-sepolia.blockpi.network/v1/rpc/public",
      chainId: 11155111,
      accounts: DEPLOYER_PRIVATE_KEY ? [`0x${DEPLOYER_PRIVATE_KEY}`] : [],
    },
 
},
etherscan: { 
  apiKey: process.env.ETHERSCAN_API_KEY,  
},
};
