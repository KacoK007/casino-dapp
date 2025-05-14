import { useState, useEffect } from 'react';
import { ethers, parseUnits } from 'ethers';

const TOKEN_ADDRESS = "0x3D2635adF0Bf73C6F48d215b031e78b84E850b8d";
const CASINO_ADDRESS = "0x98f41F64F738bA25FC884227Dc4cFfd01669F723";
const ABI = [ // Simplified ABI
    "function buy() payable",
    "function sell(uint256 tokenAmount)",
    "function balanceOf(address) view returns (uint256)",
    "function decimals() view returns (uint8)",
    "function approve(address spender, uint256 amount) returns (bool)",
];

export default function TokenSwap({ provider, balance, setBalance }) {
  const [ethAmount, setEthAmount] = useState('');
  const [tokenAmount, setTokenAmount] = useState('');
  const [status, setStatus] = useState('');
  const [signer, setSigner] = useState(null);
  const [tokenContract, setTokenContract] = useState(null);

  // Calculate CTKN from ETH (1 ETH = 10,000,000 CTKN)
  const calculateTokenAmount = (ethValue) => {
    if (!ethValue) return "";
    const tokens = parseFloat(ethValue) * 10000000;
    return tokens.toLocaleString('en-US', { maximumFractionDigits: 0 });
  };

  // Calculate ETH from CTKN (10,000,000 CTKN = 1 ETH)
  const calculateEthAmount = (tokenValue) => {
    if (!tokenValue) return "";
    const eth = parseFloat(tokenValue) / 10000000;
    return eth.toFixed(8);
  };

  const fetchBalance = async () => {
    try {
      if (tokenContract && signer) {
        const address = await signer.getAddress();
        const balanceWei = await tokenContract.balanceOf(address);
        const decimals = await tokenContract.decimals();
        const balanceFormatted = ethers.formatUnits(balanceWei, decimals);
        setBalance(balanceFormatted);
      }
    } catch (err) {
      setStatus(`Error fetching balance: ${err.message}`);
    }
  };

  useEffect(() => {
    const initContract = async () => {
      try {
        if (provider) {
          const newSigner = await provider.getSigner();
          setSigner(newSigner);
          const contract = new ethers.Contract(TOKEN_ADDRESS, ABI, newSigner);
          setTokenContract(contract);
          const address = await newSigner.getAddress();
          const balanceWei = await contract.balanceOf(address);
          const decimals = await contract.decimals();
          const balanceFormatted = ethers.formatUnits(balanceWei, decimals);
          setBalance(balanceFormatted);
        }
      } catch (err) {
        setStatus('Error initializing contract: ' + err.message);
      }
    };
    initContract();
  }, [provider]);

  const approveTokens = async (amount) => {
    try {
      const decimals = 18;
      if (!amount || parseUnits(amount, decimals) <= 0) {
          setStatus("Please enter a valid token amount.");
          return;
      }
      const amountInTokens = ethers.parseUnits(amount, decimals);
      const tx = await tokenContract.approve(CASINO_ADDRESS, amountInTokens);
      await tx.wait();
      setStatus(`Approved ${amount} CTKN for spending by the casino contract.`);
    } catch (err) {
      setStatus(`Error: ${err.message}`);
    }
  };

  const buyTokens = async () => {
    try {
      if (!ethAmount || parseFloat(ethAmount) <= 0) {
                setStatus("Please enter a valid ETH amount.");
                return;
            }
      const tx = await tokenContract.buy({ value: ethers.parseEther(ethAmount) });
      await tx.wait();
      setStatus(`Swapped ${ethAmount} ETH for CTKN`);
      await fetchBalance();
    } catch (err) {
      setStatus(`Error: ${err.message}`);
    }
  };

  const sellTokens = async () => {
    try {
      const decimals = await tokenContract.decimals();
      if (!tokenAmount || parseUnits(tokenAmount, decimals) <= 0) {
                setStatus("Please enter a valid token amount.");
                return;
            }
      const amount = ethers.parseUnits(tokenAmount, decimals);
      const approveTx = await tokenContract.approve(TOKEN_ADDRESS, amount);
      await approveTx.wait();
      const tx = await tokenContract.sell(amount);
      await tx.wait();
      setStatus(`Swapped ${tokenAmount} CTKN for ETH`);
      await fetchBalance();
    } catch (err) {
      setStatus(`Error: ${err.message}`);
    }
  };

  return (
    <div className="relative p-6 rounded-xl overflow-hidden shadow-2xl" style={{
      background: 'linear-gradient(135deg, #2c3e50, #4a6491)',
      border: '6px solid #d4af37',
      color: 'white',
      fontFamily: "'Trebuchet MS', sans-serif"
    }}>
      {/* Casino cashier decoration */}
      <div className="absolute inset-0 opacity-10" style={{
        backgroundImage: 'url("data:image/svg+xml,%3Csvg width=\'100\' height=\'100\' viewBox=\'0 0 100 100\' xmlns=\'http://www.w3.org/2000/svg\'%3E%3Cpath d=\'M11 18c3.866 0 7-3.134 7-7s-3.134-7-7-7-7 3.134-7 7 3.134 7 7 7zm48 25c3.866 0 7-3.134 7-7s-3.134-7-7-7-7 3.134-7 7 3.134 7 7 7zm-43-7c1.657 0 3-1.343 3-3s-1.343-3-3-3-3 1.343-3 3 1.343 3 3 3zm63 31c1.657 0 3-1.343 3-3s-1.343-3-3-3-3 1.343-3 3 1.343 3 3 3zM34 90c1.657 0 3-1.343 3-3s-1.343-3-3-3-3 1.343-3 3 1.343 3 3 3zm56-76c1.657 0 3-1.343 3-3s-1.343-3-3-3-3 1.343-3 3 1.343 3 3 3zM12 86c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm28-65c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm23-11c2.76 0 5-2.24 5-5s-2.24-5-5-5-5 2.24-5 5 2.24 5 5 5zm-6 60c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm29 22c2.76 0 5-2.24 5-5s-2.24-5-5-5-5 2.24-5 5 2.24 5 5 5zM32 63c2.76 0 5-2.24 5-5s-2.24-5-5-5-5 2.24-5 5 2.24 5 5 5zm57-13c2.76 0 5-2.24 5-5s-2.24-5-5-5-5 2.24-5 5 2.24 5 5 5zm-9-21c1.105 0 2-.895 2-2s-.895-2-2-2-2 .895-2 2 .895 2 2 2zM60 91c1.105 0 2-.895 2-2s-.895-2-2-2-2 .895-2 2 .895 2 2 2zM35 41c1.105 0 2-.895 2-2s-.895-2-2-2-2 .895-2 2 .895 2 2 2zM12 60c1.105 0 2-.895 2-2s-.895-2-2-2-2 .895-2 2 .895 2 2 2z\' fill=\'%23d4af37\' fill-opacity=\'0.2\' fill-rule=\'evenodd\'/%3E%3C/svg%3E")',
        pointerEvents: 'none'
      }}></div>
      
      {/* Gold border accents */}
      <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-transparent via-yellow-400 to-transparent"></div>
      <div className="absolute bottom-0 left-0 right-0 h-1 bg-gradient-to-r from-transparent via-yellow-400 to-transparent"></div>
      
      <h2 className="text-2xl font-bold mb-4 text-center text-yellow-300 relative z-10" style={{ textShadow: '2px 2px 4px rgba(0,0,0,0.5)' }}>
        CASINO CASHIER
      </h2>

      <div className="mb-6 p-4 bg-black bg-opacity-40 rounded-lg relative z-10">
        <p className="text-lg font-bold text-center text-yellow-200 mb-2">YOUR CTKN BALANCE</p>
        <p className="text-2xl font-bold text-center text-white">{balance} CTKN</p>
      </div>

      {/* Exchange Rate Display */}
      <div className="mb-4 p-3 bg-black bg-opacity-30 rounded-lg text-center relative z-10">
        <p className="text-sm font-semibold text-yellow-200">EXCHANGE RATE</p>
        <p className="text-lg font-bold text-white">1 ETH = 10,000,000 CTKN</p>
        <p className="text-xs text-gray-300 mt-1">Fixed rate</p>
      </div>

      <div className="space-y-4 relative z-10">
        {/* Buy Tokens Section */}
        <div className="p-4 bg-black bg-opacity-30 rounded-lg">
          <h3 className="font-bold text-yellow-200 mb-2">BUY TOKENS</h3>
          <div className="flex items-center">
            <input
              type="text"
              value={ethAmount}
              onChange={(e) => {
                setEthAmount(e.target.value);
                setTokenAmount(calculateTokenAmount(e.target.value));
              }}
              placeholder="ETH amount"
              className="flex-1 p-3 rounded-lg bg-white bg-opacity-90 text-black font-bold focus:outline-none focus:ring-2 focus:ring-yellow-400"
            />
            <button 
              onClick={buyTokens} 
              className="ml-3 px-6 py-3 bg-yellow-500 hover:bg-yellow-400 rounded-lg font-bold text-gray-900 transition-all duration-200 transform hover:scale-105 shadow-md"
            >
              BUY CTKN
            </button>
          </div>
          {ethAmount && (
            <p className="text-sm text-yellow-200 mt-2">
              You will receive: <span className="font-bold">{calculateTokenAmount(ethAmount)} CTKN</span>
            </p>
          )}
        </div>

        {/* Sell Tokens Section */}
        <div className="p-4 bg-black bg-opacity-30 rounded-lg">
          <h3 className="font-bold text-yellow-200 mb-2">SELL TOKENS</h3>
          <div className="flex items-center">
            <input
              type="text"
              value={tokenAmount}
              onChange={(e) => {
                setTokenAmount(e.target.value);
                setEthAmount(calculateEthAmount(e.target.value));
              }}
              placeholder="CTKN amount"
              className="flex-1 p-3 rounded-lg bg-white bg-opacity-90 text-black font-bold focus:outline-none focus:ring-2 focus:ring-yellow-400"
            />
            <button 
              onClick={sellTokens} 
              className="ml-3 px-6 py-3 bg-yellow-500 hover:bg-yellow-400 rounded-lg font-bold text-gray-900 transition-all duration-200 transform hover:scale-105 shadow-md"
            >
              SELL CTKN
            </button>
          </div>
          {tokenAmount && (
            <p className="text-sm text-yellow-200 mt-2">
              You will receive: <span className="font-bold">{calculateEthAmount(tokenAmount)} ETH</span>
            </p>
          )}
        </div>

        {/* Approve Tokens Section */}
        <div className="p-4 bg-black bg-opacity-30 rounded-lg">
          <h3 className="font-bold text-yellow-200 mb-2">APPROVE TOKENS</h3>
          <div className="flex items-center">
            <input
              type="text"
              placeholder="CTKN amount"
              className="flex-1 p-3 rounded-lg bg-white bg-opacity-90 text-black font-bold focus:outline-none focus:ring-2 focus:ring-yellow-400"
            />
            <button 
              onClick={() => approveTokens(tokenAmount)} 
              className="ml-3 px-6 py-3 bg-yellow-500 hover:bg-yellow-400 rounded-lg font-bold text-gray-900 transition-all duration-200 transform hover:scale-105 shadow-md"
            >
              APPROVE
            </button>
          </div>
        </div>
      </div>

      {status && (
        <div className="mt-4 p-3 bg-black bg-opacity-50 rounded-lg text-center relative z-10">
          <p className="text-yellow-200 font-semibold">{status}</p>
        </div>
      )}
    </div>
  );
}