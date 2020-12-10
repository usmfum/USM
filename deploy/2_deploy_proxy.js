
const func = async function ({ deployments, getNamedAccounts, getChainId }) {
  const { deploy, get, read, execute } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId()

  let wethAddress

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

  const usmAddress = (await get('USM')).address;

  const proxy = await deploy('Proxy', {
    from: deployer,
    deterministicDeployment: true,
    args: [usmAddress, wethAddress]
  })

  console.log(`Deployed Proxy to ${proxy.address}`);
}

module.exports = func;