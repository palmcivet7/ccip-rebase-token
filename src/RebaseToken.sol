// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Rebase Token
/// @notice This is a crosschain rebase token that incentivizes users to deposit into a vault.
/// @notice The interest rate in the contract can only decrease.
/// @notice Each user will have their own interest rate, that is the global interest rate at the time of deposit.
contract RebaseToken is ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error RebaseToken__InterestRateCanOnlyDecrease();

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant PRECISION_FACTOR = 1e18;

    uint256 internal s_interestRate = 5e10;
    mapping(address user => uint256 interestRate) internal s_userInterestRate;
    mapping(address user => uint256 lastUpdatedTimestamp) internal s_userLastUpdatedTimestamp;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event InterestRateSet(uint256 newInterestRate);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() ERC20("Rebase Token", "RBT") {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Set the interest rate in the contract
    /// @param newInterestRate The new interest rate to set
    /// @dev The interest rate can only decrease
    function setInterestRate(uint256 newInterestRate) external {
        if (newInterestRate >= s_interestRate) revert RebaseToken__InterestRateCanOnlyDecrease();
        s_interestRate = newInterestRate;
        emit InterestRateSet(newInterestRate);
    }

    /// @notice Mint the user token when they deposit into vault
    /// @param to User to mint tokens to
    /// @param amount Amount of tokens to mint to user
    function mint(address to, uint256 amount) external {
        _mintAccruedInterest(to);
        s_userInterestRate[to] = s_interestRate;
        _mint(to, amount);
    }

    /// @notice Calculate the balance for the user including the interest that has accumulated since last update
    /// @param user User who's balance to calculate and return
    /// @return balance User's calculated balance including interest
    function balanceOf(address user) public view override returns (uint256) {
        // get the current principle balance of the user (tokens that have actually been minted to the user)
        // multiply the principal balance by the interest that has accumulated since the balance was last updated
        return (super.balanceOf(user) * _calculateUserAccumulatedInterestSinceLastUpdate(user) / PRECISION_FACTOR);
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/
    function _mintAccruedInterest(address user) internal {
        // find their current balance of rebase tokens that have been minted to the user
        // calculate their current balance including any interest
        // calculate the number of tokens that need to be minted to the user
        // call _mint to mint the tokens to the user
        s_userLastUpdatedTimestamp[user] = block.timestamp;
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
}
