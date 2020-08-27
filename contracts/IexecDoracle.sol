// SPDX-License-Identifier: Apache-2.0

/******************************************************************************
 * Copyright 2020 IEXEC BLOCKCHAIN TECH                                       *
 *                                                                            *
 * Licensed under the Apache License, Version 2.0 (the "License");            *
 * you may not use this file except in compliance with the License.           *
 * You may obtain a copy of the License at                                    *
 *                                                                            *
 *     http://www.apache.org/licenses/LICENSE-2.0                             *
 *                                                                            *
 * Unless required by applicable law or agreed to in writing, software        *
 * distributed under the License is distributed on an "AS IS" BASIS,          *
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   *
 * See the License for the specific language governing permissions and        *
 * limitations under the License.                                             *
 ******************************************************************************/

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
		IexecLibCore_v5.Task memory task = iexecproxy.viewTask(_doracleCallId);
		IexecLibCore_v5.Deal memory deal = iexecproxy.viewDeal(task.dealid);

		if (task.status   != IexecLibCore_v5.TaskStatusEnum.COMPLETED                                                  ) { return (false, bytes("result-not-available"             ));  }
		if (deal.callback != address(this)                                                                             ) { return (false, bytes("result-not-validated-for-callback"));  }
		if (m_authorizedApp        != address(0) && !_checkIdentity(m_authorizedApp,        deal.app.pointer,        4)) { return (false, bytes("unauthorized-app"                 ));  }
		if (m_authorizedDataset    != address(0) && !_checkIdentity(m_authorizedDataset,    deal.dataset.pointer,    4)) { return (false, bytes("unauthorized-dataset"             ));  }
		if (m_authorizedWorkerpool != address(0) && !_checkIdentity(m_authorizedWorkerpool, deal.workerpool.pointer, 4)) { return (false, bytes("unauthorized-workerpool"          ));  }
		if (m_requiredtag & ~deal.tag != bytes32(0)                                                                    ) { return (false, bytes("invalid-tag"                      ));  }
		if (m_requiredtrust > deal.trust                                                                               ) { return (false, bytes("invalid-trust"                    ));  }
		return (true, task.resultsCallback);
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
