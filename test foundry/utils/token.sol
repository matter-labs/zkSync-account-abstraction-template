// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract token1 is ERC20 {
    constructor() ERC20("token1", "tk") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
