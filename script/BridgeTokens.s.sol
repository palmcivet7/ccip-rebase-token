// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";

import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";

import {IERC20} from "../src/RebaseTokenPool.sol";

contract BridgeTokensScript is Script {
    function run(
        address tokenToSend,
        uint256 amountToSend,
        address receiver,
        address link,
        address ccipRouter,
        uint64 destinationChainSelector
    ) public {
        vm.startBroadcast();

        /// @dev create tokenAmounts array
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: tokenToSend, amount: amountToSend});

        /// @dev create evm2any message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: link,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        });

        /// @dev get ccip fee and approve router to spend link
        uint256 ccipFee = IRouterClient(ccipRouter).getFee(destinationChainSelector, message);
        IERC20(link).approve(ccipRouter, ccipFee);
        /// @dev approve router to spend token to send
        IERC20(tokenToSend).approve(ccipRouter, amountToSend);

        /// @dev ccip send
        IRouterClient(ccipRouter).ccipSend(destinationChainSelector, message);

        vm.stopBroadcast();
    }
}
