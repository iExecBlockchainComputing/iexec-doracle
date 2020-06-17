import { ethers } from 'ethers';
import * as utils from './utils';

const IexecInterface = require('@iexec/interface/build/contracts/IexecInterfaceToken.json');
const IERC734        = require('@iexec/solidity/build/contracts/IERC734.json');
const Doracle        = require('@iexec/doracle/build/contracts/IexecDoracle.json');

export default class IexecDoracleUpdater
{
	address:   string;
	wallet:    ethers.Wallet;
	requester: string;

	doracle:    ethers.Contract;
	iexecproxy: ethers.Contract;

	settings:
	{
		authorizedApp:        string,
		authorizedDataset:    string,
		authorizedWorkerpool: string,
		requiredtag:          string,
		requiredtrust:        number,
		GROUPMEMBER_PURPOSE:  number,
	}

	constructor(address: string, wallet: ethers.Wallet, requester: string = null)
	{
		this.address   = address;
		this.wallet    = wallet;
		this.requester = requester;
	}

	async start(listener: boolean = true) : Promise<void>
	{
		console.log(`Connecting to contracts`);
		this.doracle = new ethers.Contract(this.address, Doracle.abi, this.wallet);
		console.log(`- doracle    ${this.doracle.address}`);
		this.iexecproxy = new ethers.Contract(await this.doracle.iexecproxy(), IexecInterface.abi, this.wallet.provider);
		console.log(`- iexecproxy ${this.iexecproxy.address}`);

		console.log(`Retrieving doracle settings:`);
		this.settings = {
			authorizedApp:        await this.doracle.m_authorizedApp(),
			authorizedDataset:    await this.doracle.m_authorizedDataset(),
			authorizedWorkerpool: await this.doracle.m_authorizedWorkerpool(),
			requiredtag:          await this.doracle.m_requiredtag(),
			requiredtrust:        await this.doracle.m_requiredtrust(),
			GROUPMEMBER_PURPOSE:  await this.iexecproxy.GROUPMEMBER_PURPOSE(),
		}
		console.log(`- authorizedApp:        ${this.settings.authorizedApp}`       );
		console.log(`- authorizedDataset:    ${this.settings.authorizedDataset}`   );
		console.log(`- authorizedWorkerpool: ${this.settings.authorizedWorkerpool}`);
		console.log(`- requiredtag:          ${this.settings.requiredtag}`         );
		console.log(`- requiredtrust:        ${this.settings.requiredtrust}`       );
		console.log(`- GROUPMEMBER_PURPOSE:  ${this.settings.GROUPMEMBER_PURPOSE}` );

		if (listener)
		{
			console.log(`Starting event listener.`)
			this.doracle.on("ResultReady(bytes32)", this.trigger.bind(this));
			console.log(`====== Daemon is running ======`);
		}
		else
		{
			console.log(`====== Daemon is ready ======`);
		}
	}

	async checkIdentity(identity: string, candidate: string, purpose: number): Promise<boolean>
	{
		try
		{
			return identity == candidate || await (new ethers.Contract(identity, IERC734.abi, this.wallet.provider)).keyHasPurpose(utils.addrToKey(candidate), purpose);
		}
		catch
		{
			console.log(identity, candidate)
			return false;
		}
	}

	async getVerifiedResult(doracleCallId: string) : Promise<string>
	{
		let task = await this.iexecproxy.viewTask(doracleCallId);
		let deal = await this.iexecproxy.viewDeal(task.dealid);

		if (this.requester)
		{
			utils.require(deal.requester == this.requester, "requester filtered (this is not an error)");
		}

		utils.require(task.status == 3, "result-not-available");
		utils.require(task.resultDigest == ethers.utils.keccak256(task.results), "result-not-validated-by-consensus");
		utils.require(this.settings.authorizedApp        == ethers.constants.AddressZero || await this.checkIdentity(this.settings.authorizedApp,        deal.app.pointer,        this.settings.GROUPMEMBER_PURPOSE), "unauthorized-app");
		utils.require(this.settings.authorizedDataset    == ethers.constants.AddressZero || await this.checkIdentity(this.settings.authorizedDataset,    deal.dataset.pointer,    this.settings.GROUPMEMBER_PURPOSE), "unauthorized-dataset");
		utils.require(this.settings.authorizedWorkerpool == ethers.constants.AddressZero || await this.checkIdentity(this.settings.authorizedWorkerpool, deal.workerpool.pointer, this.settings.GROUPMEMBER_PURPOSE), "unauthorized-workerpool");
		utils.require(this.settings.requiredtrust <= deal.trust, "invalid-trust");

		// Check tag - must be done byte by byte.
		let  tag = ethers.utils.arrayify(deal.tag);
		let rtag = ethers.utils.arrayify(this.settings.requiredtag);
		for (var i in tag) utils.require((rtag[i] & ~tag[i]) == 0, "invalid-tag");

		return task.results;
	}

	async checkData(data: string) : Promise<void>
	{
		// Default, not do anything
	}

	trigger(doracleCallId: string, event: {})
	{
		process.stdout.write(`${new Date().toISOString()} | processing ${doracleCallId} ... `);
		this.getVerifiedResult(doracleCallId)
		.then(data => {
			this.checkData(data)
			.then(() => {
				this.doracle.processResult(doracleCallId)
				.then(tx => {
					process.stdout.write(`success\n`);
				})
				.catch(e => {
					const txHash = e.transactionHash;
					const data   = e.data[txHash];
					process.stdout.write(`Error: ${data.error} (${data.reason})\n`);
				});
			})
			.catch(reason => {
				process.stdout.write(`Invalid results (${reason})\n`);
			});
		})
		.catch(reason => {
			process.stdout.write(`Failled to verify results (${reason})\n`);
		});
	}
}
