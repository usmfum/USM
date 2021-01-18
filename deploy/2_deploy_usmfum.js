const func = async function ({ deployments, getNamedAccounts, getChainId }) {
  const { deploy, execute, get, read } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId()

  oracleAddress = (await get('MedianOracle')).address;

  const usm = await deploy('USM', {
    from: deployer,
    deterministicDeployment: true,
    args: [oracleAddress],
  })
  console.log(`Deployed USM to ${usm.address}`);
};

module.exports = func;
module.exports.tags = ["USM"];
