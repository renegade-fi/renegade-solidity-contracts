//! Generate zero values for Merkle trees used in Renegade contracts
//!
//! This tool generates a Solidity file with predefined Merkle tree zero values.

use anyhow::{anyhow, Result};
use clap::Parser;
use renegade_constants::{Scalar, MERKLE_HEIGHT};
use renegade_crypto::hash::compute_poseidon_hash;
use std::fs::File;
use std::io::Write;
use std::path::PathBuf;
use tiny_keccak::{Hasher, Keccak};

/// Name of the Solidity contract to generate
const CONTRACT_NAME: &str = "MerkleZeros";
/// The string that is used to create leaf zero values
const LEAF_KECCAK_PREIMAGE: &str = "renegade";

/// Command line arguments for the merkle-zeros-codegen binary
#[derive(Parser, Debug)]
#[clap(author, version, about)]
struct Args {
    /// Path to output directory for the generated Solidity file
    #[clap(short, long, default_value = "./")]
    output_dir: PathBuf,
}

/// Generate the Solidity contract with Merkle tree zero values
fn generate_solidity_contract() -> Result<String> {
    // Contract header
    let mut contract = String::new();
    contract.push_str("// SPDX-License-Identifier: MIT\n");
    contract.push_str("pragma solidity ^0.8.0;\n\n");
    contract.push_str("// ⚠ ️WARNING: This file is auto-generated by `codegen/merkle-zeros`. Do not edit directly.\n");
    contract.push_str(&format!("library {} {{\n", CONTRACT_NAME));

    // Add a comment to indicate the preimage
    contract.push_str("\t// LEAF_ZERO_VALUE is the keccak256 hash of the string \"");
    contract.push_str(LEAF_KECCAK_PREIMAGE);
    contract.push_str("\"\n\n");

    // Generate the zero values for each height in the Merkle tree
    let zero_values = generate_zero_values();
    let root = zero_values[MERKLE_HEIGHT];

    // Add the constant values to the contract
    for (i, value) in zero_values[..MERKLE_HEIGHT].iter().rev().enumerate() {
        contract.push_str(&format!(
            "\tuint256 constant public ZERO_VALUE_{} = {};\n",
            i, value
        ));
    }
    contract.push_str(&format!(
        "\tuint256 constant public ZERO_VALUE_ROOT = {};\n",
        root
    ));

    // Add an assembly-based getter function for gas-efficient constant-time access
    contract.push_str("\n\t/// @notice Get zero value for a given height\n");
    contract.push_str("\t/// @param height The height in the Merkle tree\n");
    contract.push_str("\t/// @return The zero value for the given height\n");
    contract
        .push_str("\tfunction getZeroValue(uint256 height) internal pure returns (uint256) {\n");
    contract.push_str("\t\t// Require height to be within valid range\n");
    contract.push_str("\t\trequire(height <= 31, \"MerkleZeros: height must be <= 31\");\n\n");

    contract.push_str("\t\tuint256 result;\n");
    contract.push_str("\t\tassembly {\n");
    contract.push_str("\t\t\tswitch height\n");

    // Generate all the assembly cases with direct constant values
    for i in 0..MERKLE_HEIGHT {
        contract.push_str(&format!(
            "\t\t\tcase {} {{ result := ZERO_VALUE_{} }}\n",
            i, i
        ));
    }

    // Remove the default case for assembly since require will handle invalid values
    contract.push_str("\t\t}\n");
    contract.push_str("\t}\n");

    // Close contract
    contract.push_str("}\n");
    Ok(contract)
}

/// Generate the zero values for each height in the Merkle tree
fn generate_zero_values() -> Vec<Scalar> {
    let mut result = vec![generate_leaf_zero_value()];
    for height in 1..=MERKLE_HEIGHT {
        let last_zero = result[height - 1];
        let next_zero = compute_poseidon_hash(&[last_zero, last_zero]);
        result.push(next_zero);
    }
    result
}

/// Generate the zero value for a leaf in the Merkle tree
fn generate_leaf_zero_value() -> Scalar {
    // Create a Keccak-256 hasher
    let mut hasher = Keccak::v256();

    // Prepare input and output buffers
    let input = LEAF_KECCAK_PREIMAGE.as_bytes();
    let mut output = [0u8; 32]; // 256 bits = 32 bytes

    // Compute the hash
    hasher.update(input);
    hasher.finalize(&mut output);

    Scalar::from_be_bytes_mod_order(&output)
}

/// Entrypoint
fn main() -> Result<()> {
    // Parse command line arguments
    let args = Args::parse();
    println!("Generating Merkle tree zero values");

    // Generate Solidity contract with Merkle tree zero values
    let contract = generate_solidity_contract()?;

    // Ensure output directory and file exist
    if !args.output_dir.exists() {
        std::fs::create_dir_all(&args.output_dir)
            .map_err(|e| anyhow!("Failed to create output directory: {}", e))?;
    }
    let output_file = args.output_dir.join(format!("{}.sol", CONTRACT_NAME));

    // Write to file
    let mut file =
        File::create(&output_file).map_err(|e| anyhow!("Failed to create output file: {}", e))?;
    file.write_all(contract.as_bytes())
        .map_err(|e| anyhow!("Failed to write to output file: {}", e))?;

    println!(
        "Successfully generated Merkle zero values and wrote them to {}",
        output_file.display()
    );
    Ok(())
}
