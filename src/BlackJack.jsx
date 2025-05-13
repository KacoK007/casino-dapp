import { useEffect, useState } from 'react';
import { ethers } from 'ethers';
const TOKEN_ADDRESS = "0x3D2635adF0Bf73C6F48d215b031e78b84E850b8d";
const CASINO_ADDRESS = "0x98f41F64F738bA25FC884227Dc4cFfd01669F723";
const ABI = [
  "function startBlackjack(uint256 betAmount) external",
  "function hit() external",
  "function stand() external",
  "function getPlayerCards() view returns (uint8[] memory)",
  "function getDealerCards() view returns (uint8[] memory)",
  "function decimals() view returns (uint8)",
  "event GameResult(address indexed player, string game, uint256 betAmount, uint256 payout, string result)",
  "function balanceOf(address) view returns (uint256)"
];

export default function Blackjack({ provider, onBalanceChange }) {
  const [contract, setContract] = useState(null);
  const [bet, setBet] = useState('');
  const [playerCards, setPlayerCards] = useState([]);
  const [dealerCards, setDealerCards] = useState([]);
  const [status, setStatus] = useState('');

  const fetchBalance = async () => {
    try {
      if (provider) {
        const signer = await provider.getSigner();
        const tokenContract = new ethers.Contract(TOKEN_ADDRESS, ABI, signer);
        const address = await signer.getAddress();
        const balanceWei = await tokenContract.balanceOf(address);
        const decimals = await tokenContract.decimals();
        const balanceFormatted = ethers.formatUnits(balanceWei, decimals);
        onBalanceChange(balanceFormatted);
      }
    } catch (err) {
      console.error('Error fetching balance:', err);
    }
  };

  useEffect(() => {
    const initContract = async () => {
      try {
        if (provider) {
          const signer = await provider.getSigner();
          const casinoContract = new ethers.Contract(CASINO_ADDRESS, ABI, signer);
          setContract(casinoContract);
          
          casinoContract.on("GameResult", async (player, game, betAmount, payout, result) => {
            if (game !== "Blackjack" && player !== contract.address) return;
            refreshHands();
            setStatus(`Game Over - ${result}! Payout: ${ethers.formatUnits(payout, 18)} CST`);
            await fetchBalance();
          });
        }
      } catch (err) {
          setStatus('Error initializing contract: ' + err.message);
      }
    };
    initContract();

    return () => {
      if (contract) {
        contract.removeAllListeners("GameResult");
      }
    };
  }, [provider]);
  

  const refreshHands = async () => {
    if (!contract) return;
    try {
      const p = await contract.getPlayerCards();
      const d = await contract.getDealerCards();
      setPlayerCards(p.map(n => Number(n)));
      setDealerCards(d.map(n => Number(n)));
    } catch (err) {
      console.error('Error refreshing hands:', err);
    }
  };

    const startGame = async () => {
        try {
            const decimals = 18;
            if (!bet || parseFloat(bet) <= 0) {
                setStatus("Please enter a valid bet amount.");
                return;
            }
            const tx = await contract.startBlackjack(ethers.parseUnits(bet, decimals));
            await tx.wait();
            setStatus("Game started - Good luck!");
            await fetchBalance();
            refreshHands();
        } catch (err) {
            if (err.reason === 'Finish your current game first') {
                setStatus('Finish your current game first');
            } else if (err.reason === "rejected") {
                setStatus("Transaction rejected.");
            } else if (err.reason === "Insufficient allowance") {
                setStatus("Insufficient allowance. Please approve the tokens first.");
            } else if (err.reason === "Bet must be greater than zero") {
                setStatus("Bet must be greater than zero.");
            } else {
                setStatus('Error starting game: ' + err.message);
            }
        }
    };

    const hit = async () => {
        try {
            setStatus("Hitting...");
            const tx = await contract.hit();
            await tx.wait();
            await refreshHands();
        } catch (err) {
            if (err.reason === "No active game") {
                setStatus('No active game');
            } else if (err.reason === "rejected") {
                setStatus("Transaction rejected.");
            } else if (err.reason === "Insufficient allowance") {
                setStatus("Insufficient allowance. Please approve the tokens first.");
            } else if (err.reason === "Bet must be greater than zero") {
                setStatus("Bet must be greater than zero.");
            } else {
                setStatus('Error hitting: ' + err.message);
            }
        }
    };

    const stand = async () => {
        try {
            setStatus("Standing... Waiting for dealer's turn");
            const tx = await contract.stand();
            await tx.wait();
            await refreshHands();
        } catch (err) {
            if (err.reason === "No active game") {
                    setStatus('No active game');
                } else if (err.reason === "rejected") {
                    setStatus("Transaction rejected.");
                } else if (err.reason === "Insufficient allowance") {
                    setStatus("Insufficient allowance. Please approve the tokens first.");
                } else if (err.reason === "Bet must be greater than zero") {
                    setStatus("Bet must be greater than zero.");
                } else {
                    setStatus('Error Standing: ' + err.message);
            }
        }
    };

  const cardValueToSymbol = (value) => {
    if (value === 1) return 'A';
    if (value >= 2 && value <= 10) return value;
    if (value === 11) return 'J';
    if (value === 12) return 'Q';
    if (value === 13) return 'K';
    return '?';
  };

  return (
    <div className="relative p-6 rounded-2xl overflow-hidden shadow-2xl" style={{
      background: 'linear-gradient(135deg, #0a5c36, #1a7e4c)',
      border: '8px solid #5a2d0c',
      boxShadow: '0 0 20px rgba(0, 0, 0, 0.5)',
      color: 'white',
      fontFamily: "'Trebuchet MS', sans-serif"
    }}>
      {/* Poker table felt texture */}
      <div className="absolute inset-0 opacity-20" style={{
        backgroundImage: 'radial-gradient(circle at center, transparent 0%, rgba(0,0,0,0.5) 100%)',
        pointerEvents: 'none'
      }}></div>
      
      {/* Casino chips decoration */}
      <div className="absolute top-2 right-2 w-12 h-12 rounded-full bg-red-600 border-4 border-yellow-400"></div>
      <div className="absolute bottom-2 left-2 w-10 h-10 rounded-full bg-blue-600 border-4 border-white"></div>
      <div className="absolute top-2 left-2 w-8 h-8 rounded-full bg-green-600 border-4 border-white"></div>
      
      <h2 className="text-2xl font-bold mb-4 text-center text-yellow-300 relative z-10" style={{ textShadow: '2px 2px 4px rgba(0,0,0,0.5)' }}>
        BLACKJACK 🃏
      </h2>

      <div className="mb-4 flex items-center justify-center relative z-10">
        <input
          type="text"
          placeholder="Bet amount in CST"
          value={bet}
          onChange={(e) => setBet(e.target.value)}
          className="p-3 rounded-lg bg-white bg-opacity-90 text-black font-bold text-center w-48 focus:outline-none focus:ring-2 focus:ring-yellow-400"
        />
        <button 
          onClick={startGame} 
          className="ml-3 px-6 py-3 bg-yellow-500 hover:bg-yellow-400 rounded-lg font-bold text-gray-900 transition-all duration-200 transform hover:scale-105 shadow-md"
          style={{ minWidth: '150px' }}
        >
          DEAL CARDS
        </button>
      </div>

      <div className="relative z-10">
        <div className="my-6 p-4 bg-black bg-opacity-30 rounded-xl">
          <p className="font-bold text-lg mb-2 text-yellow-300">DEALER'S HAND</p>
          <div className="flex space-x-2 mb-4">
            {dealerCards.map((card, i) => (
              <div key={i} className="w-12 h-16 bg-white rounded flex items-center justify-center text-2xl font-bold text-black shadow-md">
                {cardValueToSymbol(card)}
              </div>
            ))}
          </div>

          <p className="font-bold text-lg mb-2 text-yellow-300">YOUR HAND</p>
          <div className="flex space-x-2 mb-4">
            {playerCards.map((card, i) => (
              <div key={i} className="w-12 h-16 bg-white rounded flex items-center justify-center text-2xl font-bold text-black shadow-md">
                {cardValueToSymbol(card)}
              </div>
            ))}
          </div>
        </div>

        <div className="flex justify-center space-x-4 mt-4">
          <button 
            onClick={hit} 
            className="ml-3 px-6 py-3 bg-yellow-500 hover:bg-yellow-400 rounded-lg font-bold text-gray-900 transition-all duration-200 transform hover:scale-105 shadow-md"
            style={{ minWidth: '100px' }}
          >
            HIT
          </button>
          <button 
            onClick={stand} 
            className="ml-3 px-6 py-3 bg-yellow-500 hover:bg-yellow-400 rounded-lg font-bold text-gray-900 transition-all duration-200 transform hover:scale-105 shadow-md"
            style={{ minWidth: '100px' }}
          >
            STAND
          </button>
        </div>
      </div>

      {status && (
        <div className="mt-6 p-3 bg-black bg-opacity-50 rounded-lg text-center relative z-10">
          <p className="text-yellow-200 font-semibold">{status}</p>
        </div>
      )}
    </div>
  );
}