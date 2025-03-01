// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BN254 } from "solidity-bn254/BN254.sol";
import { IHasher } from "../poseidon2/IHasher.sol";
import { DarkpoolConstants } from "../darkpool/Constants.sol";

/// @title MerkleTreeLib
/// @notice Library for Merkle tree operations

library MerkleTreeLib {
    /// @notice Structure containing Merkle tree state
    struct MerkleTree {
        /// @notice The next available leaf index
        uint64 nextIndex;
        /// @notice The current root of the tree
        BN254.ScalarField root;
        /// @notice The current path of siblings for the next leaf to be inserted.
        BN254.ScalarField[] siblingPath;
        /// @notice The root history, mapping from historic roots to a boolean
        mapping(BN254.ScalarField => bool) rootHistory;
    }

    /// @notice Initialize the Merkle tree
    /// @param tree The tree to initialize
    function initialize(MerkleTree storage tree) internal {
        tree.nextIndex = 0;
        tree.root = BN254.ScalarField.wrap(0);

        // Initialize the sibling path
        BN254.ScalarField zero = BN254.ScalarField.wrap(0);
        tree.siblingPath = new BN254.ScalarField[](DarkpoolConstants.MERKLE_DEPTH);
        for (uint256 i = 0; i < DarkpoolConstants.MERKLE_DEPTH; i++) {
            tree.siblingPath[i] = zero;
        }
    }

    /// @notice Returns the root of the tree
    /// @param tree The tree to get the root of
    /// @return The root of the tree
    function root(MerkleTree storage tree) internal view returns (BN254.ScalarField) {
        return tree.root;
    }

    /// @notice Returns whether the given root is in the history of the tree
    /// @param tree The tree to check the root history of
    /// @param root The root to check
    /// @return Whether the root is in the history of the tree
    function rootInHistory(MerkleTree storage tree, BN254.ScalarField root) internal view returns (bool) {
        return tree.rootHistory[root];
    }

    /// @notice Insert a leaf into the tree
    /// @param tree The tree to insert the leaf into
    /// @param leaf The leaf to insert
    function insertLeaf(MerkleTree storage tree, BN254.ScalarField leaf, IHasher hasher) internal {
        // Compute the hash of the leaf into the tree
        uint256 idx = tree.nextIndex;
        uint256 leafUint = BN254.ScalarField.unwrap(leaf);
        uint256[] memory sisterLeaves = new uint256[](tree.siblingPath.length);
        for (uint256 i = 0; i < tree.siblingPath.length; i++) {
            sisterLeaves[i] = BN254.ScalarField.unwrap(tree.siblingPath[i]);
        }
        uint256[] memory hashes = hasher.merkleHash(idx, leafUint, sisterLeaves);

        // Update the tree
        tree.nextIndex++;
        BN254.ScalarField newRoot = BN254.ScalarField.wrap(hashes[hashes.length - 1]);
        tree.root = newRoot;
        tree.rootHistory[newRoot] = true;

        // Update the sibling paths, switching between left and right nodes as appropriate
        for (uint256 i = 0; i < DarkpoolConstants.MERKLE_DEPTH; i++) {
            uint256 idxBit = (idx >> i) & 1;
            if (idxBit == 0) {
                // Left node, the new sibling is the intermediate hash computed in the merkle insertion
                tree.siblingPath[i] = BN254.ScalarField.wrap(hashes[i]);
            } else {
                // Right node, the new sibling is in a new sub-tree, and is the zero value
                // for this depth in the tree
                // TODO: Use depth-dependent zero values
                tree.siblingPath[i] = BN254.ScalarField.wrap(0);
            }
        }
    }
}
