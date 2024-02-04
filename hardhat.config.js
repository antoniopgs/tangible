require('hardhat-contract-sizer');
require("@nomiclabs/hardhat-waffle");
require('dotenv').config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.19",
  networks: {
    hardhat: {
      forking: {
        url: "https://mainnet.infura.io/v3/f36750d69d314e3695b7fe230bb781af"
      }
    },
    polygonMumbai: {
      url: "https://polygon-mumbai.g.alchemy.com/v2/aK8s83vhhzG8PbGyJqLi160PgWD_9IbX",
      accounts: {
        mnemonic: process.env.MNEMONIC,
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 20,
        passphrase: "",
      }
    },
    sepolia: {
      url: "https://eth-sepolia.g.alchemy.com/v2/y7BrjLoYar43xDMfT298ttTLMcW4jTmu",
      // url: "https://sepolia.infura.io/v3/4fe4075685794edc8349a620aad0121e",
      accounts: {
        mnemonic: process.env.MNEMONIC,
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 20,
        passphrase: "",
      }
      // gasPrice: 50000
    }
  },
  contractSizer: {
    runOnCompile: true
  }
};