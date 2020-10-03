import React, { Component } from 'react';
import {connect} from 'react-redux';
import { setToken } from './redux/actions';
import { selectedTokenSelector } from './redux/selectors';
import USM from './USM';

class USMFUM extends Component {

    render() {

        const {dispatch, selectedToken} = this.props;

        const changeSelectedToken = (e) => dispatch(setToken(e.target.value));
        
        return (
            <>
                <div className="row">
                    <div id="token-container" className="nes-container with-title is-centered">
                        <p className="title">Token</p>
                        <p>Choose the token you'd like to interact with.</p>
                        <label>
                            <input onChange={changeSelectedToken} type="radio" className="nes-radio" value="USM" name="token" />
                            <span>USM</span>
                        </label>
                        <label>
                            <input onChange={changeSelectedToken} type="radio" className="nes-radio" value="FUM" name="token" />
                            <span>FUM</span>
                        </label>
                    </div>
                </div>
                {selectedToken === "USM" ? <USM /> : "FUM GOES HERE"}
            </>
        )
    }
}

function mapStateToProps(state){
	return {
        selectedToken: selectedTokenSelector(state)
	}
}

export default connect(mapStateToProps)(USMFUM);