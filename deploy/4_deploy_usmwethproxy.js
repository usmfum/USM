const func = async function ({ deployments, getNamedAccounts, getChainId }) {
  const { deploy, get, read, execute } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId()

  const wethAddresses = {
    '1' : '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
    '42' : '0xa1C74a9A3e59ffe9bEe7b85Cd6E91C0751289EbD',
  }

  let wethAddress, usmAddress

  if (chainId === '31337') { // buidlerevm's chainId
    weth = await deploy('WETH9', {
      from: deployer,
      deterministicDeployment: true
    })
    wethAddress = weth.address
  }
  else {
    wethAddress = wethAddresses[chainId]
  }

  usmAddress = (await get('USM')).address;

  const proxy = await deploy('USMWETHProxy', {
    from: deployer,
    deterministicDeployment: true,
    args: [usmAddress, wethAddress]
  })

  console.log(`Deployed USMWETHProxy to ${proxy.address}`);
}

module.exports = func;
module.exports.tags = ["USMWETHProxy"];
