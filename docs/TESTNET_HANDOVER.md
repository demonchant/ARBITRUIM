# FlowGuard — Public Testnet Beta Handover

## Purpose

This document hands over the steps for launching a public, judge-usable FlowGuard beta on **Arbitrum Sepolia**. It uses real onchain transactions and official Paxos **test USDG**, but every asset in this environment has zero monetary value.

> **Safety boundary:** this is a Buildathon testnet beta, not a production-money launch. Never send ETH, USDG, or any real asset to the testnet contract.

## What has been delivered

- Public FlowGuard web app with demo flow and `/testnet` onboarding page.
- MetaMask testnet connection and official test-USDG balance display.
- Solidity settlement protocol with funded deal, evidence-hash anchoring, threshold attestations, release, refund, dispute, and arbitration flows.
- Automated contract tests for threshold release, deadline refund, and arbitrator-only dispute resolution.
- Deployment script and public configuration template.

## Smart-contract inventory

### Testnet deployment: **one contract**

Deploy only `FlowGuardSettlement.sol` to Arbitrum Sepolia. It accepts the pre-existing official Paxos test USDG token as constructor input; USDG is **not** deployed or controlled by FlowGuard.

### Repository contracts: **two contracts**

| Contract | Deploy for public testnet beta? | Purpose |
| --- | --- | --- |
| `FlowGuardSettlement.sol` | **Yes** | The actual non-custodial settlement protocol. |
| `MockUSDG.sol` | No | Local-test fallback only. Do not deploy for the public Paxos USDG demo. |

There is no separate escrow contract, evidence contract, or token contract to deploy. Evidence originals remain encrypted offchain; the settlement contract records only the evidence-bundle hash and attestation state.

## Testnet roles and funding

All funding below must be **Arbitrum Sepolia test ETH**. Test ETH has no market value.

| Role | Address | Recommended test ETH | Signs |
| --- | --- | ---: | --- |
| Deployer | `0x0D98313115c3Aed77780bF99Bb36dC0EF4EC70e0` | 0.05 | Contract deployment |
| Buyer | `0xe38b59EA0427804CB3F5ac1F330637A43B6B4E20` | 0.03 | USDG approval, deal creation, release, refund, dispute |
| Supplier | `0x57d1b0F499Fc427ce12F6731eEC775f73B87a295` | 0.01 | Evidence submission |
| Courier attestor | `0x6331924fCBC5b3d086F761af130a5c74957507f6` | 0.01 | Evidence attestation |
| Receiver attestor | `0x1a415984C40d6C198eA4Dae2B430133c4949B56d` | 0.01 | Evidence attestation |
| Guardian | `0xdbb9ea567b5263360b6f40319d75b88b975eB13E` | 0.01 optional | Emergency-pause test only |
| Arbitrator | `0x1A88D37246c6D99dBEAbec2fe5Af30FA2aFc8f5D` | 0.01 optional | Dispute-resolution test only |

Only the **buyer** needs test USDG. Obtain it through the Paxos Testnet Faucet. The official Arbitrum Sepolia USDG address is `0xFFC95faa3d63Cde504a05B567C600B78C0b41892`.

## Network configuration

```text
Network: Arbitrum Sepolia
Chain ID: 421614
Currency: ETH
RPC URL: https://sepolia-rollup.arbitrum.io/rpc
Explorer: https://sepolia.arbiscan.io
```

## Deployment procedure

1. Create a local `.env` from `.env.example`.
2. Set `DEPLOYER_PRIVATE_KEY` only on the deployer’s own computer. Never commit or share it.
3. Keep `GUARDIAN_ADDRESS` set to the dedicated guardian account.
4. Keep `USDG_ADDRESS` set to official Paxos test USDG.
5. Run:

   ```powershell
   npm.cmd run contracts:test
   npm.cmd run deploy:sepolia
   ```

6. Save the printed `FlowGuardSettlement` address.
7. Add it to `.env.local` as `VITE_FLOWGUARD_CONTRACT_ADDRESS`.
8. Build and deploy the website to Vercel.
9. Verify the contract source on Arbiscan and add its explorer URL to the Buildathon submission.

## Cost estimate

### Buildathon testnet beta

| Item | Expected cost |
| --- | ---: |
| Deploy `FlowGuardSettlement` | $0 — paid with faucet test ETH |
| User transactions | $0 — paid with faucet test ETH |
| Paxos test USDG | $0 — test token only |
| Public RPC | $0 on free tier initially |
| Vercel hosting | $0 on free tier initially |
| GitHub repository | $0 |
| Optional custom domain | roughly $10–$25/year |
| **Expected minimum** | **$0** |
| **With a custom domain** | **about $10–$25/year** |

### Future mainnet production (not part of this Buildathon)

| Item | Budget guidance |
| --- | --- |
| Deploy one settlement contract | Variable Arbitrum One gas; estimate immediately before deployment using Arbitrum’s live estimator. |
| Contract audit | Often $10,000–$50,000+ depending on scope and auditor. |
| Legal/compliance | Obtain Nigerian fintech/virtual-asset counsel quotes before accepting real USDG. |
| Hosting, RPC, evidence storage, monitoring | Low at pilot scale, then usage-based. |

Mainnet deployment gas is not the meaningful launch cost. Independent security review, operations, and compliance are the main production costs.

## Judge demo sequence

1. Buyer connects MetaMask and creates a delivery deal using the supplier, courier, receiver, and arbitrator addresses above.
2. Buyer approves and funds the deal with Paxos test USDG.
3. Supplier submits a hash for an encrypted delivery-evidence bundle.
4. Courier and receiver each attest to that exact hash.
5. Buyer releases test USDG to the supplier.
6. Show the contract, deal events, and payment transaction on Arbiscan.

## Handover checklist

- [ ] Every active role has Arbitrum Sepolia test ETH.
- [ ] Buyer has Paxos test USDG.
- [ ] Contract deployed and address recorded.
- [ ] Contract verified on Arbiscan.
- [ ] Website deployed publicly.
- [ ] Website environment includes deployed contract address.
- [ ] Full demo completed with transaction links.
- [ ] Buildathon submission includes website, GitHub, contract, and demo video.
