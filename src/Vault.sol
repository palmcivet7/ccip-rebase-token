// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    // we need to pass the token address to the constructor
    // create a deposit function that mints tokens to the user equal to the amount of ETH the user deposited
    // create a redeem function that burns tokens from the user and sends the user ETH
    // create a way to add rewards to the vault

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error Vault__RedeemFailed();

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    IRebaseToken internal immutable i_rebaseToken;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address rebaseToken) {
        i_rebaseToken = IRebaseToken(rebaseToken);
    }

    /*//////////////////////////////////////////////////////////////
                                EXTERNAL
    //////////////////////////////////////////////////////////////*/
    receive() external payable {}

    /// @notice Allows users to deposit ETH into the vault and mint rebase tokens in return
    function deposit() external payable {
        // need to use amount of ETH user has sent to mint tokens to user
        uint256 interestRate = i_rebaseToken.getInterestRate();
        i_rebaseToken.mint(msg.sender, msg.value, interestRate);

        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Allows users to redeem their rebase tokens to ETH
    /// @param amount of rebase tokens to redeem
    function redeem(uint256 amount) external {
        if (amount == type(uint256).max) {
            amount = i_rebaseToken.balanceOf(msg.sender);
        }

        // burn the tokens from user
        i_rebaseToken.burn(msg.sender, amount);
        // send the user ETH
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert Vault__RedeemFailed();
        emit Redeem(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    /// @return rebaseToken address
    function getRebaseToken() external view returns (address) {
        return address(i_rebaseToken);
    }
}
