const fs = require('fs')
const path = require('path')
require('@nomiclabs/hardhat-truffle5')
require('solidity-coverage')
require('hardhat-gas-reporter')
require('hardhat-deploy')
require('@nomiclabs/hardhat-etherscan')


// REQUIRED TO ENSURE METADATA IS SAVED IN DEPLOYMENTS (because solidity-coverage disable it otherwise)
const {
  TASK_COMPILE_GET_COMPILER_INPUT
} = require("hardhat/builtin-tasks/task-names");
task(TASK_COMPILE_GET_COMPILER_INPUT).setAction(async (_, bre, runSuper) => {
  const input = await runSuper();
  input.settings.metadata.useLiteralContent = bre.network.name !== "coverage";
  return input;
})


function nodeUrl(network) {
  let infuraKey
  try {
    infuraKey = fs.readFileSync(path.resolve(__dirname, '.infuraKey')).toString().trim()
  } catch(e) {
    infuraKey = ''
  }
  return `https://${network}.infura.io/v3/${infuraKey}`
}

let mnemonic = process.env.MNEMONIC;
if (!mnemonic) {
  try {
    mnemonic = fs.readFileSync(path.resolve(__dirname, '.secret')).toString().trim()
  } catch(e){}
}
const accounts = mnemonic ? {
  mnemonic,
}: undefined;

let etherscanKey = process.env.ETHERSCANKEY;
if (!etherscanKey) {
  try {
    etherscanKey = fs.readFileSync(path.resolve(__dirname, '.etherscanKey')).toString().trim()
  } catch(e){}
}

module.exports = {
  defaultNetwork: 'hardhat',
  networks: {
    kovan: {
      accounts,
      url: nodeUrl('kovan')
    },
    goerli: {
      accounts,
      url: nodeUrl('goerli'),
    },
    rinkeby: {
      accounts,
      url: nodeUrl('rinkeby')
    },
    ropsten: {
      accounts,
      url: nodeUrl('ropsten')
    },
    mainnet: {
      accounts,
      url: nodeUrl('mainnet'),
      gasPrice: 51000000000
    },
    coverage: {
      url: 'http://127.0.0.1:8555',
    },
  },
  etherscan: {
    apiKey: etherscanKey
  },
  solidity: {
    version: '0.8.9',
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000000,
      }
    }
  },
  gasReporter: {
    enabled: true,
  },
  paths: {
    sources: './contracts',
    tests: './test',
    cache: './cache',
    coverage: './coverage',
    coverageJson: './coverage.json',
    artifacts: './artifacts',
  },
  namedAccounts: {
    deployer: 0
  }
}
