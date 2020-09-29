import React, { Component } from 'react';
import {connect} from 'react-redux';
import {Button, Col, Container, Form, Row, Tab, Tabs} from "react-bootstrap";
import './App.scss';
import { setMintEthValue } from './redux/interactions';
import { mintEthValueSelector, mintUsmValueSelector } from './redux/selectors';

class App extends Component {

	render() {
		const {dispatch, mintEthValue} = this.props;

		const changeMintEthValue = (e) => setMintEthValue(dispatch, e.target.value);

		return (
			<Container className="h-100">
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
												<Form.Control value={mintEthValue} type="number" min="0" step=".01" placeholder="USM" />
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
		mintUsmValue: mintUsmValueSelector(state)
	}
}

export default connect(mapStateToProps)(App);
