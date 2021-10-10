const addresses = {
    'chainlink': '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419',
    'usdcEth': '0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640',
    'ethUsdt': '0x11b815efB8f581194ae79006d24E0d814B7697F6',
    'daiEth': '0x60594a405d53811d3BC4766596EFD80fd545A270',
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
