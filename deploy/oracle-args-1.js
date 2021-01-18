const addresses = {
    'chainlink': '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419',
    'compound': '0x922018674c12a7f0d394ebeef9b58f186cde13c1',
    'ethUsdt': '0x0d4a11d5eeaac28ec3f61d100daf4d40471f1852',
    'usdcEth': '0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc',
    'daiEth': '0xa478c2975ab1ea89e8196811f51a7b7ade33eb11',
}
  
const usdcDecimals = 6                                      // See UniswapMedianOracle
const ethDecimals = 18                                      // See UniswapMedianOracle
const uniswapTokensInReverseOrder = true                    // See UniswapMedianOracle

module.exports = [
    addresses['chainlink'],
    addresses['compound'],
    addresses['usdcEth'],
    usdcDecimals,
    ethDecimals,
    uniswapTokensInReverseOrder,
];