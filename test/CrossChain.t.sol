// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {RebaseToken, IRebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool, IERC20} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {CCIPLocalSimulatorFork} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {RegistryModuleOwnerCustom} from
    "@chainlink/contracts-ccip/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@chainlink/contracts-ccip/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";

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
        vault = new Vault(IRebaseToken(address(ethSepoliaToken)));
        sepoliaPool = new RebaseTokenPool(
            IERC20(address(ethSepoliaToken)),
            new address[](0),
            ethSepoliaNetworkDetails.rmnProxy,
            ethSepoliaNetworkDetails.router
        );

        /// @dev grant mint and burn role to vault and pool from token
        ethSepoliaToken.grantMintAndBurnRole(address(vault));
        ethSepoliaToken.grantMintAndBurnRole(address(sepoliaPool));

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
            arbSepoliaNetworkDetails.rmnProxy,
            arbSepoliaNetworkDetails.router
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
    }
}
