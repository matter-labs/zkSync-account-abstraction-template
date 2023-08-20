//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct Inheritor {
    string description; // [opt] a description of an inheritor
    uint8 percentage; // the percentage the owner set to the inheritor
    uint256 id; // the id of the inheritor
}

struct RequestWithdraw {
    bool requestExsit; // if there is a request made by an inheritor;
    uint256 timestamp; // the time when the request set
    address caller; // the inheritor that made the request
}

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
