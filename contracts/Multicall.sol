// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OApp, MessagingFee, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { OAppOptionsType3 } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";

import { MulticallCodes } from "./utils/MulticallCodes.sol";

contract Multicall is OApp, OAppOptionsType3, MulticallCodes {

    using OptionsBuilder for bytes;

    struct Call {
        address target;
        bytes callData;
        uint128 value;
    }

    struct CallBundle {
        Call[] calls;
        uint32 dstEid;
        uint128 gasLimit;
    }

    mapping(uint32 eid => mapping(bytes32 sender => uint64 nonce)) private receivedNonce;

    event LogCall(DeliveryCode code, Call call, uint256 value);
    event Confirmation(uint32 srcEid, bytes32 sender, uint64 nonce);
    event ReturnedData(bytes data);

    constructor(address _endpoint, address _delegate) OApp(_endpoint, _delegate) Ownable(_delegate) {}

    /**
     * @notice Sends a message to the destination chain.
     */
    function lzAggregate(
        CallBundle[] calldata _callsBundles,
        DeliveryCode _deliveryCode
    ) public payable returns (MessagingReceipt memory receipt) {
        uint256 length = _callsBundles.length;

        uint256 totalNativeFeeUsed = 0;
        uint256 remainingValue = msg.value;

        CallBundle calldata callBundle;

        if (_deliveryCode == DeliveryCode.ORDERED_DELIVERY) {
            for (uint i = 0; i < length; ) {
                callBundle = _callsBundles[i];

                _getPeerOrRevert(callBundle.dstEid);

                bytes memory payload = abi.encode(DeliveryCode.ORDERED_DELIVERY, callBundle.calls);

                uint128 totalETHValue = 0;

                for (uint j = 0; j < callBundle.calls.length; ) {
                    totalETHValue += callBundle.calls[j].value;
                    unchecked {++j;}
                }

                bytes memory options = OptionsBuilder
                    .newOptions()
                    .addExecutorLzReceiveOption(callBundle.gasLimit, totalETHValue)
                    .addExecutorOrderedExecutionOption();

                MessagingFee memory fee = _quote(callBundle.dstEid, payload, options, false);

                totalNativeFeeUsed += fee.nativeFee;
                remainingValue -= fee.nativeFee;

                require(remainingValue >= 0, "Insufficient gas fee");

                receipt = _lzSend(
                    callBundle.dstEid,
                    payload,
                    options,
                    MessagingFee(totalETHValue + fee.nativeFee, 0),
                    payable(msg.sender)
                );

                unchecked {
                    ++i;
                }
            }

            return receipt;
        }

        if (_deliveryCode == DeliveryCode.UNORDERED_DELIVERY) {}
    }

    /**
     * @notice Quotes the gas needed to pay for the full omnichain transaction in native gas or ZRO token.
     * @param _callBundles desc
     * @param _deliveryCode desc
     * @return nativeFee A `MessagingFee` struct containing the calculated gas fee in either the native token or ZRO token.
     */
    function quoteAggregate(
        CallBundle[] calldata _callBundles,
        DeliveryCode _deliveryCode
    ) public view returns (uint256 nativeFee) {
        uint256 length = _callBundles.length;
        CallBundle calldata callBundle;

        if (_deliveryCode == DeliveryCode.ORDERED_DELIVERY) {
            for (uint i = 0; i < length; ) {
                callBundle = _callBundles[i];

                bytes memory payload = abi.encode(_deliveryCode, callBundle.calls);

                uint128 totalETHValue = 0;

                for (uint j = 0; j < callBundle.calls.length; ) {
                    totalETHValue += callBundle.calls[j].value;
                    unchecked {++j;}
                }

                bytes memory options = OptionsBuilder
                    .newOptions()
                    .addExecutorLzReceiveOption(callBundle.gasLimit, totalETHValue)
                    .addExecutorOrderedExecutionOption();

                MessagingFee memory fee = _quote(callBundle.dstEid, payload, options, false);

                nativeFee += fee.nativeFee;

                unchecked {
                    ++i;
                }
            }

            return nativeFee;
        }

        if (_deliveryCode == DeliveryCode.UNORDERED_DELIVERY) {
            for (uint i = 0; i < length; ) {
                callBundle = _callBundles[i];

                bytes memory payload = abi.encode(_deliveryCode, callBundle.calls);

                uint128 totalETHValue = 0;

                for (uint j = 0; j < callBundle.calls.length; ) {
                    totalETHValue += callBundle.calls[j].value;
                    unchecked {++j;}
                }

                bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(callBundle.gasLimit, totalETHValue);

                MessagingFee memory fee = _quote(callBundle.dstEid, payload, options, false);

                nativeFee += fee.nativeFee;

                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
     * @dev Handles incoming LayerZero messages
     * @param _origin The origin information of the message
     * @param _message The message payload
     */
    function lzReceive(
        Origin calldata _origin,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) public payable override {
        (DeliveryCode code, Call[] memory calls) = abi.decode(_message, (DeliveryCode, Call[]));

        if (code == DeliveryCode.ORDERED_DELIVERY) {
            _acceptNonce(_origin.srcEid, _origin.sender, _origin.nonce);
        }

        uint256 length = calls.length;

        Call memory call;

        for (uint i = 0; i < length; ) {
            call = calls[i];

            (bool success, bytes memory returnData) = call.target.call{ value: call.value }(call.callData);

            unchecked {
                ++i;
            }
        }

        emit LogCall(code, call, msg.value);
    }

    /**
     * @dev Internal function override to handle incoming messages from another chain.
     * @dev _origin A struct containing information about the message sender.
     * @dev _guid A unique global packet identifier for the message.
     * @param payload The encoded message payload being received.
     *
     * @dev The following params are unused in the current implementation of the OApp.
     * @dev _executor The address of the Executor responsible for processing the message.
     * @dev _extraData Arbitrary data appended by the Executor to the message.
     *
     * Decodes the received payload and processes it as per the business logic defined in the function.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 /*_guid*/,
        bytes calldata payload,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        (bytes memory data) = abi.decode(payload, (bytes));

        emit ReturnedData(data);
    }

    function _payNative(uint256 _nativeFee) internal virtual override returns (uint256 nativeFee) {
        if (msg.value < _nativeFee) revert NotEnoughNative(msg.value);
        return _nativeFee;
    }

    /**
     * @dev Public function to get the next expected nonce for a given source endpoint and sender.
     * @param _srcEid Source endpoint ID.
     * @param _sender Sender's address in bytes32 format.
     * @return uint64 Next expected nonce.
     */
    function nextNonce(uint32 _srcEid, bytes32 _sender) public view virtual override returns (uint64) {
        return receivedNonce[_srcEid][_sender] + 1;
    }

    /**
     * @dev Internal function to accept nonce from the specified source endpoint and sender.
     * @param _srcEid Source endpoint ID.
     * @param _sender Sender's address in bytes32 format.
     * @param _nonce The nonce to be accepted.
     */
    function _acceptNonce(uint32 _srcEid, bytes32 _sender, uint64 _nonce) internal virtual {
        receivedNonce[_srcEid][_sender] += 1;
        require(_nonce == receivedNonce[_srcEid][_sender], "OApp: invalid nonce");
    }
}
