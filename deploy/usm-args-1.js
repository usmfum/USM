const addresses = {
    'oracle': '',
    'USMv0.1': '0x03eb7Ce2907e202bB70BAE3D7B0C588573d3cECC',
    'FUMv0.1': '0xf04a5D82ff8a801f7d45e9C14CDcf73defF1a394',
}
  
module.exports = [
    addresses['oracle'],
    [
        addresses['USMv0.1'],
        addresses['FUMv0.1'],
    ],
];