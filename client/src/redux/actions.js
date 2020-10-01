export function selectUsmForm(mintOrRedeem){
    return {
        type: 'USM_FORM_SELECTED',
        mintOrRedeem
    }
}

export function web3Loaded(web3) {
    return {
        type: 'WEB3_LOADED',
        web3
    }
}

export function accountLoaded(account) {
    return {
        type: 'ACCOUNT_LOADED',
        account
    }
}

export function setMintEthValue(value) {
    return {
        type: 'MINT_ETH_VALUE',
        value
    }
}

export function setMintUsmValue(value) {
    return {
        type: 'MINT_USM_VALUE',
        value
    }
}