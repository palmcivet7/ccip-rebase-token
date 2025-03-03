// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IRebaseToken, IERC20} from "./interfaces/IRebaseToken.sol";

/// @title Rebase Token
/// @notice This is a crosschain rebase token that incentivizes users to deposit into a vault.
/// @notice The interest rate in the contract can only decrease.
/// @notice Each user will have their own interest rate, that is the global interest rate at the time of deposit.
contract RebaseToken is ERC20, Ownable, AccessControl, IRebaseToken {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error RebaseToken__InterestRateCanOnlyDecrease();

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant PRECISION_FACTOR = 1e18;
    bytes32 internal constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    uint256 internal s_interestRate = (5 * PRECISION_FACTOR) / 1e8; // 10^-8 == 1/ 10^8
    mapping(address user => uint256 interestRate) internal s_userInterestRate;
    mapping(address user => uint256 lastUpdatedTimestamp) internal s_userLastUpdatedTimestamp;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event InterestRateSet(uint256 newInterestRate);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function grantMintAndBurnRole(address account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, account);
    }

    /// @notice Set the interest rate in the contract
    /// @param newInterestRate The new interest rate to set
    /// @dev The interest rate can only decrease
    function setInterestRate(uint256 newInterestRate) external onlyOwner {
        if (newInterestRate >= s_interestRate) revert RebaseToken__InterestRateCanOnlyDecrease();
        s_interestRate = newInterestRate;
        emit InterestRateSet(newInterestRate);
    }

    /// @notice Get the principle balance of a user. This is the number of tokens that have currently been minted to
    /// the user, not including any interest that has accrued since the last time the user interacted with the protocol.
    /// @param user to get the principle balance of
    /// @return principleBalance of the user
    function principleBalanceOf(address user) external view returns (uint256) {
        return super.balanceOf(user);
    }

    /// @notice Mint the user token when they deposit into vault
    /// @param to User to mint tokens to
    /// @param amount Amount of tokens to mint to user
    function mint(address to, uint256 amount, uint256 userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(to);
        s_userInterestRate[to] = userInterestRate;
        _mint(to, amount);
    }

    /// @notice Burn the user tokens when they withdraw from the vault
    /// @param from the user to burn tokens from
    /// @param amount the amount of tokens to burn
    function burn(address from, uint256 amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(from);
        _burn(from, amount);
    }

    /// @notice Calculate the balance for the user including the interest that has accumulated since last update
    /// @param user User who's balance to calculate and return
    /// @return balance User's calculated balance including interest
    function balanceOf(address user) public view override(ERC20, IERC20) returns (uint256) {
        // get the current principle balance of the user (tokens that have actually been minted to the user)
        // multiply the principal balance by the interest that has accumulated since the balance was last updated
        // review - function multiples (number of tokens minted by user) * (1 + accruedInterest). HOWEVER
        // if the user burns tokens, we mint them the accrued interest and then increase their balance,
        // which means the balanceOf() function will return a higher number of the interest earned from the
        // burned tokens
        return (super.balanceOf(user) * _calculateUserAccumulatedInterestSinceLastUpdate(user) / PRECISION_FACTOR);
    }

    /// @notice transfer tokens from one user to another
    /// @param to user to transfer tokens to
    /// @param amount of tokens to transfer
    /// @return true if transfer was successful
    function transfer(address to, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(to);
        if (amount == type(uint256).max) {
            amount = balanceOf(msg.sender);
        }
        // @review -
        // 1. attacker deposits a small amount when interest rate is high
        // 2. attacker deposits large amount from different wallet when interest rate is low
        // 3. attacker transfers large amount to the wallet with high interest rate
        // they now have a high interest rate for a large deposit
        if (balanceOf(to) == 0) {
            s_userInterestRate[to] = s_userInterestRate[msg.sender];
        }
        return super.transfer(to, amount);
    }

    /// @notice transfer tokens from one user to another
    /// @param from user to transfer tokens from
    /// @param to user to transfer tokens to
    /// @param amount of tokens to transfer
    /// @return true if transfer was successful
    function transferFrom(address from, address to, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        _mintAccruedInterest(from);
        _mintAccruedInterest(to);
        if (amount == type(uint256).max) {
            amount = balanceOf(from);
        }
        if (balanceOf(to) == 0) {
            s_userInterestRate[to] = s_userInterestRate[from];
        }
        return super.transferFrom(from, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/
    /// @notice mint the accrued interest to the user since the last time they interacted with the protocol
    /// @param user who to mint accrued interest to
    function _mintAccruedInterest(address user) internal {
        // (1) find their current balance of rebase tokens that have been minted to the user -> principle balance
        uint256 previousPrincipleBalance = super.balanceOf(user);
        // (2) calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(user);
        // calculate the number of tokens that need to be minted to the user -> (2) - (1)
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        // set the users last updated timestamp
        s_userLastUpdatedTimestamp[user] = block.timestamp;
        // call _mint to mint the tokens to the user
        _mint(user, balanceIncrease);
    }

    /// @notice Calculate the interest that has accumulated since the last update
    /// @param user who to calculate the interest accumulated for
    /// @return interest calculated interest accumulated since last update
    function _calculateUserAccumulatedInterestSinceLastUpdate(address user) internal view returns (uint256) {
        // going to be linear growth with time
        // 1. calculate time since last update
        // 2. calculate the amount of linear growth
        // (principal amount) + (principalAmount * userInterestRate * timeElapsed)
        // deposit: 10
        // interest rate: 0.5 tokens per second
        // time elapsed: 2 seconds
        // 10 + (10 * 0.5 * 2)
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[user];
        uint256 linearInterest = PRECISION_FACTOR + (s_userInterestRate[user] * timeElapsed);
        return linearInterest;
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the interest rate for the user
    /// @param user The user to get the interest rate for
    /// @return userInterestRate The interest rate for the user
    function getUserInterestRate(address user) external view returns (uint256) {
        return s_userInterestRate[user];
    }

    /// @notice Get the last updated timestamp for user
    /// @param user who to get last updated timestamp for
    /// @return lastUpdatedTimestamp last updated block.timestamp for user
    function getUserLastUpdatedTimestamp(address user) external view returns (uint256) {
        return s_userLastUpdatedTimestamp[user];
    }

    /// @notice Get the interest rate that is currently set for the contract. Any future depositors will receive this rate.
    /// @return interestRate
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /// @notice get the role that is required to mint and burn tokens
    /// @return MINT_AND_BURN_ROLE
    function getMintAndBurnRole() external pure returns (bytes32) {
        return MINT_AND_BURN_ROLE;
    }
}
