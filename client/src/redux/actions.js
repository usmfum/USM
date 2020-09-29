export function web3Loaded(web3) {
    return {
        type: 'WEB3_LOADED',
        web3
    }
}

export function mintEthValue(value) {
    return {
        type: 'MINT_ETH_VALUE',
        value
    }
}

export function mintUsmValue(value) {
    return {
        type: 'MINT_USM_VALUE',
        value
    }
}