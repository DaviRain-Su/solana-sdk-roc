import {
  Connection,
  PublicKey,
  Transaction,
  TransactionInstruction,
  Keypair,
  sendAndConfirmTransaction,
} from "@solana/web3.js";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");

async function main() {
  const rpcUrl = process.env.RPC_URL || "http://localhost:8899";
  const connection = new Connection(rpcUrl, "confirmed");

  const programIdFile = path.join(ROOT, ".program-id");
  if (!fs.existsSync(programIdFile)) {
    console.error("Error: .program-id not found. Run 'roc-solana deploy' first.");
    process.exit(1);
  }

  const programId = new PublicKey(fs.readFileSync(programIdFile, "utf-8").trim());
  console.log("Program ID:", programId.toBase58());

  const keyfile = path.join(process.env.HOME, ".config/solana/id.json");
  const payer = Keypair.fromSecretKey(
    Uint8Array.from(JSON.parse(fs.readFileSync(keyfile, "utf-8")))
  );
  console.log("Payer:", payer.publicKey.toBase58());

  const instruction = new TransactionInstruction({
    keys: [],
    programId,
    data: Buffer.from([]),
  });

  const tx = new Transaction().add(instruction);

  console.log("\nSending transaction...");
  const sig = await sendAndConfirmTransaction(connection, tx, [payer]);
  console.log("Signature:", sig);

  console.log("\nFetching transaction logs...");
  const txInfo = await connection.getTransaction(sig, {
    commitment: "confirmed",
    maxSupportedTransactionVersion: 0,
  });

  if (txInfo?.meta?.logMessages) {
    console.log("\n=== Program Logs ===");
    txInfo.meta.logMessages.forEach((log) => console.log(log));
  }
}

main().catch(console.error);
