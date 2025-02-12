// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

contract TestUtils is Test {
    /// @dev The BN254 field modulus from roundUtils.huff
    uint256 constant PRIME = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;

    /// @dev Generates a random input modulo the PRIME
    /// Note that this is not uniformly distributed over the prime field, because of the "wraparound"
    /// but it suffices for fuzzing test inputs
    function randomFelt() internal returns (uint256) {
        return vm.randomUint() % PRIME;
    }

    /// @dev Generates a random input between [0, high)
    function randomUint(uint256 high) internal returns (uint256) {
        return TestUtils.randomUint(0, high);
    }

    /// @dev Generates a random input between [low, high)
    /// The returned value is not uniformly distributed over the range; there is wraparound.
    /// However, if high << 2^256, the distribution will be close to uniform.
    function randomUint(uint256 low, uint256 high) internal returns (uint256) {
        require(low <= high, "low must be less than or equal to high");
        if (low == high) {
            return low;
        }

        uint256 range = high - low;
        return low + (vm.randomUint() % range);
    }

    // --- FFI Helpers --- //

    /// @dev Helper to compile a Rust binary
    function compileRustBinary(string memory manifestPath) internal virtual {
        string[] memory compileInputs = new string[](5);
        compileInputs[0] = "cargo";
        compileInputs[1] = "+nightly-2024-09-01";
        compileInputs[2] = "build";
        compileInputs[3] = "--quiet";
        compileInputs[4] = string.concat("--manifest-path=", manifestPath);
        vm.ffi(compileInputs);
    }

    /// @dev Helper to run a binary and parse its output as a uint256 array
    function runBinaryGetArray(string[] memory args, string memory delimiter)
        internal
        virtual
        returns (uint256[] memory)
    {
        string memory response = runBinaryGetResponse(args);
        return parseStringToUintArray(response, delimiter);
    }

    /// @dev Helper to run a binary and parse its RES: prefixed output
    function runBinaryGetResponse(string[] memory args) internal virtual returns (string memory) {
        bytes memory res = vm.ffi(args);
        string memory str = string(res);

        // Strip the "RES:" prefix and parse
        // We prefix here to avoid the FFI interface interpreting the output as either raw bytes or a string
        require(
            bytes(str).length > 4 && bytes(str)[0] == "R" && bytes(str)[1] == "E" && bytes(str)[2] == "S"
                && bytes(str)[3] == ":",
            "Invalid output format"
        );

        // Extract everything after "RES:"
        bytes memory result = new bytes(bytes(str).length - 4);
        for (uint256 i = 4; i < bytes(str).length; i++) {
            result[i - 4] = bytes(str)[i];
        }
        return string(result);
    }

    /// @dev Helper to convert bytes to hex string
    function bytesToHexString(bytes memory data) internal pure virtual returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory result = new bytes(data.length * 2);

        for (uint256 i = 0; i < data.length; i++) {
            result[i * 2] = hexChars[uint8(data[i] >> 4)];
            result[i * 2 + 1] = hexChars[uint8(data[i] & 0x0f)];
        }

        return string(result);
    }

    /// @dev Helper to split a string by a delimiter
    function split(string memory _str, string memory _delim) internal pure virtual returns (string[] memory) {
        bytes memory str = bytes(_str);
        bytes memory delim = bytes(_delim);

        // Count number of delimiters to size array
        uint256 count = 1;
        for (uint256 i = 0; i < str.length; i++) {
            if (str[i] == delim[0]) {
                count++;
            }
        }

        string[] memory parts = new string[](count);
        count = 0;

        // Track start of current part
        uint256 start = 0;

        // Split into parts
        for (uint256 i = 0; i < str.length; i++) {
            if (str[i] == delim[0]) {
                parts[count] = substring(str, start, i);
                start = i + 1;
                count++;
            }
        }
        // Add final part
        parts[count] = substring(str, start, str.length);

        return parts;
    }

    /// @dev Helper to get a substring
    function substring(bytes memory _str, uint256 _start, uint256 _end) internal pure virtual returns (string memory) {
        bytes memory result = new bytes(_end - _start);
        for (uint256 i = _start; i < _end; i++) {
            result[i - _start] = _str[i];
        }
        return string(result);
    }

    /// @dev Helper to parse a string of space-separated numbers into a uint256 array
    function parseStringToUintArray(string memory str, string memory delimiter)
        internal
        virtual
        returns (uint256[] memory)
    {
        string[] memory parts = split(str, delimiter);
        uint256[] memory values = new uint256[](parts.length);
        for (uint256 i = 0; i < parts.length; i++) {
            values[i] = vm.parseUint(parts[i]);
        }
        return values;
    }
}
