pragma solidity ^0.5.10;
pragma experimental ABIEncoderV2;

import "iexec-solidity/contracts/ERC20_Token/ERC20.sol";
import "../IexecDoracle.sol";

contract Lottery is ERC20, IexecDoracle
{
	using SafeMath for uint256;

	bytes32 public constant TAG    = 0x0000000000000000000000000000000000000000000000000000000000000001; // TEE
	uint256 public constant TRUST  = 0; // No replication
	string  public constant PARAMS = "";

	/**
	* token contract for transfers.
	*/
	IERC20 public baseToken;

	struct Details
	{
		bytes32   oracleCall;
		uint256   ticketPrice;
		uint256   potValue;
		uint256   registrationDeadline;
		uint256   maxParticipants;
		address[] participants;
	}

	mapping(bytes32 => uint256) public oracleCallToLottery;
	Details[]                   public lotteryDetails;

	event NewLottery    (uint256 indexed id);
	event NewParticipant(uint256 indexed id, address participant);
	event NewRoll       (uint256 indexed id, bytes32 taskid);
	event Reward        (uint256 indexed id, address winner, uint256 value);
	event Claim         (uint256 indexed id);

	constructor(
		address _iexecHubAddr,
		address _app,
		address _dataset,
		address _workerpool)
	public IexecDoracle(_iexecHubAddr)
	{
		_iexecDoracleUpdateSettings(
			_app,
			_dataset,
			_workerpool,
			TAG,
			TRUST
		);
	}

	/***************************************************************************
	 *                                 LOTTERY                                 *
	 ***************************************************************************/
	function createLottery(
		uint256 _ticketPrice,
		uint256 _maxParticipants,
		uint256 _duration)
	public
	{
		uint256 id = lotteryDetails.length++;

		Details storage details = lotteryDetails[id];
		details.ticketPrice          = _ticketPrice;
		details.registrationDeadline = now + _duration;
		details.maxParticipants      = _maxParticipants;

		emit NewLottery(id);
	}

	function buyTicket(uint256 _id)
	public
	{
		Details storage details = lotteryDetails[_id];

		require(now <= details.registrationDeadline);
		require(details.participants.length < details.maxParticipants);

		_transfer(msg.sender, address(this), details.ticketPrice);
		details.participants.push(msg.sender);
		details.potValue = details.potValue.add(details.ticketPrice);

		emit NewParticipant(_id, msg.sender);
	}

	function roll(
		uint256                                  _id,
		IexecODBLibOrders.AppOrder        memory _apporder,
		IexecODBLibOrders.DatasetOrder    memory _datasetorder,
		IexecODBLibOrders.WorkerpoolOrder memory _workerpoolorder)
	public
	{
		Details storage details = lotteryDetails[_id];

		require(now > details.registrationDeadline);
		require(details.oracleCall == bytes32(0));

		// check whitelist
		require(m_authorizedApp        == address(0) || checkIdentity(m_authorizedApp,        _apporder.app,               iexecClerk.GROUPMEMBER_PURPOSE()), "unauthorized-app");
		require(m_authorizedDataset    == address(0) || checkIdentity(m_authorizedDataset,    _datasetorder.dataset,       iexecClerk.GROUPMEMBER_PURPOSE()), "unauthorized-dataset");
		require(m_authorizedWorkerpool == address(0) || checkIdentity(m_authorizedWorkerpool, _workerpoolorder.workerpool, iexecClerk.GROUPMEMBER_PURPOSE()), "unauthorized-workerpool");

		IexecODBLibOrders.RequestOrder memory requestorder;
		requestorder.app                = _apporder.app;                         //address
		requestorder.appmaxprice        = _apporder.appprice;                    //uint256
		requestorder.dataset            = _datasetorder.dataset;                 //address
		requestorder.datasetmaxprice    = _datasetorder.datasetprice;            //uint256
		requestorder.workerpool         = _workerpoolorder.workerpool;           //address
		requestorder.workerpoolmaxprice = _workerpoolorder.workerpoolprice;      //uint256
		requestorder.requester          = address(this);                         //address
		requestorder.volume             = 1;                                     //uint256
		requestorder.tag                = TAG;                                   //bytes32
		requestorder.category           = _workerpoolorder.category;             //uint256
		requestorder.trust              = TRUST;                                 //uint256
		requestorder.beneficiary        = address(0);                            //address
		requestorder.callback           = address(this);                         //address
		requestorder.params             = PARAMS;                                //string
		requestorder.salt               = keccak256(abi.encodePacked(now, _id)); //bytes32

		// sign order
		require(iexecClerk.signRequestOrder(requestorder));

		// pay for deal
		uint256 dealprice = _apporder.appprice.add(_datasetorder.datasetprice).add(_workerpoolorder.workerpoolprice);
		baseToken.approve(address(iexecClerk), dealprice);
		iexecClerk.deposit(dealprice);
		_burn(address(this), dealprice);
		details.potValue = details.potValue.sub(dealprice);

		// match and retreive deal
		bytes32 dealid = iexecClerk.matchOrders(_apporder, _datasetorder, _workerpoolorder, requestorder);
		bytes32 taskid = keccak256(abi.encodePacked(dealid, uint256(0)));

		// register
		details.oracleCall = taskid;
		oracleCallToLottery[taskid] = _id;

		emit NewRoll(_id, taskid);
	}

	function receiveResult(bytes32 _doracleCallId, bytes memory)
	public
	{
		// emit ResultReady(_doracleCallId);

		uint256 id              = oracleCallToLottery[_doracleCallId];
		Details storage details = lotteryDetails[id];

		(uint256 value) = abi.decode(_iexecDoracleGetVerifiedResult(_doracleCallId), (uint256));

		address winner = details.participants[value % details.participants.length];
		_transfer(address(this), winner, details.potValue);

		emit Reward(id, winner, details.potValue);

		delete oracleCallToLottery[_doracleCallId];
		delete lotteryDetails[id];
	}

	function claim(uint256 _id)
	public
	{
		Details storage details = lotteryDetails[_id];

		iexecHub.claim(details.oracleCall);
		IexecODBLibCore.Account memory account = iexecClerk.viewAccount(address(this));
		iexecClerk.withdraw(account.stake);

		_mint(address(this), account.stake);
		details.potValue   = details.potValue.add(account.stake);
		details.oracleCall = bytes32(0);

		emit Claim(_id);
	}

	/***************************************************************************
	 *                                 ESCROW                                  *
	 ***************************************************************************/
	function deposit(uint256 amount)
		external returns (bool)
	{
		_deposit(msg.sender, amount);
		_mint(msg.sender, amount);
		return true;
	}

	function withdraw(uint256 amount)
		external returns (bool)
	{
		_burn(msg.sender, amount);
		_withdraw(msg.sender, amount);
		return true;
	}

	function receiveApproval(address sender, uint256 amount, address token, bytes calldata)
		external returns (bool)
	{
		require(token == address(baseToken), 'wrong-token');
		_deposit(sender, amount);
		_mint(sender, amount);
		return true;
	}

	function _deposit(address from, uint256 amount)
		internal
	{
		require(baseToken.transferFrom(from, address(this), amount));
	}

	function _withdraw(address to, uint256 amount)
		internal
	{
		baseToken.transfer(to, amount);
	}

}
