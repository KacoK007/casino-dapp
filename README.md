# 🎰 Mini Casino DApp

A decentralized casino application where players can bet CST tokens (CasinoToken) in games like Slots, Blackjack.

---

## 🌐 Live Demo
Deployed frontend (GitHub Pages):
👉 [https://yourusername.github.io/mini-casino-dapp](https://yourusername.github.io/mini-casino-dapp)

---

## 🔗 Ethereum Testnet Used
**Testnet:** Sepolia

Contracts deployed on:
- **CasinoToken:** `0x...`
- **CasinoGame:** `0x...`

(Replace with actual addresses)

---

## 📦 Features
- Swap ETH ↔ CST
- Play Blackjack (with real deck logic), Slots

---

## 🧪 How to Deploy Smart Contracts via Remix
1. Go to [Remix IDE](https://remix.ethereum.org/)
2. Paste the contents of `CasinoToken.sol` and `CasinoGame.sol` into new files
3. Compile both contracts using the Solidity compiler
4. In the **Deploy & Run Transactions** panel:
   - Environment: **Injected Provider - MetaMask** (connect your wallet)
   - Contract: Select `CasinoToken`
   - Constructor parameter: Enter your wallet address for ownership
   - Deploy and copy the deployed address
5. Repeat for `CasinoGame` contract, passing the `CasinoToken` address as constructor argument
6. Fund the token contract with ETH
7. Transfer enough token to the `CasinoGame` contract
8. Interact via the Remix UI or your frontend


---

## 🛠️ Build & Deploy
Replace the the addresses in BlackJack.jsx and Slots.jsx.
```bash
npm install
npm run dev            # for local development
npm run deploy         # deploys to GitHub Pages
```

---

## 👛 Wallet Support
- MetaMask (via Ethers.js)

---

## 📄 License
MIT
