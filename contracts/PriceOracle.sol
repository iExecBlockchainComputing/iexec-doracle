pragma solidity ^0.5.7;
pragma experimental ABIEncoderV2;

import "./IexecDoracle.sol";

contract PriceOracle is Ownable, IexecDoracle
{
	struct timedValue
	{
		uint256 date;
		string  details;
		uint256 value;
	}

	mapping(bytes32 => timedValue) public values;

	event ValueChange(bytes32 indexed id, uint256 oldDate, uint256 oldValue, uint256 newDate, uint256 newValue);

	// ================[ IexecHub 3.0.30 ]================
	// Mainnet: TDB
	// Kovan:   0xC75f4909185f712F2795563B956CCF62b76A6e13
	// ===================================================
	constructor(IexecHub _iexecHub) public IexecDoracle(_iexecHub)
	{
	}

	function updateEnv(
	  address _authorizedApp
	, address _authorizedDataset
	, address _authorizedWorkerpool
	, bytes32 _requiredtag
	, uint256 _requiredtrust
	)
	public onlyOwner
	{
		_iexecDoracleUpdateSettings(_authorizedApp, _authorizedDataset, _authorizedWorkerpool, _requiredtag, _requiredtrust);
	}


	function decodeResults(bytes memory results) public pure returns(uint256, string memory, uint256)
	{ return abi.decode(results, (uint256, string, uint256)); }

	function processResult(bytes32 _oracleCallId)
	public
	{
		uint256       date;
		string memory details;
		uint256       value;

		// Parse results
		(date, details, value) = decodeResults(_iexecDoracleGetVerifiedResult(_oracleCallId));

		// Process results
		bytes32 id = keccak256(bytes(details));
		if (values[id].date < date)
		{
			emit ValueChange(id, values[id].date, values[id].value, date, value);
			values[id].date    = date;
			values[id].details = details;
			values[id].value   = value;
		}
	}

}
