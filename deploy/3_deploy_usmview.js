const func = async function ({ deployments, getNamedAccounts, getChainId }) {
  const { deploy, execute, get, read } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId()

  usmAddress = (await get('USM')).address;

  const usmView = await deploy('USMView', {
    from: deployer,
    deterministicDeployment: true,
    args: [usmAddress],
  })
  console.log(`Deployed USMView to ${usmView.address}`);
};

module.exports = func;
module.exports.tags = ["USMView"];
