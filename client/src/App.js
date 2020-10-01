import React, { Component } from 'react';
import {connect} from 'react-redux';
import './App.scss';
import { selectUsmForm, setMintEthValue, setMintUsmValue } from './redux/actions';
import { loadWeb3 } from './redux/interactions';
import { accountSelector, mintEthValueSelector, mintUsmValueSelector, selectedUsmFormSelector, web3Selector } from './redux/selectors';

class App extends Component {

	printUsmMint(props, changeMintEthValue, changeMintUsmValue) {
		const {mintUsmValue, mintEthValue} = props;

		return (
			<div id="mint-usm-container" className="nes-container with-title">
				<p className="title">Mint</p>
				<form id="mint-usm-form" className="">
					<div className="nes-field is-inline">
						<label htmlFor="mint-usm-eth">ETH Amount</label>
						<input id="mint-usm-eth" onChange={changeMintEthValue} value={mintEthValue} className="nes-input" type="number" min="0" step=".01" placeholder="ETH" />
					</div>
					<div className="nes-field is-inline">
						<label htmlFor="mint-usm-usm">USM Amount</label>
						<input id="mint-usm-usm" onChange={changeMintUsmValue} value={mintUsmValue} className="nes-input" type="number" min="0" step=".01" placeholder="USM" />
					</div>
					<button type="submit" className="nes-btn is-primary">Mint</button>
				</form>
			</div>
		);
	}

	printUsmRedeem(props, changeRedeemUsmValue, redeemEthValue) {
		return (
			<></>
		);
	}

	render() {
		const USM_MINT = "usm_mint";
		const USM_REDEEM = "usm_redeem";

		const {dispatch, selectedUsmForm, connected, account, mintUsmValue} = this.props;

		const connectWeb3 = (e) => loadWeb3(dispatch);
		const changeMintEthValue = (e) => dispatch(setMintEthValue(e.target.value));
		const changeMintUsmValue = (e) => dispatch(setMintUsmValue(e.target.value));
		const usmForm = (mintOrRedeem) => dispatch(selectUsmForm(mintOrRedeem));

		return (
			<div id="usm-container" className="nes-container with-title is-centered">
				<p className="title">USM</p>
				<button onClick={() => usmForm(USM_MINT)} type="button" className="nes-btn is-success">Mint</button>
				<button onClick={() => usmForm(USM_REDEEM)} type="button" className="nes-btn is-error">Redeem</button>
				{selectedUsmForm == USM_MINT ? 
					this.printUsmMint(this.props, changeMintEthValue, changeMintUsmValue)
					: 
					this.printUsmRedeem(this.props) 
				}					
			</div>
		);
	}
}

function mapStateToProps(state){
	return {
		connected: web3Selector(state),
		account: accountSelector(state),
		selectedUsmForm: selectedUsmFormSelector(state),
		mintUsmValue: mintUsmValueSelector(state),
		mintEthValue: mintEthValueSelector(state)
	}
}

export default connect(mapStateToProps)(App);
