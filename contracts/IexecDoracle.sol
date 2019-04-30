pragma solidity ^0.5.7;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "iexec-poco/contracts/IexecClerk.sol";
import "iexec-poco/contracts/IexecHub.sol";

contract IexecDoracle is SignatureVerifier, IOracleConsumer
{
	IexecHub   public m_iexecHub;
	IexecClerk public m_iexecClerk;
	address    public m_authorizedApp;
	address    public m_authorizedDataset;
	address    public m_authorizedWorkerpool;
	bytes32    public m_requiredtag;
	uint256    public m_requiredtrust;

	event ResultReady(bytes32 indexed doracleCallId);

	constructor(IexecHub _iexecHub)
	public
	{
		m_iexecHub   = _iexecHub;
		m_iexecClerk = m_iexecHub.iexecclerk();
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
