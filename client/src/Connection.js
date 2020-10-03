import React, { Component } from 'react';
import {connect} from 'react-redux';
import { loadWeb3 } from './redux/interactions';

class Connection extends Component
{
    render() {
        const {dispatch} = this.props;

        const connectWeb3 = (e) => loadWeb3(dispatch);

        return (
            <div id="connection-container" className="nes-container with-title is-centered">
                <p className="title">Connect</p>
                <p>Connect your Ethereum wallet</p>
                <button onClick={connectWeb3} type="button" className="nes-btn is-primary">Connect</button>				
            </div>
        );
    }
}

function mapStateToProps(state){
	return {
	}
}

export default connect(mapStateToProps)(Connection);