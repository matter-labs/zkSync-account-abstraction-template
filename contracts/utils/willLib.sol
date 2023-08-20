//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./structs.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error WillError__InheritorExist();
error WillError__NotInheritor(address caller);
error WillError__NotOwner(address caller);
error WillError__NotValidPercentage(uint8 maxPercentage);
error WillError__TxFailed();
error WillError__YouAllowToWithdraw();
error WillError__NotAllowedYet();
error WillError__RequestAlreadyExist(uint256 requestTimestamp);
error WillError__DidWithdraw(address caller);
error WillError__NotValidUpdate();

library willLib {
    event AddInheritor(address indexed inheritor, uint256 indexed percentage);
    event RemoveInheritor(address indexed inheritor, uint256 indexed availabelpercentage);
    event OwnerWithdraw(address indexed owner, uint256 amount);
    event RequestToWithdraw(address indexed caller, uint256 indexed time);
    event InheritorWithdraw(address indexed inheritor, uint256 indexed value);
    //flag the will be set when the widthdraw Mode is active.

    bytes1 constant WITHDRAW_MODE = 0x01;
    //address native token on zksyc era.
    address constant ETH = 0x000000000000000000000000000000000000800A;

    modifier onlyInheritors() {
        if (!s().isInheritor[msg.sender]) revert WillError__NotInheritor(msg.sender);
        _;
    }
    /**
     * @dev revert if the caller is not the owner, or the account it self.
     * @notice this modifier also will cancle a request if exist and update the "lastUpdate", which mean when ever the owner interact with the contract
     *          this will reset the state.
     */

    modifier onlyOwner() {
        if (msg.sender != s().owner || msg.sender == address(this)) revert WillError__NotOwner(msg.sender);
        _resetRequestIfExist();
        _;
        s().lastUpdate = block.timestamp;
    }
    /**
     * @dev check that the time to withdraw , if it's early revert  otherwise set the withdraw flag.
     * @param token the address of the token to be withdrawed, support eth and erc20.
     */

    modifier allowInheritorWithdraw(address token) {
        require(s().requestWithdraw.requestExsit,"no request to withdraw");
        if (block.timestamp < s().duration + s().requestWithdraw.timestamp) {
            revert WillError__NotAllowedYet();
        }
        if (!_isWithdrawMode()) {
            _setWithdrawMode();
        }
        if (s().didWithraw[msg.sender][token]) {
            revert WillError__DidWithdraw(msg.sender);
        }
        
        if (s().tokenForEachPercentage[token] == 0) {
            s().tokenForEachPercentage[token] = _amountForEachPercentage(token);
        }
        _;
    }
    /**
     * @dev allow an inheritor to set a request to withdraw .
     * @notice if there is already a request ,this will revert.
     * @notice if the withdraw flag is set there is no need to create a request , so this will throw.
     * @notice the time fromLastUpdate should pass , which is the time that and inheritor can set a request after the lastUpdate
     */

    modifier allowRequestWithdraw() {
        if (_isWithdrawMode()) revert WillError__YouAllowToWithdraw();
        if (s().requestWithdraw.requestExsit) revert WillError__RequestAlreadyExist(s().requestWithdraw.timestamp);
        if (block.timestamp < s().lastUpdate + s().fromLastUpdate) revert WillError__NotAllowedYet();
        _;
    }
    /**
     * @dev set the withdraw mode, so inheritors can get thier shares
     */

    function _setWithdrawMode() internal {
        s().mode = s().mode | WITHDRAW_MODE;
    }
    /**
     * @dev reset the withdraw mode.
     */

    function _resetWithdrawMode() internal {
        s().mode = 0x00;
    }
    /**
     * @dev check if the the contract is in withdraw mode
     * @return withdraw true if the contract in withdraw mode, and false if not
     */

    function _isWithdrawMode() internal view returns (bool withdraw) {
        withdraw = s().mode & WITHDRAW_MODE != 0;
    }
    /**
     * @dev check if there is a request to withdraw, and delete it .
     */

    function _resetRequestIfExist() internal {
        if (s().requestWithdraw.requestExsit) {
            delete  s().requestWithdraw;
        }
    }

    /**
     * @dev function that allow the owner to add his inheritors .
     * @notice the percentage is only 100% and it every time the owner add an iheritor by the _percentage value. notice if the percentage available
     * is less then _percentage this will throw.
     * @param description optional description of the inheritor
     * @param _inheritor the address of the inheritor
     * @param _percentage the percentage that the inheritor will take from all this contract value in case of withdraw mode.
     * -return addInhritor emit an event.
     */
    function addInheritor(string memory description, address _inheritor, uint8 _percentage) internal onlyOwner {
        require(_inheritor != address(0), "inheritor address zero");
        require(_percentage != 0, "percentage can't be zero");
        if (s().isInheritor[_inheritor]) revert WillError__InheritorExist();
        if (_percentage > s().availablePercentage) {
            revert WillError__NotValidPercentage(s().availablePercentage);
        }
        s().availablePercentage -= _percentage;
        s().inheritor[_inheritor] = Inheritor(description, _percentage, s().countInheritors);
        s().countInheritors += 1;

        s().isInheritor[_inheritor] = true;
        emit AddInheritor(_inheritor, _percentage);
    }
    /**
     * @dev remove and inheritor by the owner.
     * @notice the percentage that was for this inheritor will be added to the global var availablePercentage.
     * @param _inheritor the address of the inheritor the owner want to remove.
     */

    function removeInheritor(address _inheritor) internal onlyOwner {
        if (!s().isInheritor[_inheritor]) {
            revert WillError__NotInheritor(_inheritor);
        }
        s().isInheritor[_inheritor] = false; // set the mapping to false
        s().countInheritors -= 1; //decrease the count of inheritors by one ;
        uint8 perce = s().inheritor[_inheritor].percentage; //fetch percentage to add after to the availabel percantage
        Inheritor memory setToDefault; //delete the inheritor struct
        s().availablePercentage += perce; //add the percantage to the available percentage
        s().inheritor[_inheritor] = setToDefault;
        emit RemoveInheritor(_inheritor, s().availablePercentage);
    }

    /**
     * @dev change a percentage of an inheritor by the owner
     * @param _inheritor the inheritor address .
     * @param newPercentage the new percentage for this inheritor.
     */
    function changeInheritorPersantage(address _inheritor, uint8 newPercentage) internal onlyOwner {
        if (!s().isInheritor[_inheritor] || newPercentage == 0) {
            revert WillError__NotValidUpdate();
        }

        if (newPercentage > s().availablePercentage + s().inheritor[_inheritor].percentage) {
            revert WillError__NotValidPercentage(s().availablePercentage + s().inheritor[_inheritor].percentage);
        }
        s().availablePercentage = s().availablePercentage + s().inheritor[_inheritor].percentage - newPercentage;

        s().inheritor[_inheritor].percentage = newPercentage;
    }
    /**
     * @dev change the duration .
     * @notice this contract is based on time,the owner sets a duration that if it passed with no interaction from the owner with the account,any
     * inheritor can withraw it's shares.
     * @notice it's required to be a withdraw request,the logic behind that the inheritors should know that they are allowed, to withdraw (since they are close to the owner)
     * @param newDuration the new duration that will allow the inheritors withdraw if it passed.
     */

    function changeDuration(uint256 newDuration) internal onlyOwner {
        s().duration = newDuration * 1 days;
    }
    /**
     * @dev the period sould pass from the lastUpdate (last interaction from the owner) to allow create a request withdraw .
     * @notice It will be annoying if inheritors always can create a requestWithdraw ,so the owner have the choice to set duration
     * that should passto allow inheritors to create a requestWithdraw.
     * @param _fromLastUpdate the period that should pass from lastUpdate  .
     */

    function changeFromLastUpdate(uint256 _fromLastUpdate) internal onlyOwner {
        s().fromLastUpdate = _fromLastUpdate * 1 days;
    }
    /**
     * @dev The owner have the ability to set a main inheritor,that will take all the remain funds that will stay
     *  in the owner account  after the last inheritor withdrawed.
     * @notice that's will be the process for each token , after last inheritor withdraw (token), if the balance of account of this token
     * more then zero, it will send the funds to the mainInheritor.
     * @param _mainInheritor the new address of the mainInheritor.
     */

    function changeMainInheritor(address payable _mainInheritor) internal onlyOwner {
        s().mainInheritor = _mainInheritor;
    }
    /**
     * @dev pause the withdraw if the withdraw mode is active. only by the owner.
     */

    function pauseWithdraw() internal onlyOwner {
        require(_isWithdrawMode(), "No need to block it");
        _resetWithdrawMode();
        _resetRequestIfExist();
        s().lastUpdate = block.timestamp;
    }

    // inheritors functions :

    /**
     * @dev an inheritor set a request to withdraw.
     * @notice By using the requestTimestamp alongside the duration, the smart contract creates a withdrawal request
     *  system that capitalizes on the inheritor's understanding of the owner's behavior. This method reduces the risk
     *  of unintended withdrawals caused by unforeseen owner actions, significantly bolstering the reliability and security
     *  of the contract's withdrawal process.
     */
    function requestToWithdraw() internal onlyInheritors allowRequestWithdraw {
        s().requestWithdraw = RequestWithdraw(true, block.timestamp, msg.sender);

        emit RequestToWithdraw(msg.sender, block.timestamp);
    }
    /**
     * @dev inheritor withdraw his share for a specific token;
     * @notice the inheritor has the same percentage in all tokens that's owned by this account
     * @notice the inheritor should provide the token address for each withdraw.
     * @param token the address of the token to withdraw .
     */

    function inheritorWithdraw(address token) internal onlyInheritors allowInheritorWithdraw(token) {
        s().countWithdraws[token]++;
        uint256 val = _getCountForPercentage(s().inheritor[msg.sender].percentage, token);
        s().didWithraw[msg.sender][token] = true;
        _tokenTransfer(token, msg.sender, val);
        emit InheritorWithdraw(msg.sender, val);
        uint256 balance = token == ETH ? address(this).balance : IERC20(token).balanceOf(address(this));
        if (s().countInheritors == s().countWithdraws[token] && balance != 0) {
            _tokenTransfer(token, s().mainInheritor, balance);
        }
    }

    /**
     * @dev send value of a token to an address
     * @param token the address of the token .
     */
    function _tokenTransfer(address token, address to, uint256 value) internal {
        if (token == ETH) {
            (bool seccuss,) = to.call{value: value}("");
            require(seccuss, "txFailed");
        } else {
            IERC20(token).transfer(to, value);
        }
    }

    //read functions:
    /**
     * @dev get your share of a token in the current time
     * @notice it will throw if the caller not inheritor
     * @notice this is not the final share , since the owner is still able to (dercrease , increase ,remove ,change) .
     * @param token the token address
     */
    function getYourCurrentAmount(address token) internal view onlyInheritors returns (uint256) {
        return _amountForEachPercentage(token) * s().inheritor[msg.sender].percentage;
    }

    /**
     * @dev get your current percentage.
     * @notice it will throw if the caller not inheritor
     * @param _inheritor  address of inheritor .
     */
    function getInheritorPercentage(address _inheritor) internal view onlyInheritors returns (uint8) {
        return s().inheritor[_inheritor].percentage;
    }

    /**
     * @dev get the current count of inheritors set's by the owner.
     */
    function getInheritorCount() internal view returns (uint8) {
        return s().countInheritors;
    }

    /**
     * @dev get the current available percentage.
     */
    function getAvailablePercentage() internal view returns (uint8) {
        return s().availablePercentage;
    }

    /**
     * @dev get the current RequestWithdraw info . (false,0,address(0)) if non.
     */
    function getRequestWithdraw() internal view returns (RequestWithdraw memory) {
        return s().requestWithdraw;
    }

    /**
     * @dev get the current inheritor info.
     * @param add address of the inheritor
     */
    function getInheritor(address add) internal view returns (Inheritor memory) {
        return s().inheritor[add];
    }

    //helper functions :
    /**
     * @dev return the time left to be able to set withdraw mode if the owner didn't interact with the account from now
     */
    function _timeLeft() private view returns (uint256) {
        uint256 timeleft;
        if (s().requestWithdraw.requestExsit) {
            timeleft = (s().duration + s().requestWithdraw.timestamp) - block.timestamp;
        } else {
            if (block.timestamp > s().lastUpdate + s().fromLastUpdate) {
                timeleft = s().duration;
            } else {
                timeleft = s().duration + s().fromLastUpdate;
            }
        }
        return timeleft;
    }

    /**
     * @dev return the amount of token for each 1% ,
     * @notice this is specific for each token,
     * @param token the address of the token.
     * @return forEach the amount of token for each 1% .
     */
    function _amountForEachPercentage(address token) internal view returns (uint256 forEach) {
        if (token == ETH) {
            forEach = address(this).balance / 100;
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            forEach = balance / 100;
        }
    }

    /**
     * @dev get a value count based on persentage and token .
     */
    function _getCountForPercentage(uint256 percentage, address token) internal view returns (uint256 count) {
        count = s().tokenForEachPercentage[token] * percentage;
    }

    ///////////////// storage stuff ////////////////////////////////////////////////////
    // location slot for this contract storage to start from.
    bytes32 constant STORAGE_LOCATION = bytes32(uint256(keccak256("main.storage.location")) - 1);

    /**
     * @dev modifier that insure that this contract is initiated once.
     */
    modifier once() {
        require(!s().initiated, "will already initialized");
        _;
        s().initiated = true;
    }
    /**
     * @dev this init should never be called more then one in each contract. it servs as a constructor.
     * @param _duration the duration to allow withdraw
     * @param _fromLastUpdate the duration to allow make a request withdraw
     * @param _mainInheritor the main inheritor of the owner.
     */

    function init(uint256 _duration, uint256 _fromLastUpdate, address _mainInheritor, address _owner) internal once {
        require(msg.sender != address(0));
        require(_owner != address(0),"owner can't be address zero");
        s().owner = _owner;
        s().duration = (_duration) * 1 days;
        s().fromLastUpdate = _fromLastUpdate * 1 days;
        s().mainInheritor = _mainInheritor;
        s().availablePercentage = 100;
        s().lastUpdate = block.timestamp;
    }
    /**
     * @dev return the location storage of the will contract .
     */

    function s() internal pure returns (mainStorage storage S) {
        bytes32 slot = STORAGE_LOCATION;
        assembly {
            S.slot := slot
        }
    }
    ////////////////////////////////////////////////////////////////////////////////////
}
