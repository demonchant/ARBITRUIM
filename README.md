# FlowGuard Protocol

FlowGuard is programmable proof-of-delivery settlement for African SME trade. A buyer escrows a stablecoin payment, a supplier anchors an encrypted delivery-evidence hash, selected independent attestors verify it, and the settlement contract releases payment once the agreed threshold is met.

## Why this is not generic escrow

The protocol does not place photos, identities, invoices, or GPS traces onchain. It anchors one content hash for an encrypted evidence bundle, then lets a buyer choose a threshold of trusted attestors such as a courier, receiver, and cold-chain sensor oracle. The same contract supports buyer approval, time-delayed automatic settlement, buyer refunds for missed delivery, and a deal-specific dispute arbitrator.

## Security posture

The contract uses checks-effects-interactions, a reentrancy lock, exact state transitions, immutable token and guardian addresses, bounded attestor lists, deal-specific permissions, and safe handling for ERC-20 tokens that return no value. The guardian can pause new deals and evidence intake but cannot move or seize user funds. Release, refund, and dispute resolution remain available while paused.

## Deploy before submission

Deploy `FlowGuardSettlement` to Arbitrum Sepolia with the test settlement-token address and a separate guardian address. Use a real USDG token address only after independently verifying the official deployment with Paxos. Deploy `MockUSDG` only for the testnet demo, mint it to the demo buyer, approve FlowGuard, then run the cold-chain delivery scenario.

Create a local `.env` file with `ARBITRUM_SEPOLIA_RPC_URL`, `DEPLOYER_PRIVATE_KEY`, and optionally `GUARDIAN_ADDRESS`. Never commit it. Run `npm run deploy:sepolia`. The script uses `MockUSDG` only when `USDG_ADDRESS` is absent; this is intentional for a no-money testnet demo.

## Demo scenario

Kora Foods buys temperature-controlled produce. The buyer creates a 2,400 mUSDG deal requiring two of three attestations: courier GPS, receiver signature, and temperature oracle. Kora funds the deal. The supplier uploads encrypted proof to storage and submits its SHA-256 or keccak256 bundle hash. Two attestors sign the same hash. The buyer releases payment, or anyone can settle after the review window. A missed deadline lets the buyer recover funds without an admin.

## Before mainnet

Complete an independent security review, add invariant and fuzz testing, verify deployed source code, publish the formal evidence schema, obtain legal advice for custody and stablecoin compliance, and conduct a controlled pilot with real trade partners. Do not use unaudited contracts to hold production funds.
