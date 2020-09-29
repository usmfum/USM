import { mintEthValue, web3Loaded } from "./actions";
import {getWeb3} from "../getWeb3";


export const loadWeb3 = async (dispatch) => {
    const web3 = await getWeb3();
    dispatch(web3Loaded(web3));
    return web3;
}

export const setMintEthValue = async (dispatch, value) => {
    dispatch(mintEthValue(value));
    return value;
}