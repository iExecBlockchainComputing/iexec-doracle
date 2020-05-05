pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@iexec/interface/contracts/WithIexecToken.sol";
import "@iexec/solidity/contracts/ERC734/IERC734.sol";


contract IexecDoracle is WithIexecToken
{
	address public m_authorizedApp;
	address public m_authorizedDataset;
	address public m_authorizedWorkerpool;
	bytes32 public m_requiredtag;
	uint256 public m_requiredtrust;

	constructor(address _iexecproxy)
	public WithIexecToken(_iexecproxy)
	{}

	function _iexecDoracleUpdateSettings(
		address _authorizedApp,
		address _authorizedDataset,
		address _authorizedWorkerpool,
		bytes32 _requiredtag,
		uint256 _requiredtrust)
	internal
	{
		m_authorizedApp        = _authorizedApp;
		m_authorizedDataset    = _authorizedDataset;
		m_authorizedWorkerpool = _authorizedWorkerpool;
		m_requiredtag          = _requiredtag;
		m_requiredtrust        = _requiredtrust;
	}

	function _iexecDoracleGetResults(bytes32 _doracleCallId)
	internal view returns (bool, bytes memory)
	{
		IexecLibCore_v5.Task memory task    = iexecproxy.viewTask(_doracleCallId);
		IexecLibCore_v5.Deal memory deal    = iexecproxy.viewDeal(task.dealid);
		uint256                     purpose = iexecproxy.groupmember_purpose();

		if (task.status   != IexecLibCore_v5.TaskStatusEnum.COMPLETED                                                        ) { return (false, bytes("result-not-available"             ));  }
		if (deal.callback != address(this)                                                                                   ) { return (false, bytes("result-not-validated-for-callback"));  }
		if (m_authorizedApp        != address(0) && !_checkIdentity(m_authorizedApp,        deal.app.pointer,        purpose)) { return (false, bytes("unauthorized-app"                 ));  }
		if (m_authorizedDataset    != address(0) && !_checkIdentity(m_authorizedDataset,    deal.dataset.pointer,    purpose)) { return (false, bytes("unauthorized-dataset"             ));  }
		if (m_authorizedWorkerpool != address(0) && !_checkIdentity(m_authorizedWorkerpool, deal.workerpool.pointer, purpose)) { return (false, bytes("unauthorized-workerpool"          ));  }
		if (m_requiredtag & ~deal.tag != bytes32(0)                                                                          ) { return (false, bytes("invalid-tag"                      ));  }
		if (m_requiredtrust > deal.trust                                                                                     ) { return (false, bytes("invalid-trust"                    ));  }
		return (true, task.results);
	}

	function _iexecDoracleGetVerifiedResult(bytes32 _doracleCallId)
	internal view returns (bytes memory)
	{
		(bool success, bytes memory results) = _iexecDoracleGetResults(_doracleCallId);
		require(success, string(results));
		return results;
	}

	function _checkIdentity(address _identity, address _candidate, uint256 _purpose)
	internal view returns (bool valid)
	{
		return _identity == _candidate || IERC734(_identity).keyHasPurpose(bytes32(uint256(_candidate)), _purpose); // Simple address || ERC 734 identity contract
	}
}
