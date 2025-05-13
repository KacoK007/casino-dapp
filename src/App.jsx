import { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import TokenSwap from './TokenSwap';
import Blackjack from './BlackJack';
import Slots from './Slots';

export default function App() {
  const [provider, setProvider] = useState(null);
  const [account, setAccount] = useState(null);
  const [balance, setBalance] = useState('0');

  useEffect(() => {
    if (window.ethereum) {
      const ethProvider = new ethers.BrowserProvider(window.ethereum);
      setProvider(ethProvider);

      window.ethereum.request({ method: 'eth_requestAccounts' }).then(accounts => {
        setAccount(accounts[0]);
      });

      window.ethereum.on('accountsChanged', (accounts) => {
        setAccount(accounts[0]);
      });
    } else {
      alert('Please install MetaMask to use this app.');
    }
  }, []);

  const handleBalanceChange = (newBalance) => {
    setBalance(newBalance);
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-gray-900 to-black text-white p-4 relative overflow-hidden">
      {/* Casino lights decoration */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-transparent via-yellow-500 to-transparent animate-pulse"></div>
        <div className="absolute top-10 left-0 right-0 h-1 bg-gradient-to-r from-transparent via-red-500 to-transparent animate-pulse" style={{ animationDelay: '0.5s' }}></div>
        <div className="absolute top-20 left-0 right-0 h-1 bg-gradient-to-r from-transparent via-blue-500 to-transparent animate-pulse" style={{ animationDelay: '1s' }}></div>
      </div>

      {/* Main content */}
      <div className="relative z-10 max-w-7xl mx-auto">
        {/* Header */}
        <header className="text-center mb-8">
          <h1 className="text-4xl md:text-5xl font-bold mb-2 text-transparent bg-clip-text bg-gradient-to-r from-yellow-400 via-red-500 to-purple-500">
            🎰 Crypto Casino Royale 🎰
          </h1>
          {account && (
            <div className="flex flex-col md:flex-row items-center justify-center gap-4 mb-4">
              <div className="bg-black bg-opacity-50 rounded-full px-4 py-2 border border-yellow-500">
                <span className="text-yellow-300">Wallet:</span> 
                <span className="ml-2 font-mono">{`${account.substring(0, 6)}...${account.substring(38)}`}</span>
              </div>
              <div className="bg-black bg-opacity-50 rounded-full px-4 py-2 border border-green-500">
                <span className="text-green-300">Balance:</span> 
                <span className="ml-2 font-bold">{balance} CTKN</span>
              </div>
            </div>
          )}
        </header>

        {/* Main game area */}
        <main className="flex flex-col items-center justify-center min-h-[80vh] w-full px-4">
          {account ? (
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Left Column - TokenSwap */}
              <div className="lg:order-1">
                <TokenSwap provider={provider} balance={balance} setBalance={setBalance} />
              </div>
              
              {/* Right Column - Blackjack and Slots */}
              <div className="lg:order-2 space-y-6">
                <Blackjack provider={provider} onBalanceChange={handleBalanceChange} />
                <Slots provider={provider} onBalanceChange={handleBalanceChange} />
              </div>
            </div>
          ) : (
            <div className="text-center py-20">
              <div className="inline-block p-6 bg-black bg-opacity-70 rounded-xl border border-yellow-500 animate-pulse">
                <p className="text-xl">Connecting to wallet...</p>
                <p className="text-sm text-gray-400 mt-2">Please approve the connection in MetaMask</p>
              </div>
            </div>
          )}
        </main>

        {/* Footer */}
        <footer className="mt-8 text-center text-gray-400 text-sm">
          <p>Play responsibly. All games are powered by smart contracts.</p>
        </footer>
      </div>
    </div>
  );
}