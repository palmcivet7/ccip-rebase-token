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
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";

contract CrossChainTest is Test {
    address owner = makeAddr("owner");
    address user = makeAddr("user");

    uint256 constant SEND_VALUE = 1e5;

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
        // ethSepoliaFork = vm.createSelectFork(vm.envString("SEPOLIA_RPC_URL"));
        // arbSepoliaFork = vm.createFork(vm.envString("ARBITRUM_SEPOLIA_RPC_URL"));
        ethSepoliaFork = vm.createSelectFork("eth-sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // 1. Deploy and configure on Eth Sepolia
        /// @dev get eth sepolia network details
        ethSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

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
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

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
            remoteTokenAddress: abi.encode(remoteToken),
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

    function bridgeTokens(
        uint256 amountToBridge,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken,
        RebaseToken remoteToken
    ) public {
        vm.selectFork(localFork);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(localToken), amount: amountToBridge});

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: localNetworkDetails.linkAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 500_000}))
        });

        // struct EVM2AnyMessage {
        //     bytes receiver; // abi.encode(receiver address) for dest EVM chains
        //     bytes data; // Data payload
        //     EVMTokenAmount[] tokenAmounts; // Token transfers
        //     address feeToken; // Address of feeToken. address(0) means you will send msg.value.
        //     bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV2)
        //   }

        // struct EVMTokenAmount {
        //     address token; // token address on the local chain.
        //     uint256 amount; // Amount of tokens.
        //   }

        uint256 fee =
            IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message);

        ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee);

        vm.prank(user);
        IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fee);
        vm.prank(user);
        localToken.approve(localNetworkDetails.routerAddress, amountToBridge);

        uint256 localBalanceBefore = localToken.balanceOf(user);

        vm.prank(user);
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);

        uint256 localBalanceAfter = localToken.balanceOf(user);

        assertEq(localBalanceAfter, localBalanceBefore - amountToBridge);
        // uint256 localUserInterestRate = localToken.getUserInterestRate(user);

        vm.selectFork(remoteFork);
        uint256 remoteBalanceBefore = remoteToken.balanceOf(user);
        vm.selectFork(localFork);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);
        uint256 remoteBalanceAfter = remoteToken.balanceOf(user);
        // vm.warp(block.timestamp + 20 minutes);

        assertEq(remoteBalanceAfter, remoteBalanceBefore + amountToBridge);
        // uint256 remoteUserInterestRate = remoteToken.getUserInterestRate(user);
        // assertEq(localUserInterestRate, remoteUserInterestRate);
    }

    function testBridgeAllTokens() public {
        vm.selectFork(ethSepoliaFork);
        vm.deal(user, SEND_VALUE);
        vm.prank(user);
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        assertEq(ethSepoliaToken.balanceOf(user), SEND_VALUE);
        bridgeTokens(
            SEND_VALUE,
            ethSepoliaFork,
            arbSepoliaFork,
            ethSepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            ethSepoliaToken,
            arbSepoliaToken
        );
        vm.selectFork(arbSepoliaFork);
        vm.warp(block.timestamp + 20 minutes);
        bridgeTokens(
            arbSepoliaToken.balanceOf(user),
            arbSepoliaFork,
            ethSepoliaFork,
            arbSepoliaNetworkDetails,
            ethSepoliaNetworkDetails,
            arbSepoliaToken,
            ethSepoliaToken
        );
    }
}
