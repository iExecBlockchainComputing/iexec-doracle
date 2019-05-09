import { ethers } from 'ethers';
import   config   from './config.js';

// import PriceOracle from 'iexec-doracle-contracts/build/contracts/PriceOracle.json';
const PriceOracle = require('../build/contracts/PriceOracle.json');

class Daemon
{
	wallet:   ethers.Wallet;
	contract: ethers.Contract;

	constructor(address: string, wallet: ethers.Wallet)
	{
		this.wallet   = wallet;
		this.contract = new ethers.Contract(address, PriceOracle.abi, this.wallet);
	}

	start()
	{
		console.log(`Starting to listen ${this.contract.address}`)
		this.contract.on("ResultReady(bytes32)", this.trigger.bind(this));
		console.log(`Daemon running ...`);
	}

	trigger(doracleCallId: string, event: {})
	{
		process.stdout.write(`${new Date().toISOString()} | processing ${doracleCallId} ...`);

		this.contract.processResult(doracleCallId)
		.then(tx => {
			process.stdout.write(` success\n`);
		})
		.catch(e => {
			const txHash = e.transactionHash;
			const data   = e.data[txHash];
			process.stdout.write(` Error: ${data.error} (${data.reason})\n`);
		});
	}
}

(async () => {

	let provider = ethers.getDefaultProvider(config.provider);
	let wallet   = new ethers.Wallet(config.wallet, provider);
	let daemon   = new Daemon(config.address, wallet);

	daemon.start();

})();
