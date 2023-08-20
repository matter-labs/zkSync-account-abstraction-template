## Table of Contents

- [Inheritance Will Smart Contract](#inheritance-will-smart-contract)
  - [Motivation](#motivation)
  - [Introduction](#introduction)
  - [Keys](#keys)
    - [**Storage Struct** :](#storage-struct-)
    - [**location slot** :](#location-slot-)
    - [Design Decisions](#design-decisions)
    - [Role of Inheritors](#role-of-inheritors)
  - [Functions](#functions)
  - [Storage Variables](#storage-variables)
  - [License](#license)

# Inheritance Will Smart Contract

The Inheritance `Will` Smart Contract is a solidity-based contract designed to manage controlled fund withdrawals for inheritors specified by the owner. This contract leverages a withdrawal mechanism based on time, ensuring a secure and efficient process for allowing inheritors to access their designated shares.The contract facilitates a seamless interaction between the owner and inheritors.

## Motivation

In the ever-evolving landscape of cryptocurrencies, the need for a secure and foolproof solution to safeguard digital assets is paramount. The Inheritance `Will` Smart Contract addresses a significant concern within the crypto space – the risk of lost funds due to unforeseen circumstances. These circumstances may include the unfortunate passing of the account owner, the loss of private keys, or the inability to access the account due to various reasons.

Numerous cases have arisen where substantial amounts of cryptocurrency are effectively locked within accounts, rendering them inaccessible indefinitely. This situation not only results in financial loss but also undermines the potential legacy and intended use of those funds. To address this critical issue, the Inheritance Will Smart Contract offers a robust mechanism for the secure management and eventual distribution of assets, ensuring that they reach the intended beneficiaries even in the absence of the account owner's active involvement.

By empowering account owners to set up predefined withdrawal mechanisms and designating inheritors, this contract effectively bridges the gap between the owner's control and the need for a fail-safe solution. The withdrawal request system, coupled with accurate timing conditions, assures that authorized inheritors can access their designated shares without relying on the owner's continuous presence or intervention. This proactive approach significantly reduces the risk of lost funds due to circumstances beyond anyone's control.

## Introduction

The Inheritance Will Smart Contract introduces a system that enables a contract owner to define inheritors, allocate their respective percentages, and specify withdrawal conditions. The contract leverages a structured approach to manage the withdrawal process, optimizing the inheritor's knowledge of the owner's behavior and minimizing the risk of unintended withdrawals.

## Keys

The presented smart contract introduces a comprehensive framework that facilitates controlled inheritance of digital assets by integrating the following fundamental concepts:

- **`Inheritor`**: An "Inheritor" is an struct designated by the contract owner to receive a predefined portion of the contract's holdings upon activation of the withdrawal mode. The inheritor's details, including a description and assigned percentage, are stored in a structured format for transparency and accountability.

  ```solidity
    struct Inheritor {
    string description; // [opt] a description of an inheritor
    uint8 percentage; // the percentage the owner set to the inheritor
    uint256 id; // the id of the inheritor
  }
  ```

---

- **`Withdrawal Request`**: The "Withdrawal Request" mechanism allows inheritors to initiate a formal request for the withdrawal of their allotted share. A request timestamp, inheritor's address, and a flag indicating an existing request are recorded, ensuring a deliberate and intentional withdrawal process.

  ```solidity
      struct RequestWithdraw {
        bool requestExsit; // if there is a request made by an inheritor;
        uint256 timestamp; // the time when the request set
        address caller; // the inheritor that made the request
      }
  ```

---

- **`Withdrawal Mode`**: The "Withdrawal Mode" is a pivotal state that enables the contract to transition into a mode where inheritors can execute their withdrawal requests. Activation of the withdrawal mode unlocks access to inheritors' shares and safeguards the contract against unauthorized withdrawals.

  ```solidity
    bytes1 constant WITHDRAW_MODE = 0x01;
    function _setWithdrawMode() internal {
          s().mode = s().mode | WITHDRAW_MODE;
      }
  ```

---

- **`Token Management`**: The contract supports both _native(eth)_ token and _erc20_ tokens for inheritance, providing flexibility in asset distribution. The contract maintains a mapping of token addresses and corresponding amounts required for each percentage, ensuring accurate distribution of the inherited shares.

  > `notice` ETH in zksync have it's own address which is : 0x000000000000000000000000000000000000800A

  ```solidity
    mapping(address => uint256) tokenForEachPercentage; // token for each 1% , for each token
  ```

---

- **`Owner Control`**: The contract owner holds exclusive control over critical operations, including the addition, removal, and modification of inheritors. Additionally, the owner can adjust parameters such as the duration for withdrawal requests and the time allowed between interactions.

  ```solidity
    modifier onlyOwner() {
          if (msg.sender != s().owner || msg.sender == address(this)) revert WillError__NotOwner(msg.sender);
          _resetRequestIfExist();
          _;
          s().lastUpdate = block.timestamp;
      }
  ```

  the address(this) is refer to the account , of the contract that delegateCall to this contract.so in our case we will use this for account abstraction in zksync.so to pass this modifier the **`msg.sender`** should be the owner or the account it self delegatecall to this contract.

- **`Main Inheritor`**: The concept of a "Main Inheritor" is introduced, serving as the recipient of any remaining funds in the contract after all inheritors have withdrawn their shares for a specific tokens. This ensures efficient and organized distribution of residual assets.

  ```solidity
        address mainInheritor; //after last inheritor withdrawed s specific token , the contract send the remaining asset of this token to this address
  ```

---

- **`Other Smart Contract Logic`**: The contract employs various modifiers to validate conditions and restrict operations. For instance, the `onlyDelegatecall` modifier restricts execution to delegatecall calls, enhancing security, while the `onlyInheritors` modifier ensures that specific operations are accessible only by an inheritor.

  ```solidity
    //getCodeAddress() to get the execution code (diffrent from address(this));
    modifier onlyDelegatecall() {
          require(address(this) != SystemContractHelper.getCodeAddress());
          _;
      }
      // if caller not an inheritor revert .
    modifier onlyInheritors() {
          if (!s().isInheritor[msg.sender]) revert WillError__NotInheritor(msg.sender);
          _;
      }
  ```

---

- **`Storage slot`**: the storage of this contract are implemented in one stuct , and stored in specefic slot to Avoid clashes with account storage that will implement the `Will` functionality.

  ### **Storage Struct** :

  ```solidity
   struct mainStorage {
    bytes1 mode;
    address mainInheritor; //after last inheritor withdrawed s specific token , the contract send the remaining asset of this token to this address
    address owner; // the owner of the contract;
    RequestWithdraw requestWithdraw; //request to withdraw any inheritor can set it with some conditions;
    uint8 countInheritors; // how many inheritors .
    uint256 duration; //time to pass from sending request to allow the inheritors to withdraw thier shares
    uint256 lastUpdate; // the last interaction from the owner.
    uint256 fromLastUpdate; //duration should pass from lastUpdate to allow inheritors to create a request withdraw.
    uint8 availablePercentage; //the percentage available for inherit;
    mapping(address => uint256) tokenForEachPercentage; // token for each 1% , for each token
    mapping(address => bool) isInheritor; //check if this address is inheritor of the owner
    mapping(address => Inheritor) inheritor; // get inheritor info (struct) ;
    mapping(address => mapping(address => bool)) didWithraw; //inheritor => token => did withdraw;
    mapping(address => uint8) countWithdraws; //how many inheritor did withdraw this token.
    bool initiated;//if the contract already initiated.
   }

  ```

  ### **location slot** :

  ```solidity
    bytes32 constant STORAGE_LOCATION = bytes32(uint256(keccak256("main.storage.location")) - 1);
  ```

---

- **`Inheritors and Percentages`**: The contract allows the owner to designate inheritors, assigning each a specific percentage of the total funds stored in the contract. These inheritors are individuals whom the owner trusts to receive their shares in the event that the owner is unable to access the account.

- **`Withdrawal Requests`**: Instead of immediately allowing inheritors to withdraw their shares, the contract implements a withdrawal request mechanism. This mechanism is designed to ensure that the withdrawal process aligns with the intended purpose of the contract and is not triggered by accidental actions.

- **`Duration and Timing`**: The owner can set a duration that must pass from the time a withdrawal request is made before an inheritor is allowed to execute their withdrawal. This duration serves as a safeguard, enabling inheritors to withdraw their shares only after a certain period has elapsed since the request.</br>.
  \*note that the owner can set the duration to any time (even 0), and also the inheritors to just one inheritor with 100% percentage, this gives the owner the Flexibility to manage his assets as he want.</br>

---

- **`Initialization`** :
  The contract initialization occurs via the `init` function, which sets various contract parameters. This function should be called only once.
  ```solidity
     function init(uint256 _duration, uint256 _fromLastUpdate, address _mainInheritor, address _owner) internal once {
        require(msg.sender != address(0));
        require(_owner != address(0),"owner can't be address zero");
        s().owner = _owner;
        s().duration = (_duration) * 1 days;
        s().fromLastUpdate = _fromLastUpdate * 1 days;
        s().mainInheritor = _mainInheritor;
        s().availablePercentage = 100;
    }
  ```
  > ⛔⛔ `NOTICE` ⛔⛔ : this function can be frontRunned.make sure to delegateCall to it in secure way.

---

### Design Decisions

1. **`Withdrawal Mode**: The contract includes a flag known as **_mode_**. This mode becomes active after the specified **duration** set by the owner has elapsed since the withdrawal request was initiated. Once triggered, the mode remains active unless the owner manually pauses it. This approach safeguards against accidental or premature withdrawals, ensuring that inheritors can only withdraw their shares according to the intended conditions.

2. **`Timing Precision`**: By utilizing the combination of the request timestamp and the specified withdrawal duration, the contract minimizes the chances of accidental withdrawals. This approach optimizes the withdrawal process by aligning it with the inheritor's understanding of the owner's behavior and ensuring that withdrawals occur when intended.

3. **`Main Inheritor`**: The contract allows the owner to specify a "main inheritor." This address will receive any remaining funds left in the contract after all inheritors have made their withdrawals. This ensures that funds do not remain locked in the contract and are properly distributed according to the owner's wishes.

   > `notice:` the only way that the **_mainInheritor_** get the remaining share is by the last inheritor get withdrawed. so the idea is that the main inheritor may informe other inheritors to get thier shares , so he can get the remaining 😊. that's why i'm assuming that the owner will set the **_mainInheritor_** as someone that can do that, and even he may guid other inheritors how to withdraw😉.

4. **`Inheritor Management`**: The contract offers functionalities for adding, removing, and changing the percentage of inheritors. This flexibility empowers the owner to adapt the contract to changing circumstances while maintaining control over the distribution of funds.

5. **`Owner Interaction`**: The owner's interactions with the contract serve as a trigger for resetting the state, such as canceling pending withdrawal requests and updating the "lastUpdate" timestamp. This feature ensures that the contract remains responsive to any changes in the owner's intentions.

_In summary, the design of the Inheritance `Will` Smart Contract is rooted in the principle of providing a secure and controlled method for inheritors to access their shares in the event of unforeseen circumstances affecting the account owner. The combination of withdrawal requests, precise timing conditions, and the inheritor's understanding of the owner's behavior enhances the reliability and security of the contract's withdrawal process, mitigating the risks associated with lost funds in the crypto space._

### Role of Inheritors

_Inheritors play a crucial role in this contract's design. The contract assumes that inheritors are individuals closely associated with the owner and thus have an understanding of the owner's behavior and intentions. Inheritors are expected to make withdrawal requests based on their knowledge of the owner's circumstances, ensuring that withdrawals occur in alignment with the owner's intent._

## Functions

| Function                    | Description                                                                                              |
| --------------------------- | -------------------------------------------------------------------------------------------------------- |
| `addInheritor`              | Allows the owner to add an inheritor with a specified description and percentage.                        |
| `removeInheritor`           | Permits the owner to remove an inheritor and reallocates their percentage.                               |
| `changeInheritorPersantage` | Allows the owner to change an inheritor's percentage.                                                    |
| `changeDuration`            | Enables the owner to change the withdrawal duration.                                                     |
| `changeFromLastUpdate`      | Allows the owner to set the time after the last update before an inheritor can request a withdrawal.     |
| `changeMainInheritor`       | Allows the owner to set a main inheritor who will receive remaining funds after all inheritors withdraw. |
| `pauseWithdraw`             | Allows the owner to pause the withdrawal mode.                                                           |
| `requestToWithdraw`         | Inheritors use this function to initiate a withdrawal request.                                           |
| `inheritorWithdraw`         | Inheritors use this function to withdraw their share based on token balance.                             |
| `getYourCurrentAmount`      | Allows inheritors to check their current share in a specific token.                                      |
| `getInheritorPercentage`    | Allows inheritors to check their percentage.                                                             |
| `getInheritorCount`         | Provides the current count of inheritors.                                                                |
| `getAvailablePercentage`    | Provides the current available percentage.                                                               |
| `getRequestWithdraw`        | Retrieves information about the current withdrawal request.                                              |
| `getInheritor`              | Retrieves information about a specific inheritor.                                                        |

## Storage Variables

| Storage Variable         | Description                                                                     |
| ------------------------ | ------------------------------------------------------------------------------- |
| `mode`                   | Indicating whether the contract is in withdraw mode.                            |
| `mainInheritor`          | Address of the main inheritor who receives remaining funds.                     |
| `owner`                  | Address of the contract owner.                                                  |
| `requestWithdraw`        | Information about a withdrawal request.                                         |
| `countInheritors`        | Count of inheritors set by the owner.                                           |
| `duration`               | Duration for the withdrawal condition.                                          |
| `lastUpdate`             | Timestamp of the last owner interaction.                                        |
| `fromLastUpdate`         | Time period after the last update before an inheritor can request a withdrawal. |
| `availablePercentage`    | Percentage available for inheritance.                                           |
| `tokenForEachPercentage` | Mapping amount of tokens for each 1% inheritance.                               |
| `isInheritor`            | Mapping to check if an address is an inheritor of the owner.                    |
| `inheritor`              | Mapping to get inheritor info (struct).                                         |
| `didWithdraw`            | Mapping to track if an inheritor did withdraw for each token.                   |
| `countWithdraws`         | Mapping to track how many inheritors did withdraw for each token.               |
| `initiated`              | Boolean flag to indicate if the contract is already initialized.                |

## License

This smart contract is released under the MIT License. Please refer to the SPDX-License-Identifier tag in the source code for more details.

[Back to Motivation](#motivation)
