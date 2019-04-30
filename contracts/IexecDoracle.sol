pragma solidity ^0.5.7;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "iexec-poco/contracts/IexecClerk.sol";
import "iexec-poco/contracts/IexecHub.sol";

contract IexecDoracle is SignatureVerifier, IOracleConsumer
{
	address    constant IEXEC_HUB_MAINNET = 0x0000000000000000000000000000000000000000;
	address    constant IEXEC_HUB_KOVAN   = 0xC75f4909185f712F2795563B956CCF62b76A6e13;
	address    constant IEXEC_HUB_ROPSTEN = 0x0000000000000000000000000000000000000000;
	address    constant IEXEC_HUB_RINKEBY = 0x0000000000000000000000000000000000000000;
	address    constant IEXEC_HUB_GOERLI  = 0x0000000000000000000000000000000000000000;

	IexecHub   public m_iexecHub;
	IexecClerk public m_iexecClerk;
	address    public m_authorizedApp;
	address    public m_authorizedDataset;
	address    public m_authorizedWorkerpool;
	bytes32    public m_requiredtag;
	uint256    public m_requiredtrust;

	event ResultReady(bytes32 indexed doracleCallId);

	constructor(address _iexecHubAddr)
	public
	{
		if      (getCodeSize(_iexecHubAddr)     > 0) { m_iexecHub = IexecHub(_iexecHubAddr);     }
		else if (getCodeSize(IEXEC_HUB_MAINNET) > 0) { m_iexecHub = IexecHub(IEXEC_HUB_MAINNET); }
		else if (getCodeSize(IEXEC_HUB_KOVAN)   > 0) { m_iexecHub = IexecHub(IEXEC_HUB_KOVAN);   }
		else if (getCodeSize(IEXEC_HUB_ROPSTEN) > 0) { m_iexecHub = IexecHub(IEXEC_HUB_ROPSTEN); }
		else if (getCodeSize(IEXEC_HUB_RINKEBY) > 0) { m_iexecHub = IexecHub(IEXEC_HUB_RINKEBY); }
		else if (getCodeSize(IEXEC_HUB_GOERLI)  > 0) { m_iexecHub = IexecHub(IEXEC_HUB_GOERLI);  }
		else                                         { revert("invalid-hub-address");            }
		m_iexecClerk = m_iexecHub.iexecclerk();
	}

	function getCodeSize(address _addr)
	internal view returns (uint _size)
	{
		assembly { _size := extcodesize(_addr) }
	}

	function receiveResult(bytes32 _doracleCallId, bytes calldata)
	external
	{
		emit ResultReady(_doracleCallId);
	}

	function _iexecDoracleUpdateSettings(
		address _authorizedApp
	,	address _authorizedDataset
	,	address _authorizedWorkerpool
	, bytes32 _requiredtag
	, uint256 _requiredtrust
	)
	internal
	{
		m_authorizedApp        = _authorizedApp;
		m_authorizedDataset    = _authorizedDataset;
		m_authorizedWorkerpool = _authorizedWorkerpool;
		m_requiredtag          = _requiredtag;
		m_requiredtrust        = _requiredtrust;
	}

	function _iexecDoracleGetVerifiedResult(bytes32 _doracleCallId)
	internal view returns (bytes memory)
	{
		IexecODBLibCore.Task memory task = m_iexecHub.viewTask(_doracleCallId);
		IexecODBLibCore.Deal memory deal = m_iexecClerk.viewDeal(task.dealid);

		require(task.status == IexecODBLibCore.TaskStatusEnum.COMPLETED,                                                                                    "result-not-available"             );
		require(task.resultDigest == keccak256(task.results),                                                                                               "result-not-validated-by-consensus");
		require(m_authorizedApp        == address(0) || checkIdentity(m_authorizedApp,        deal.app.pointer,        m_iexecClerk.GROUPMEMBER_PURPOSE()), "unauthorized-app"                 );
		require(m_authorizedDataset    == address(0) || checkIdentity(m_authorizedDataset,    deal.dataset.pointer,    m_iexecClerk.GROUPMEMBER_PURPOSE()), "unauthorized-dataset"             );
		require(m_authorizedWorkerpool == address(0) || checkIdentity(m_authorizedWorkerpool, deal.workerpool.pointer, m_iexecClerk.GROUPMEMBER_PURPOSE()), "unauthorized-workerpool"          );
		require(m_requiredtag & ~deal.tag == bytes32(0),                                                                                                    "invalid-tag"                      );
		require(m_requiredtrust <= deal.trust,                                                                                                              "invalid-trust"                    );
		return task.results;
	}
}
