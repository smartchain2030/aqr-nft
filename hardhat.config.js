require("dotenv").config();
const { utils, ethers } = require("ethers");
const fs = require("fs");
const chalk = require("chalk");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");

const defaultNetwork = "localhost"; // "hardhat" for tests
const API = process.env.MATIC_NODE_API;
const PRIVATE_KEY = process.env.PRIVATEKEY;

module.exports = {
  defaultNetwork,
  networks: {
    localhost: {
      url: "http://localhost:8545", // uses account 0 of the hardhat node to deploy
    },
    mainnet: {
      url: API,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    rinkeby: {
      url: API,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    kovan: {
      url: API,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    ropsten: {
      url: API,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    goerli: {
      url: "https://goerli.infura.io/v3/63273290f2b64f1d956e2a607d17b196",
      accounts: [`0x${PRIVATE_KEY}`],
    },
    mumbai: {
      url: `https://rpc-mumbai.maticvigil.com`,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    matic: {
      url: `https://rpc-mainnet.maticvigil.com`,
      accounts: [`0x${PRIVATE_KEY}`],
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.7.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.6.11",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};

task("accounts", "Prints the list of accounts", async () => {
  if (defaultNetwork === "localhost") {
    const provider = new ethers.providers.JsonRpcProvider(
      "http://127.0.0.1:8545/"
    );
    const accounts = await provider.listAccounts();
    for (let i = 0; i < accounts.length; i++) {
      const accountBalance = await provider.getBalance(accounts[i]);
      console.log(
        "📄",
        chalk.cyan(accounts[i]),
        "💸",
        chalk.magenta(utils.formatEther(accountBalance), "ETH")
      );
    }
    console.log("\n");
  } else {
    console.log(
      " ⚠️  This task only runs on JsonRpcProvider running a node at " +
        chalk.magenta("localhost:8545") +
        "\n"
    );
  }
});
