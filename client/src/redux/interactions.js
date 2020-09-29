import { mintEthValue, web3Loaded, accountLoaded } from "./actions";
import {getWeb3} from "../getWeb3";


export const loadWeb3 = async (dispatch) => {
    const web3 = await getWeb3();
    dispatch(web3Loaded(web3));
    loadWallet(dispatch, web3);
    return web3;
}

export const loadWallet = async (dispatch, web3) => {
    const accounts = await web3.eth.getAccounts();
    const account = accounts[0];
    dispatch(accountLoaded(account));
    return account;
}

export const setMintEthValue = async (dispatch, value) => {
    dispatch(mintEthValue(value));
    return value;
}