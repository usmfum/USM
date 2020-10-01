import {combineReducers} from 'redux';

function web3(state = {}, action) {
    switch (action.type) {
        case "WEB3_LOADED":
            return { ...state, web3: action.web3}
        case "ACCOUNT_LOADED":
            return { ...state, account: action.account}
        default:
            return state;
    }
}

function display(state = {}, action) {
    switch (action.type) {
        case 'USM_FORM_SELECTED':
            return { ...state, selectedUsmForm: action.mintOrRedeem }
        case "MINT_ETH_VALUE":
            return { ...state, mintEthValue: action.value}
        case "MINT_USM_VALUE":
            return { ...state, mintUsmValue: action.value}
        default:
            return state;
    }
}

const rootReducer = new combineReducers({
    web3, display
});

export default rootReducer;