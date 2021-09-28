const addresses = {
    'chainlink': '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419',
    'usdcEth': '0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640',
    'ethUsdt': '0x11b815efb8f581194ae79006d24e0d814b7697f6',
    'daiEth': '0x60594a405d53811d3bc4766596efd80fd545a270',
}

const usdcEthTokenToPrice = 1
const usdcEthDecimals = -12
const ethUsdtTokenToPrice = 0
const ethUsdtDecimals = -12

module.exports = [
    addresses['chainlink'],
    addresses['usdcEth'],
    usdcEthTokenToPrice,
    usdcEthDecimals,
    addresses['ethUsdt'],
    ethUsdtTokenToPrice,
    ethUsdtDecimals,
];
