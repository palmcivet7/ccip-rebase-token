// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRebaseToken is IERC20 {
    function mint(address, uint256) external;
    function burn(address, uint256) external;
    // already defined in IERC20
    // function balanceOf(address) external view returns (uint256);
}
