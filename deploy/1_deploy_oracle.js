
const chainlinkAddresses = {
  '1' : '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419',
  '42' : '0x9326BFA02ADD2366b30bacB125260Af641031331',
}
const compoundAddresses = {
  '1' : '0x922018674c12a7f0d394ebeef9b58f186cde13c1',
  '42' : '0x0000000000000000000000000000000000000000',
}
const ethUsdtAddresses = {
  '1' : '0x0d4a11d5eeaac28ec3f61d100daf4d40471f1852',
  '42' : '0x0000000000000000000000000000000000000000',
}
const usdcEthAddresses = {
  '1' : '0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc',
  '42' : '0x0000000000000000000000000000000000000000',
}
const daiEthAddresses = {
  '1' : '0xa478c2975ab1ea89e8196811f51a7b7ade33eb11',
  '42' : '0x0000000000000000000000000000000000000000',
}

const func = async function ({ deployments, getNamedAccounts, getChainId }) {
  const { deploy, read, execute } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId()

  //const uniswapTokens0Decimals = [18, 6, 18]                // ETH/USDT, USDC/ETH, DAI/ETH.  See OurUniswapV2TWAPOracle
  //const uniswapTokens1Decimals = [6, 18, 18]                // See UniswapMedianOracle
  //const uniswapTokensInReverseOrder = [false, true, true]   // See UniswapMedianOracle
  const usdcDecimals = 6                                      // See UniswapMedianOracle
  const ethDecimals = 18                                      // See UniswapMedianOracle
  const uniswapTokensInReverseOrder = true                    // See UniswapMedianOracle

  let aggregator, anchoredView, usdcEthPair
  let aggregatorAddress, anchoredViewAddress, usdcEthPairAddress

  if (chainId === '31337') { // buidlerevm's chainId
    const chainlinkPrice = '38598000000' // 8 dec places: see ChainlinkOracle
    const compoundPrice = '414174999' // 6 dec places: see CompoundOpenOracle
    const usdcEthCumPrice0 = '307631784275278277546624451305316303382174855535226'
    const usdcEthCumPrice1 = '31377639132666967530700283664103'

    aggregator = await deploy('MockChainlinkAggregatorV3', {
      from: deployer,
      deterministicDeployment: true,
    });
    await execute('MockChainlinkAggregatorV3', { from: deployer }, 'set', chainlinkPrice)
    console.log(`Deployed MockChainlinkAggregatorV3 to ${aggregator.address}`);
    aggregatorAddress = aggregator.address

    anchoredView = await deploy('MockUniswapAnchoredView', {
      from: deployer,
      deterministicDeployment: true,
    });
    await execute('MockUniswapAnchoredView', { from: deployer }, 'set', compoundPrice)
    console.log(`Deployed MockUniswapAnchoredView to ${anchoredView.address}`);
    anchoredViewAddress = anchoredView.address

    usdcEthPair = await deploy('MockUniswapV2Pair', {
      from: deployer,
      deterministicDeployment: true,
    });
    await execute('MockUniswapV2Pair', { from: deployer }, 'setCumulativePrices', usdcEthCumPrice0, usdcEthCumPrice1)
    console.log(`Deployed MockUniswapV2Pair to ${usdcEthPair.address}`);
    usdcEthPairAddress = usdcEthPair.address
  } else {
    aggregatorAddress = chainlinkAddresses[chainId]
    anchoredViewAddress = compoundAddresses[chainId]
    usdcEthPairAddress = usdcEthAddresses[chainId]
  }

  const oracle = await deploy('MedianOracle', {
    from: deployer,
    deterministicDeployment: true,
    args: require(`./oracle-args-${chainId}`),
  })
  console.log(`Deployed Oracle to ${oracle.address}`);
};

module.exports = func;
module.exports.tags = ["Oracle"];
