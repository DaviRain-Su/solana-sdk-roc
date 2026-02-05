#!/usr/bin/env node

/**
 * Invoke Roc on Solana Hello World Program
 * 
 * This script creates and sends a transaction to invoke the deployed program,
 * then retrieves and displays the program logs.
 */

import {
    Connection,
    PublicKey,
    Keypair,
    Transaction,
    TransactionInstruction,
    sendAndConfirmTransaction,
} from '@solana/web3.js';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

const RPC_URL = 'http://localhost:8899';

async function main() {
    console.log('=== Roc on Solana Program Invocation ===\n');
    
    // Load program ID
    const programIdFile = path.join(process.cwd(), '.program-id');
    if (!fs.existsSync(programIdFile)) {
        console.error('Error: .program-id file not found. Run deploy.sh first.');
        process.exit(1);
    }
    
    const programIdStr = fs.readFileSync(programIdFile, 'utf8').trim();
    const programId = new PublicKey(programIdStr);
    console.log(`Program ID: ${programId.toBase58()}\n`);
    
    // Load wallet keypair
    const keypairPath = path.join(os.homedir(), '.config/solana/id.json');
    if (!fs.existsSync(keypairPath)) {
        console.error('Error: Wallet keypair not found at ~/.config/solana/id.json');
        process.exit(1);
    }
    
    const keypairData = JSON.parse(fs.readFileSync(keypairPath, 'utf8'));
    const payer = Keypair.fromSecretKey(Uint8Array.from(keypairData));
    console.log(`Payer: ${payer.publicKey.toBase58()}\n`);
    
    // Connect to cluster
    const connection = new Connection(RPC_URL, 'confirmed');
    
    // Check balance
    const balance = await connection.getBalance(payer.publicKey);
    console.log(`Balance: ${balance / 1e9} SOL\n`);
    
    // Create a dedicated counter account owned by the program.
    // Layout: first 8 bytes little-endian u64 counter.
    const counter = Keypair.generate();
    const counterSpace = 8;

    const rentExemptLamports = await connection.getMinimumBalanceForRentExemption(counterSpace);

    const createCounterIx = (await import('@solana/web3.js')).SystemProgram.createAccount({
        fromPubkey: payer.publicKey,
        newAccountPubkey: counter.publicKey,
        lamports: rentExemptLamports,
        space: counterSpace,
        programId,
    });

    // Instruction data:
    // [0] init, [1] inc, [2 + u64] add
    const initIx = new TransactionInstruction({
        keys: [{ pubkey: counter.publicKey, isSigner: false, isWritable: true }],
        programId,
        data: Buffer.from([0]),
    });

    const incIx = new TransactionInstruction({
        keys: [{ pubkey: counter.publicKey, isSigner: false, isWritable: true }],
        programId,
        data: Buffer.from([1]),
    });
    
    // Create and send transaction
    console.log('Sending transaction...\n');

    const transaction = new Transaction().add(createCounterIx, initIx, incIx, incIx);

    try {
        const signature = await sendAndConfirmTransaction(
            connection,
            transaction,
            [payer, counter],
            { commitment: 'confirmed' }
        );
        
        console.log(`Counter account: ${counter.publicKey.toBase58()}`);
        console.log(`Transaction signature: ${signature}\n`);
        
        // Fetch transaction logs
        console.log('=== Program Logs ===\n');
        
        const txInfo = await connection.getTransaction(signature, {
            commitment: 'confirmed',
            maxSupportedTransactionVersion: 0,
        });
        
        if (txInfo && txInfo.meta && txInfo.meta.logMessages) {
            txInfo.meta.logMessages.forEach(log => {
                console.log(log);
            });
        } else {
            console.log('No logs found in transaction.');
        }
        
        console.log('\n=== Invocation Complete ===');
        console.log('SUCCESS! The program executed correctly.');
        
    } catch (error) {
        console.error('Transaction failed:', error);
        process.exit(1);
    }
}

main().catch(console.error);
