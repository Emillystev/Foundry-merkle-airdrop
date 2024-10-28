// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { IERC20, SafeERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { MerkleProof } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import { EIP712 } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol"; // for _hashTypedDataV4
    // (getMessageHash)
import { SignatureChecker } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol";
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol"; // for _isValidSignature
import { MessageHashUtils } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title Merkle Airdrop - Airdrop tokens to users who can prove they are in a merkle tree
 * @author Elene Urushadze
 */
contract MerkleAirdrop is EIP712 {
    // some list of addresses
    // allow someone in this list to claim ERX-20 tokens
    using ECDSA for bytes32;
    using SafeERC20 for IERC20; // Prevent sending tokens to recipients who can’t receive, for safeTransfer

    error MerkleAirdrop__InvalidProof();
    error MerkleAirdrop__AlreadyClaimed();
    error MerkleAirdrop__InvalidSignature();

    IERC20 private immutable i_airdropToken;
    bytes32 private immutable i_merkleRoot;
    mapping(address claimer => bool claimed) private s_hasClaimed;

    bytes32 private constant MESSAGE_TYPEHASH = keccak256("AirdropClaim(address account,uint256 amount)");

    // define the message hash struct
    struct AirdropClaim {
        address account;
        uint256 amount;
    }

    event Claimed(address account, uint256 amount);
    event MerkleRootUpdated(bytes32 newMerkleRoot);

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(bytes32 merkleRoot, IERC20 airdropToken) EIP712("Merkle Airdrop", "1.0.0") {
        i_merkleRoot = merkleRoot;
        i_airdropToken = airdropToken;
    }

    // claim the airdrop using a signature from the account owner
    function claim(
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        if (s_hasClaimed[account]) {
            revert MerkleAirdrop__AlreadyClaimed();
        }

        // Verify the signature
        if (!_isValidSignature(account, getMessageHash(account, amount), v, r, s)) {
            revert MerkleAirdrop__InvalidSignature();
        }

        // Verify the merkle proof
        // calculate the leaf node hash

        // when we are using merkle proofs and merkle tress, we want
        // to hash it twice. which avoids collisions. so if you have two
        // inputs that produce the same hash, then its a problem
        // so if we hash it twice, we will avoid that problem - known as second pre-image attact
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        // verify the merkle proof (TODO: understand verify)
        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            // merkleProof - calculates expected root, compares to actual root i_merkleRoot to see leaf was in fact in
            // the merkletree
            revert MerkleAirdrop__InvalidProof();
        }

        s_hasClaimed[account] = true; // prevent users claiming more than once and draining the contract
        emit Claimed(account, amount);
        // transfer the tokens
        i_airdropToken.safeTransfer(account, amount);
    }

    // message we expect to have been signed
    function getMessageHash(address account, uint256 amount) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({ account: account, amount: amount }))) // abi.encode -
                // to glue these pieces together
        );
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW AND PURE
    //////////////////////////////////////////////////////////////*/
    function getMerkleRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    function getAirdropToken() public view returns (IERC20) {
        return i_airdropToken;
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL
    //////////////////////////////////////////////////////////////*/

    // verify whether the recovered signer is the expected signer/the account to airdrop tokens for
    function _isValidSignature(
        address signer,
        bytes32 digest,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        internal
        pure
        returns (bool)
    {
        // could also use SignatureChecker.isValidSignatureNow(signer, digest, signature)
        (
            address actualSigner,
            /*ECDSA.RecoverError recoverError*/
            ,
            /*bytes32 signatureLength*/
        ) = ECDSA.tryRecover(digest, _v, _r, _s);
        return (actualSigner == signer);
    }

    // function _isValidSignature(
    //     address signer,
    //     bytes32 digest,
    //     uint8 _v,
    //     bytes32 _r,
    //     bytes32 _s
    // )
    // internal view returns (bool) {
    //     bytes memory signature = abi.encode(_v, _r, _s);
    //     return SignatureChecker.isValidSignatureNow(signer, digest, signature);
    // }
}
