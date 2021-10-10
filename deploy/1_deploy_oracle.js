const chainlinkAddresses = {
  '1' : '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419',
  '42' : '0x9326BFA02ADD2366b30bacB125260Af641031331',
}
const usdcEthAddresses = {
  '1' : '0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640',
}
const ethUsdtAddresses = {
  '1' : '0x11b815efB8f581194ae79006d24E0d814B7697F6',
}
const daiEthAddresses = {
  '1' : '0x60594a405d53811d3BC4766596EFD80fd545A270',
}

const func = async function ({ deployments, getNamedAccounts, getChainId }) {
  const { deploy, read, execute } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId()

  const usdcEthTokenToPrice = 1
  const usdcEthDecimals = -12
  const ethUsdtTokenToPrice = 0
  const ethUsdtDecimals = -12

  let aggregator, usdcEthPool, ethUsdtPool
  let aggregatorAddress, usdcEthPoolAddress, ethUsdtPoolAddress

  if (chainId === '31337') { // buidlerevm's chainId
    const chainlinkPrice = '309647000000' // 8 dec places: see ChainlinkOracle
    const chainlinkTime = '1613550219' // Timestamp ("updatedAt") of the Chainlink price

    const usdcEthTimestamp0 = '1632203136'
    const usdcEthTickCum0 = '2357826690419'
    const usdcEthTimestamp1 = '1632203736'
    const usdcEthTickCum1 = '2357944474677'

    const ethUsdtTimestamp0 = '1632453299'
    const ethUsdtTickCum0 = '-2406882279470'
    const ethUsdtTimestamp1 = '1632453899'
    const ethUsdtTickCum1 = '-2406999836487'

    aggregator = await deploy('MockChainlinkAggregatorV3', {
      from: deployer,
      deterministicDeployment: true,
    });
    await execute('MockChainlinkAggregatorV3', { from: deployer }, 'set', chainlinkPrice, chainlinkTime)
    console.log(`Deployed MockChainlinkAggregatorV3 to ${aggregator.address}`);
    aggregatorAddress = aggregator.address

    usdcEthPool = await deploy('MockUniswapV3Pool', {
      from: deployer,
      deterministicDeployment: true,
    });
    await execute('MockUniswapV3Pool', { from: deployer }, 'setObservation', '0', usdcEthTimestamp0, usdcEthTickCum0)
    await execute('MockUniswapV3Pool', { from: deployer }, 'setObservation', '1', usdcEthTimestamp1, usdcEthTickCum1)
    console.log(`Deployed MockUniswapV3Pool to ${usdcEthPool.address}`);
    usdcEthPoolAddress = usdcEthPool.address

    ethUsdtPool = await deploy('MockUniswapV3Pool', {
      from: deployer,
      deterministicDeployment: true,
    });
    await execute('MockUniswapV3Pool', { from: deployer }, 'setObservation', '0', ethUsdtTimestamp0, ethUsdtTickCum0)
    await execute('MockUniswapV3Pool', { from: deployer }, 'setObservation', '1', ethUsdtTimestamp1, ethUsdtTickCum1)
    console.log(`Deployed MockUniswapV3Pool to ${ethUsdtPool.address}`);
    ethUsdtPoolAddress = ethUsdtPool.address

    const oracle = await deploy('MedianOracle', {
      from: deployer,
      deterministicDeployment: true,
      args: [
        aggregatorAddress,
        usdcEthPoolAddress,
        usdcEthTokenToPrice,
        usdcEthDecimals,
        ethUsdtPoolAddress,
        ethUsdtTokenToPrice,
        ethUsdtDecimals,
      ],
    })
    console.log(`Deployed MedianOracle to ${oracle.address}`);

  } else if (chainId === '42') {
    const oracle = await deploy('MockChainlinkOracle', {
      from: deployer,
      deterministicDeployment: true,
      args: [chainlinkAddresses[chainId]],
    })
    console.log(`Deployed MockChainlinkOracle to ${oracle.address}`);

  } else { // mainnet
    const oracle = await deploy('MedianOracle', {
      from: deployer,
      deterministicDeployment: true,
      args: require(`./oracle-args-${chainId}`),
    })
    console.log(`Deployed MedianOracle to ${oracle.address}`);
  }
};

module.exports = func;
module.exports.tags = ["Oracle"];
