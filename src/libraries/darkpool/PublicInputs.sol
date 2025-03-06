// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BN254 } from "solidity-bn254/BN254.sol";
import { ExternalTransfer, PublicRootKey, OrderSettlementIndices } from "./Types.sol";

// This file represents the public inputs (statements) for various proofs used by the darkpool

// -------------------
// | Statement Types |
// -------------------

/// @title ValidWalletCreateStatement
/// @notice The statement type for the `VALID WALLET CREATE` proof
struct ValidWalletCreateStatement {
    /// @dev The commitment to the wallet's private shares
    BN254.ScalarField privateShareCommitment;
    /// @dev The public wallet shares of the wallet
    BN254.ScalarField[] publicShares;
}

/// @title ValidWalletUpdateStatement
/// @notice The statement type for the `VALID WALLET UPDATE` proof
struct ValidWalletUpdateStatement {
    /// @dev The nullifier of the previous wallet
    BN254.ScalarField previousNullifier;
    /// @dev A commitment to the new wallet's private shares
    BN254.ScalarField newPrivateShareCommitment;
    /// @dev The new public shares of the wallet
    BN254.ScalarField[] newPublicShares;
    /// @dev The global Merkle root that the old wallet shares open into
    BN254.ScalarField merkleRoot;
    /// @dev The external transfer in the update, zeroed out if there is no transfer
    ExternalTransfer externalTransfer;
    /// @dev The old public root key of the keychain
    PublicRootKey oldPkRoot;
}

/// @title ValidReblindStatement
/// @notice The statement type for the `VALID REBLIND` proof
struct ValidReblindStatement {
    /// @dev The nullifier of the original wallet
    BN254.ScalarField originalSharesNullifier;
    /// @dev A commitment to the new private shares of the reblinded wallet
    BN254.ScalarField newPrivateShareCommitment;
    /// @dev The global Merkle root that the new wallet shares open into
    BN254.ScalarField merkleRoot;
}

/// @title ValidCommitmentsStatement
/// @notice The statement type for the `VALID COMMITMENTS` proof
struct ValidCommitmentsStatement {
    /// @dev The order settlement indices of the party for which this statement is generated
    OrderSettlementIndices indices;
}

/// @title ValidMatchSettleStatement
/// @notice The statement type for the `VALID MATCH SETTLE` proof
struct ValidMatchSettleStatement {
    /// @dev The modified public shares of the first party
    BN254.ScalarField[] firstPartyPublicShares;
    /// @dev The modified public shares of the second party
    BN254.ScalarField[] secondPartyPublicShares;
    /// @dev The settlement indices of the first party
    OrderSettlementIndices firstPartySettlementIndices;
    /// @dev The settlement indices of the second party
    OrderSettlementIndices secondPartySettlementIndices;
    /// @dev The protocol fee rate used for the match
    /// @dev Note that this is a fixed point value encoded as a uint256
    /// @dev so the true fee rate is `protocolFeeRate / 2^{FIXED_POINT_PRECISION}`
    /// @dev Currently, the fixed point precision is 63
    uint256 protocolFeeRate;
}

// ------------------------
// | Scalar Serialization |
// ------------------------

/// @title StatementSerializer Library for serializing statement types to scalar arrays
library StatementSerializer {
    using StatementSerializer for ValidWalletCreateStatement;
    using StatementSerializer for ValidWalletUpdateStatement;
    using StatementSerializer for ValidReblindStatement;
    using StatementSerializer for ValidCommitmentsStatement;
    using StatementSerializer for ValidMatchSettleStatement;
    using StatementSerializer for ExternalTransfer;
    using StatementSerializer for PublicRootKey;
    using StatementSerializer for OrderSettlementIndices;

    /// @notice The number of scalar field elements in a ValidWalletCreateStatement
    uint256 constant VALID_WALLET_CREATE_SCALAR_SIZE = 71;
    /// @notice The number of scalar field elements in a ValidWalletUpdateStatement
    uint256 constant VALID_WALLET_UPDATE_SCALAR_SIZE = 81;
    /// @notice The number of scalar field elements in a ValidReblindStatement
    uint256 constant VALID_REBLIND_SCALAR_SIZE = 3;
    /// @notice The number of scalar field elements in a ValidCommitmentsStatement
    uint256 constant VALID_COMMITMENTS_SCALAR_SIZE = 3;
    /// @notice The number of scalar field elements in a ValidMatchSettleStatement
    uint256 constant VALID_MATCH_SETTLE_SCALAR_SIZE = 147;

    // --- Valid Wallet Create --- //

    /// @notice Serializes a ValidWalletCreateStatement into an array of scalar field elements
    /// @param self The statement to serialize
    /// @return serialized The serialized statement as an array of scalar field elements
    function scalarSerialize(ValidWalletCreateStatement memory self)
        internal
        pure
        returns (BN254.ScalarField[] memory)
    {
        // Create array with size = 1 (for privateShareCommitment) + publicShares.length
        BN254.ScalarField[] memory serialized = new BN254.ScalarField[](VALID_WALLET_CREATE_SCALAR_SIZE);

        // Add the wallet commitment
        serialized[0] = self.privateShareCommitment;

        // Add all public shares
        for (uint256 i = 0; i < self.publicShares.length; i++) {
            serialized[i + 1] = self.publicShares[i];
        }

        return serialized;
    }

    // --- Valid Wallet Update --- //

    /// @notice Serializes a ValidWalletUpdateStatement into an array of scalar field elements
    /// @param self The statement to serialize
    /// @return serialized The serialized statement as an array of scalar field elements
    function scalarSerialize(ValidWalletUpdateStatement memory self)
        internal
        pure
        returns (BN254.ScalarField[] memory)
    {
        BN254.ScalarField[] memory serialized = new BN254.ScalarField[](VALID_WALLET_UPDATE_SCALAR_SIZE);
        serialized[0] = self.previousNullifier;
        serialized[1] = self.newPrivateShareCommitment;

        // Copy the public shares
        uint256 n = self.newPublicShares.length;
        for (uint256 i = 0; i < n; i++) {
            serialized[i + 2] = self.newPublicShares[i];
        }

        serialized[n + 2] = self.merkleRoot;
        BN254.ScalarField[] memory externalTransferSerialized = self.externalTransfer.scalarSerialize();
        for (uint256 i = 0; i < externalTransferSerialized.length; i++) {
            serialized[n + 3 + i] = externalTransferSerialized[i];
        }

        BN254.ScalarField[] memory oldPkRootSerialized = self.oldPkRoot.scalarSerialize();
        for (uint256 i = 0; i < oldPkRootSerialized.length; i++) {
            serialized[n + 3 + externalTransferSerialized.length + i] = oldPkRootSerialized[i];
        }

        return serialized;
    }

    // --- Valid Reblind --- //

    /// @notice Serializes a ValidReblindStatement into an array of scalar field elements
    /// @param self The statement to serialize
    /// @return serialized The serialized statement as an array of scalar field elements
    function scalarSerialize(ValidReblindStatement memory self) internal pure returns (BN254.ScalarField[] memory) {
        BN254.ScalarField[] memory serialized = new BN254.ScalarField[](VALID_REBLIND_SCALAR_SIZE);
        serialized[0] = self.originalSharesNullifier;
        serialized[1] = self.newPrivateShareCommitment;
        serialized[2] = self.merkleRoot;

        return serialized;
    }

    // --- Valid Commitments --- //

    /// @notice Serializes a ValidCommitmentsStatement into an array of scalar field elements
    /// @param self The statement to serialize
    /// @return serialized The serialized statement as an array of scalar field elements
    function scalarSerialize(ValidCommitmentsStatement memory self)
        internal
        pure
        returns (BN254.ScalarField[] memory)
    {
        BN254.ScalarField[] memory serialized = new BN254.ScalarField[](VALID_COMMITMENTS_SCALAR_SIZE);
        serialized[0] = BN254.ScalarField.wrap(self.indices.balanceSend);
        serialized[1] = BN254.ScalarField.wrap(self.indices.balanceReceive);
        serialized[2] = BN254.ScalarField.wrap(self.indices.order);

        return serialized;
    }

    // --- Valid Match Settle --- //

    /// @notice Serializes a ValidMatchSettleStatement into an array of scalar field elements
    /// @param self The statement to serialize
    /// @return serialized The serialized statement as an array of scalar field elements
    function scalarSerialize(ValidMatchSettleStatement memory self)
        internal
        pure
        returns (BN254.ScalarField[] memory)
    {
        BN254.ScalarField[] memory serialized = new BN254.ScalarField[](VALID_MATCH_SETTLE_SCALAR_SIZE);

        // Copy the public shares
        uint256 n = self.firstPartyPublicShares.length;
        for (uint256 i = 0; i < n; i++) {
            serialized[i] = self.firstPartyPublicShares[i];
        }

        // Copy the second party public shares
        uint256 offset = self.firstPartyPublicShares.length;
        for (uint256 i = 0; i < n; i++) {
            serialized[offset + i] = self.secondPartyPublicShares[i];
        }

        // Copy the settlement indices
        offset += n;
        BN254.ScalarField[] memory firstPartySettlementIndicesSerialized =
            self.firstPartySettlementIndices.scalarSerialize();
        for (uint256 i = 0; i < firstPartySettlementIndicesSerialized.length; i++) {
            serialized[offset + i] = firstPartySettlementIndicesSerialized[i];
        }

        // Copy the second party settlement indices
        offset += firstPartySettlementIndicesSerialized.length;
        BN254.ScalarField[] memory secondPartySettlementIndicesSerialized =
            self.secondPartySettlementIndices.scalarSerialize();
        for (uint256 i = 0; i < secondPartySettlementIndicesSerialized.length; i++) {
            serialized[offset + i] = secondPartySettlementIndicesSerialized[i];
        }

        // Copy the protocol fee rate
        serialized[serialized.length - 1] = BN254.ScalarField.wrap(self.protocolFeeRate);
        return serialized;
    }

    // --- Types --- //

    /// @notice Serializes an ExternalTransfer into an array of scalar field elements
    /// @param self The transfer to serialize
    /// @return serialized The serialized transfer as an array of scalar field elements
    function scalarSerialize(ExternalTransfer memory self) internal pure returns (BN254.ScalarField[] memory) {
        BN254.ScalarField[] memory serialized = new BN254.ScalarField[](4);

        serialized[0] = BN254.ScalarField.wrap(uint256(uint160(self.account)));
        serialized[1] = BN254.ScalarField.wrap(uint256(uint160(self.mint)));
        serialized[2] = BN254.ScalarField.wrap(self.amount);
        serialized[3] = BN254.ScalarField.wrap(uint256(self.transferType));

        return serialized;
    }

    /// @notice Serializes a PublicRootKey into an array of scalar field elements
    /// @param self The key to serialize
    /// @return serialized The serialized key as an array of scalar field elements
    function scalarSerialize(PublicRootKey memory self) internal pure returns (BN254.ScalarField[] memory) {
        BN254.ScalarField[] memory serialized = new BN254.ScalarField[](4);

        serialized[0] = self.x[0];
        serialized[1] = self.x[1];
        serialized[2] = self.y[0];
        serialized[3] = self.y[1];

        return serialized;
    }

    /// @notice Serializes an OrderSettlementIndices into an array of scalar field elements
    /// @param self The indices to serialize
    /// @return serialized The serialized indices as an array of scalar field elements
    function scalarSerialize(OrderSettlementIndices memory self) internal pure returns (BN254.ScalarField[] memory) {
        BN254.ScalarField[] memory serialized = new BN254.ScalarField[](3);

        serialized[0] = BN254.ScalarField.wrap(self.balanceSend);
        serialized[1] = BN254.ScalarField.wrap(self.balanceReceive);
        serialized[2] = BN254.ScalarField.wrap(self.order);

        return serialized;
    }
}

// Enable the library for the statement type
using StatementSerializer for ValidWalletCreateStatement;
