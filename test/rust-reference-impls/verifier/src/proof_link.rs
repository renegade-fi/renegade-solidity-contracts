//! Circuits with proof linking groups allocated
//!
//! We define two circuits, one which constrains the product of its witness values
//! and one which constrains their sum. We create a linking group between `LINKING_WITNESS_SIZE`
//! elements in each circuit's witness.

use super::*;
use mpc_plonk::{errors::PlonkError, proof_system::PlonkKzgSnark, transcript::SolidityTranscript};
use mpc_relation::{proof_linking::LinkableCircuit, traits::Circuit, Variable};
use renegade_circuit_macros::circuit_type;
use renegade_circuit_types::{traits::*, PlonkCircuit};
use renegade_constants::{Scalar, ScalarField};

pub(crate) const LINKING_WITNESS_SIZE: usize = 5;
pub(crate) const LINKING_GROUP_NAME: &str = "sum-and-product-link-group";

// -----------------------
// | Circuit Definitions |
// -----------------------

// --- Circuit 1 --- //

/// The witness type for the sum circuit, the witness values to be summed
#[derive(Clone, Debug, Default)]
#[circuit_type(singleprover_circuit)]
pub(crate) struct SumCircuitWitness {
    /// The shared witness values
    #[link_groups = "sum-and-product-link-group"]
    pub shared_witness: [Scalar; LINKING_WITNESS_SIZE],
    /// A witness value specific to this circuit
    pub private_witness: Scalar,
}

impl SumCircuitWitness {
    /// Derive the statement from the witness
    pub fn statement(&self) -> Scalar {
        let mut sum = Scalar::zero();
        for i in 0..LINKING_WITNESS_SIZE {
            sum = sum + self.shared_witness[i];
        }
        sum + self.private_witness
    }
}

/// The statement type for the sum circuit, the expected sum of the witness values
pub(crate) type SumCircuitStatement = Scalar;

/// The sum circuit
struct SumCircuit;
impl SingleProverCircuit for SumCircuit {
    type Statement = SumCircuitStatement;
    type Witness = SumCircuitWitness;

    fn name() -> String {
        "sum-circuit".to_string()
    }

    fn apply_constraints(
        witness_var: <Self::Witness as CircuitBaseType>::VarType,
        statement_var: <Self::Statement as CircuitBaseType>::VarType,
        cs: &mut PlonkCircuit,
    ) -> Result<(), PlonkError> {
        let mut sum = cs.sum(&witness_var.shared_witness)?;
        sum = cs.add(sum, witness_var.private_witness)?;
        cs.enforce_equal(sum, statement_var)?;

        Ok(())
    }
}

// --- Circuit 2 --- //

/// The witness type for the product circuit, the witness values to be multiplied
#[derive(Clone, Debug, Default)]
#[circuit_type(singleprover_circuit)]
pub(crate) struct ProductCircuitWitness {
    /// The shared witness values
    #[link_groups = "sum-and-product-link-group"]
    pub shared_witness: [Scalar; LINKING_WITNESS_SIZE],
    /// A witness value specific to this circuit
    pub private_witness: Scalar,
}

impl ProductCircuitWitness {
    /// Derive the statement from the witness
    pub fn statement(&self) -> Scalar {
        let mut product = Scalar::one();
        for i in 0..LINKING_WITNESS_SIZE {
            product *= self.shared_witness[i];
        }
        product * self.private_witness
    }
}

/// The statement type for the product circuit, the expected product of the witness values
pub(crate) type ProductCircuitStatement = Scalar;

/// The product circuit
struct ProductCircuit;
impl SingleProverCircuit for ProductCircuit {
    type Statement = ProductCircuitStatement;
    type Witness = ProductCircuitWitness;

    fn name() -> String {
        "product-circuit".to_string()
    }

    fn apply_constraints(
        witness_var: <Self::Witness as CircuitBaseType>::VarType,
        statement_var: <Self::Statement as CircuitBaseType>::VarType,
        cs: &mut PlonkCircuit,
    ) -> Result<(), PlonkError> {
        let mut product = cs.one();
        for i in 0..LINKING_WITNESS_SIZE {
            product = cs.mul(product, witness_var.shared_witness[i])?;
        }
        product = cs.mul(product, witness_var.private_witness)?;
        cs.enforce_equal(product, statement_var)?;

        Ok(())
    }
}

// ------------------
// | Prover Methods |
// ------------------

/// Generate a verification key for the sum circuit
pub fn generate_sum_circuit_verification_key() -> VerificationKey {
    let vk = SumCircuit::verifying_key();
    VerificationKey::from(vk.as_ref().clone())
}

/// Generate a verification key for the product circuit
pub fn generate_product_circuit_verification_key() -> VerificationKey {
    let vk = ProductCircuit::verifying_key();
    VerificationKey::from(vk.as_ref().clone())
}

/// Generate a verification key for the sum-product linking relation
pub fn generate_sum_product_linking_verification_key() -> ProofLinkingVK {
    let layout = SumCircuit::get_circuit_layout().unwrap();
    let group_layout = layout.get_group_layout(LINKING_GROUP_NAME);
    ProofLinkingVK::from(group_layout)
}

/// Generate PlonK proofs for each circuit and a linking proof that they share a witness group
pub fn generate_proofs(
    sum_witness: SumCircuitWitness,
    product_witness: ProductCircuitWitness,
) -> (PlonkProof, PlonkProof, LinkingProof) {
    let sum = sum_witness.statement();
    let product = product_witness.statement();

    let (sum_proof, sum_link_hint) = SumCircuit::prove_with_link_hint(sum_witness, sum).unwrap();
    let (product_proof, product_link_hint) =
        ProductCircuit::prove_with_link_hint(product_witness, product).unwrap();

    let layout = SumCircuit::get_circuit_layout().unwrap();
    let group_layout = layout.get_group_layout(LINKING_GROUP_NAME);

    let pk = SumCircuit::proving_key();
    let link_proof = PlonkKzgSnark::link_proofs::<SolidityTranscript>(
        &sum_link_hint,
        &product_link_hint,
        &group_layout,
        &pk.commit_key,
    )
    .unwrap();

    let sum_proof_converted = PlonkProof::from(sum_proof);
    let product_proof_converted = PlonkProof::from(product_proof);
    let link_proof_converted = LinkingProof::from(link_proof);

    (
        sum_proof_converted,
        product_proof_converted,
        link_proof_converted,
    )
}
