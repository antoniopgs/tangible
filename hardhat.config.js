/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.18",
  networks: {
    hardhat: {
      forking: {
        url: "https://mainnet.infura.io/v3/f36750d69d314e3695b7fe230bb781af"
      }
    }
  }
};
