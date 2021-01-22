// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

contract InvalidUSMFUMRecipient {
    bytes4 private constant FUNC_SELECTOR = bytes4(keccak256("isInvalidUSMFUMRecipient()"));

    function isInvalidUSMFUMRecipient() public pure
    {
        //invalid = false;
    }

    function external_call(address destination, uint value, uint dataLength, bytes memory data) internal returns (bool) {
        bool result;
        assembly {
            let x := mload(0x40)        // "Allocate" memory for output (0x40 is where "free memory" pointer is stored by convention)
            let d := add(data, 32)      // First 32 bytes are the padded length of data, so exclude that
            //let g := sub(gas(), 34710)
            result := call(
                sub(gas(), 34710),      // 34710 is the value that solidity is currently emitting
                                        // It includes callGas (700) + callVeryLow (3, to pay for SUB) + callValueTransferGas (9000) +
                                        // callNewAccountGas (25000, in case the destination address does not exist and needs creating)
                destination,
                value,
                d,
                dataLength,             // Size of the input (in bytes) - this is what fixes the padding problem
                x,
                0                       // Output is ignored, therefore the output size is zero
            )
        }
        return result;
    }

    function isRecipientInvalid(address recipient) internal returns (bool) {
        bool success;
        bytes memory data = abi.encodeWithSelector(FUNC_SELECTOR);
        assembly {
            success := call(
                gas(),          // gas remaining
                recipient,      // destination address
                0,              // no ether
                add(data, 32),  // input buffer (starts after the first 32 bytes in the `data` array)
                mload(data),    // input length (loaded from the first 32 bytes in the `data` array)
                0,              // output buffer
                0               // output length
            )
        }
        return success;
    }
}
