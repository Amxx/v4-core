// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import {Currency, CurrencyLibrary} from '../libraries/CurrencyLibrary.sol';
import {CurrencyDelta} from '../libraries/CurrencyDelta.sol';
import {Commands} from '../libraries/Commands.sol';
import {IERC20Minimal} from '../interfaces/external/IERC20Minimal.sol';

import {Currency} from '../libraries/CurrencyLibrary.sol';
import {IExecuteCallback} from '../interfaces/callback/IExecuteCallback.sol';
import {IPoolManager} from '../interfaces/IPoolManager.sol';

contract PoolDonateTest is IExecuteCallback {
    using CurrencyLibrary for Currency;

    IPoolManager public immutable manager;

    constructor(IPoolManager _manager) {
        manager = _manager;
    }

    struct CallbackData {
        address sender;
        IPoolManager.PoolKey key;
        uint256 amount0;
        uint256 amount1;
    }

    function donate(
        IPoolManager.PoolKey memory key,
        uint256 amount0,
        uint256 amount1
    ) external payable returns (IPoolManager.BalanceDelta memory delta) {
        bytes memory commands = new bytes(1);
        commands[0] = Commands.DONATE;
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(key, amount0, amount1);
        delta = abi.decode(
            manager.execute(commands, inputs, abi.encode(CallbackData(msg.sender, key, amount0, amount1))),
            (IPoolManager.BalanceDelta)
        );

        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            CurrencyLibrary.NATIVE.transfer(msg.sender, ethBalance);
        }
    }

    function executeCallback(CurrencyDelta[] memory deltas, bytes calldata rawData) external returns (bytes memory) {
        require(msg.sender == address(manager));

        CallbackData memory data = abi.decode(rawData, (CallbackData));
        IPoolManager.BalanceDelta memory result;

        for (uint256 i = 0; i < deltas.length; i++) {
            CurrencyDelta memory delta = deltas[i];
            if (i == 0) {
                result.amount0 = delta.delta;
            } else if (i == 1) {
                result.amount1 = delta.delta;
            }

            if (delta.delta > 0) {
                if (delta.currency.isNative()) {
                    payable(address(manager)).transfer(uint256(delta.delta));
                } else {
                    IERC20Minimal(Currency.unwrap(delta.currency)).transferFrom(
                        data.sender,
                        address(manager),
                        uint256(delta.delta)
                    );
                }
            }
        }

        return abi.encode(result);
    }
}
