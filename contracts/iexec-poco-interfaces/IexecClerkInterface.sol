pragma solidity ^0.5.8;
pragma experimental ABIEncoderV2;

import "iexec-poco/contracts/libs/IexecODBLibCore.sol";
import "iexec-poco/contracts/libs/IexecODBLibOrders.sol";


contract IexecClerkInterface
{
	uint256 public constant WORKERPOOL_STAKE_RATIO = 30;
	uint256 public constant KITTY_RATIO            = 10;
	uint256 public constant KITTY_MIN              = 1000000000;
	uint256 public constant GROUPMEMBER_PURPOSE    = 4;

	bytes32 public /* immutable */ EIP712DOMAIN_SEPARATOR;

	event OrdersMatched        (bytes32 dealid, bytes32 appHash, bytes32 datasetHash, bytes32 workerpoolHash, bytes32 requestHash, uint256 volume);
	event ClosedAppOrder       (bytes32 appHash);
	event ClosedDatasetOrder   (bytes32 datasetHash);
	event ClosedWorkerpoolOrder(bytes32 workerpoolHash);
	event ClosedRequestOrder   (bytes32 requestHash);
	event SchedulerNotice      (address indexed workerpool, bytes32 dealid);

	function viewRequestDeals(bytes32 _id)
	external view returns (bytes32[] memory);

	function viewDeal(bytes32 _id)
	external view returns (IexecODBLibCore.Deal memory);

	function viewConsumed(bytes32 _id)
	external view returns (uint256);

	function viewPresigned(bytes32 _id)
	external view returns (bool presigned);

	function signAppOrder(IexecODBLibOrders.AppOrder memory _apporder)
	public returns (bool);

	function signDatasetOrder(IexecODBLibOrders.DatasetOrder memory _datasetorder)
	public returns (bool);

	function signWorkerpoolOrder(IexecODBLibOrders.WorkerpoolOrder memory _workerpoolorder)
	public returns (bool);

	function signRequestOrder(IexecODBLibOrders.RequestOrder memory _requestorder)
	public returns (bool);

	function matchOrders(
		IexecODBLibOrders.AppOrder        memory _apporder,
		IexecODBLibOrders.DatasetOrder    memory _datasetorder,
		IexecODBLibOrders.WorkerpoolOrder memory _workerpoolorder,
		IexecODBLibOrders.RequestOrder    memory _requestorder)
	public returns (bytes32);

	function cancelAppOrder(IexecODBLibOrders.AppOrder memory _apporder)
	public returns (bool);

	function cancelDatasetOrder(IexecODBLibOrders.DatasetOrder memory _datasetorder)
	public returns (bool);

	function cancelWorkerpoolOrder(IexecODBLibOrders.WorkerpoolOrder memory _workerpoolorder)
	public returns (bool);

	function cancelRequestOrder(IexecODBLibOrders.RequestOrder memory _requestorder)
	public returns (bool);

}
