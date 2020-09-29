import React, { Component } from 'react';
import {connect} from 'react-redux';
import {Button, Col, Container, Form, Navbar, Row, Tab, Tabs} from "react-bootstrap";
import './App.scss';
import { loadWeb3, setMintEthValue } from './redux/interactions';
import { accountSelector, mintEthValueSelector, mintUsmValueSelector, web3Selector } from './redux/selectors';

class App extends Component {

	render() {
		const {dispatch, connected, account, mintUsmValue} = this.props;

		const changeMintEthValue = (e) => setMintEthValue(dispatch, e.target.value);
		const connectWeb3 = (e) => loadWeb3(dispatch);

		return (
			<Container className="h-100">
				<header className="fixed-top d-relative">
					<Button id="connect-button" className="float-right text-truncate" onClick={connectWeb3}>{(connected == null) ? "Connect" : account}</Button>
				</header>
				<Row className="h-100 justify-content-center align-items-center d-flex">
					<Col xs="8" sm="6" md="4" className="text-center border border-thick">
						<Tabs fill className="py-2 ">
							<Tab eventKey="USM" title="USM" className="">
								<span>You have 50 USM</span>
								<Tabs fill className="py-2 ">
									<Tab eventKey="mint" title="Mint">
										<span>Mint USM</span>
										<Form className="py-2">
											<Form.Group>
												<Form.Control onChange={changeMintEthValue} type="number" min="0" step=".01" placeholder="ETH" />
											</Form.Group>
											<Form.Group>
												<Form.Control value={mintUsmValue} type="number" min="0" step=".01" placeholder="USM" />
											</Form.Group>
											<Button type="submit" variant="primary">Go</Button>
										</Form>
									</Tab>
									<Tab eventKey="burn" title="Burn">
										<span>Burn USM</span>
										<Form className="py-2">
											<Form.Group>
												<Form.Control type="number" min="0" step=".01" placeholder="USM" />
											</Form.Group>
											<Form.Group>
												<Form.Control type="number" min="0" step=".01" placeholder="ETH" />
											</Form.Group>
											<Button type="submit" variant="primary">Go</Button>
										</Form>
									</Tab>
								</Tabs>
							</Tab>
							<Tab eventKey="FUM" title="FUM">
								<span>You have 75 FUM</span>
								<Tabs fill className="py-2 ">
									<Tab eventKey="fund" title="Fund">
										<span>Fund with ETH</span>
										<Form className="py-2">
											<Form.Group>
												<Form.Control type="number" min="0" step=".01" placeholder="ETH" />
											</Form.Group>
											<Form.Group>
												<Form.Control type="number" min="0" step=".01" placeholder="FUM" />
											</Form.Group>
											<Button type="submit" variant="primary">Go</Button>
										</Form>
									</Tab>
									<Tab eventKey="defund" title="Defund">
										<span>Defund FUM</span>
										<Form className="py-2">
											<Form.Group>
												<Form.Control type="number" min="0" step=".01" placeholder="FUM" />
											</Form.Group>
											<Form.Group>
												<Form.Control type="number" min="0" step=".01" placeholder="ETH" />
											</Form.Group>
											<Button type="submit" variant="primary">Go</Button>
										</Form>
									</Tab>
								</Tabs>
							</Tab>
						</Tabs>
					</Col>
				</Row>
			</Container>
		);
	}
}

function mapStateToProps(state){
	return {
		connected: web3Selector(state),
		account: accountSelector(state),
		mintUsmValue: mintUsmValueSelector(state)
	}
}

export default connect(mapStateToProps)(App);
