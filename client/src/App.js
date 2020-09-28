import React from 'react';
import {connect} from 'react-redux';
import {Col, Container, Row, Tab, Tabs} from "react-bootstrap";
import './App.scss';

function App() {
	return (
		<Container className="h-100">
			<Row className="h-100 justify-content-center align-items-center d-flex">
				<Col sm="4" className="text-center border border-thick">
					<Tabs fill className="py-2 ">
						<Tab eventKey="USM" title="USM" className="">
							<span>You have 50 USM</span>
							<Tabs fill>
								<Tab eventKey="mint" title="Mint">
									Mint form goes here...
								</Tab>
								<Tab eventKey="burn" title="Burn">
									Burn form goes here...
								</Tab>
							</Tabs>
						</Tab>
						<Tab eventKey="FUM" title="FUM">
							<span>You have 75 FUM</span>
							<Tabs fill>
								<Tab eventKey="fund" title="Fund">
									Fund form goes here...
								</Tab>
								<Tab eventKey="defund" title="Defund">
									Defund form goes here...
								</Tab>
							</Tabs>
						</Tab>
					</Tabs>
				</Col>
			</Row>
		</Container>
	);
}

function mapStateToProps(state){
	return {
	}
}

export default connect(mapStateToProps)(App);
