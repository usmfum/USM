const addresses = {
    'USMv0.1': '0x21453979384f21D09534f8801467BDd5d90eCD6C',        // kovan (2020/12/11)
    'FUMv0.1': '0x96F8F5323Aa6CB0e6F311bdE6DEEFb1c81Cb1898',        // kovan (2020/12/11)
    'USMv0.2': '0x03eb7Ce2907e202bB70BAE3D7B0C588573d3cECC',        // mainnet (2020/12/16)
    'FUMv0.2': '0xf04a5D82ff8a801f7d45e9C14CDcf73defF1a394',        // mainnet (2020/12/16)
    'USMv0.3-rc1': '0xf05627D4F72bC4778BAECcbeaCa44b013e9b8227',    // kovan (2021/01/19)
    'FUMv0.3-rc1': '0xE13b57555E5A538785130FDa6E918185b9fE1599',    // kovan (2021/01/19)
    'USMv0.3': '0x6dcc375aE1f43c8FA4e13D56E6ec584BeE25A88F',        // kovan (2021/02/03)
    'FUMv0.3': '0xf99B440d8E18F850187aE53Cdd4EBc959EbF36dF',        // kovan (2021/02/03)
    'USMv0.4-rc1': '0x19b490DAA2B58d9B12BFb15Cd3eFC2358ad2Bd67',    // kovan (2021/02/10)
    'FUMv0.4-rc1': '0x0f682F36363b4cd5261Dd613F4CAeC6E6C8a5eef',    // kovan (2021/02/10)
    'USMv0.4': '0x7dbC406E09c876C77949A45BBE4173Aa6CdF9470',        // kovan (2021/03/14)
    'FUMv0.4': '0x6Ee47863a96a488a53053Dea290CcF7f8979d6A9',        // kovan (2021/03/14)
    'USMv0.5': '0x7816f1Ac2a8b8A2Ead4Bf5fE0B946a343C3282d6',        // mainnet (2021/10/04)
    'FUMv0.5': '0x1d87CbD8df28729Ac12f5AfD0464Eb54C2870F95',        // mainnet (2021/10/04)
}

module.exports = [
    [
        addresses['USMv0.1'],
        addresses['FUMv0.1'],
        addresses['USMv0.2'],
        addresses['FUMv0.2'],
        addresses['USMv0.3-rc1'],
        addresses['FUMv0.3-rc1'],
        addresses['USMv0.3'],
        addresses['FUMv0.3'],
        addresses['USMv0.4-rc1'],
        addresses['FUMv0.4-rc1'],
        addresses['USMv0.4'],
        addresses['FUMv0.4'],
        addresses['USMv0.5'],
        addresses['FUMv0.5'],
    ],
    [], // None of these addresses are both 1. live on kovan and 2. implement OptOutable, so don't try calling optOut() on them
];
