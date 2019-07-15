import { ethers } from 'ethers';
import * as utils from '../utils';
import IexecDoracleUpdater from '../IexecDoracleUpdater';

export default class IexecDoracleUpdater_PriceFeed extends IexecDoracleUpdater
{
	async checkData(data: string) : Promise<void>
	{
		let [ date, details, value ] = ethers.utils.defaultAbiCoder.decode(["uint256", "string", "uint256"], data);
		let entry = await this.doracle.values(ethers.utils.solidityKeccak256(["string"],[details]));
		utils.require(entry.date < date, "new-value-is-too-old");
	}
}
