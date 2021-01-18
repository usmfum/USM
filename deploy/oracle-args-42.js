const addresses = {
    'chainlink': '0x9326BFA02ADD2366b30bacB125260Af641031331',
    'compound': '0x0000000000000000000000000000000000000000',
    'ethUsdt': '0x0000000000000000000000000000000000000000',
    'usdcEth': '0x0000000000000000000000000000000000000000',
    'daiEth': '0x0000000000000000000000000000000000000000',
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