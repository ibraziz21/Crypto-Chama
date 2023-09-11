// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract poolToken is ERC20 {
    constructor()ERC20("PoolToken", "PTK") {
        _mint(msg.sender, 10000000*10**18);
    }
}