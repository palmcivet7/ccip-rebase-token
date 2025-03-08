// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {RebaseToken, IRebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool, IERC20} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {RegistryModuleOwnerCustom} from
    "@ccip/contracts//src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts//src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";

contract CrossChainTest is Test {
    address owner = makeAddr("owner");

    uint256 ethSepoliaFork;
    uint256 arbSepoliaFork;

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    RebaseToken ethSepoliaToken;
    RebaseToken arbSepoliaToken;

    Vault vault;

    RebaseTokenPool ethSepoliaPool;
    RebaseTokenPool arbSepoliaPool;

    Register.NetworkDetails ethSepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    function setUp() public {
        ethSepoliaFork = vm.createSelectFork("eth-sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // 1. Deploy and configure on Eth Sepolia
        /// @dev get eth sepolia network details
        ethSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(ethSepoliaFork);

        /// @dev prank owner
        vm.startPrank(owner);
        /// @dev deploy token, vault and pool
        ethSepoliaToken = new RebaseToken();
        vault = new Vault(address(ethSepoliaToken));
        ethSepoliaPool = new RebaseTokenPool(
            IERC20(address(ethSepoliaToken)),
            new address[](0),
            ethSepoliaNetworkDetails.rmnProxyAddress,
            ethSepoliaNetworkDetails.routerAddress
        );

        /// @dev grant mint and burn role to vault and pool from token
        ethSepoliaToken.grantMintAndBurnRole(address(vault));
        ethSepoliaToken.grantMintAndBurnRole(address(ethSepoliaPool));

        /// @dev register admin, accept admin and set pool
        /// @notice these are CCIP admin functions
        RegistryModuleOwnerCustom(ethSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(ethSepoliaToken)
        );
        TokenAdminRegistry(ethSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(ethSepoliaToken));
        TokenAdminRegistry(ethSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(ethSepoliaToken), address(ethSepoliaPool)
        );
        vm.stopPrank();

        // 2. Deploy and configure on Arbitrum Sepolia
        /// @dev switch to arb fork
        vm.selectFork(arbSepoliaFork);
        /// @dev get arb sepolia network details
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(arbSepoliaFork);

        /// @dev prank owner
        vm.startPrank(owner);
        /// @dev deploy token and pool
        arbSepoliaToken = new RebaseToken();
        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)),
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );

        /// @dev grant mint and burn role to pool from token
        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));

        /// @dev register admin, accept admin and set pool
        /// @notice these are CCIP admin functions
        RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(arbSepoliaToken)
        );
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(arbSepoliaToken), address(arbSepoliaPool)
        );
        vm.stopPrank();

        /// @dev configure token pools
        configureTokenPool(
            ethSepoliaFork,
            address(ethSepoliaPool),
            arbSepoliaNetworkDetails.chainSelector,
            address(arbSepoliaPool),
            address(arbSepoliaToken)
        );
        configureTokenPool(
            arbSepoliaFork,
            address(arbSepoliaPool),
            ethSepoliaNetworkDetails.chainSelector,
            address(ethSepoliaPool),
            address(ethSepoliaToken)
        );
    }

    function configureTokenPool(
        uint256 fork,
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteToken
    ) public {
        vm.stopPrank();

        vm.selectFork(fork);

        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePool);

        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: remotePoolAddresses,
            remoteTokenAddress: abi.encode(remotePool),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0})
        });

        // struct ChainUpdate {
        //     uint64 remoteChainSelector; // Remote chain selector
        //     bytes[] remotePoolAddresses; // Address of the remote pool, ABI encoded in the case of a remote EVM chain.
        //     bytes remoteTokenAddress; // Address of the remote token, ABI encoded in the case of a remote EVM chain.
        //     RateLimiter.Config outboundRateLimiterConfig; // Outbound rate limited config, meaning the rate limits for all of the onRamps for the given chain
        //     RateLimiter.Config inboundRateLimiterConfig; // Inbound rate limited config, meaning the rate limits for all of the offRamps for the given chain
        //   }

        // struct Config {
        //     bool isEnabled; // Indication whether the rate limiting should be enabled
        //     uint128 capacity; // ────╮ Specifies the capacity of the rate limiter
        //     uint128 rate; //  ───────╯ Specifies the rate of the rate limiter
        //   }

        uint64[] memory remoteChainSelectorsToRemove = new uint64[](0);
        vm.prank(owner);
        TokenPool(localPool).applyChainUpdates(remoteChainSelectorsToRemove, chainsToAdd);
    }
}
