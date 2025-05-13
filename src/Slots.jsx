import { useEffect, useState, useRef } from 'react';
import { ethers } from 'ethers';

const TOKEN_ADDRESS = "0x802af493e50472f39f7F4454cbe6da0824619523";
const CASINO_ADDRESS = "0xeD6f282Fe86e54Fb4Fa3DfB709aC7bB238A1295E";

const ABI = [
  "function playSlots(uint256 betAmount) external",
  "event GameResult(address indexed player, string game, uint256 betAmount, uint256 payout, string result)",
  "function balanceOf(address) view returns (uint256)",
  "function decimals() view returns (uint256)"
];

export default function Slots({ provider, onBalanceChange }) {
    const [contract, setContract] = useState(null);
    const [bet, setBet] = useState('');
    const [reels, setReels] = useState([['❓'], ['❓'], ['❓']]);
    const [status, setStatus] = useState('');
    const [isSpinning, setIsSpinning] = useState(false);
    const [finalResult, setFinalResult] = useState(null);
    const animationRef = useRef(null);
    const reelStates = useRef([
        { position: 0, speed: 0, target: null, stopping: false },
        { position: 0, speed: 0, target: null, stopping: false },
        { position: 0, speed: 0, target: null, stopping: false }
    ]);
    const stopOrder = useRef([]);

    const symbols = [
            '🍒', '🍋', '🔔', '💎', '7️⃣', '🍇', '⭐', 
            '🍉', '🍊', '🍀', '🏆', '💰', '👑', '💍',
            ];
    const visibleSymbols = 3; // Number of symbols visible in each reel
 
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
                        if (game !== "Slots" && player !== contract.address) return;
                        const aligned = result === "Jackpot" || result === "Small Win";
                        setFinalResult({ aligned, result, payout });
                    });
                }
            } catch (err) {
                setStatus('Error initializing contract: ' + err.message);
                stopSpinning();
            }
        };
        initContract();

        return () => {
            if (contract) {
                contract.removeAllListeners("GameResult");
            }
            stopSpinning();
        };
    }, [provider]);

    useEffect(() => {
        if (finalResult) {
            // Determine stop order (random which reel stops first)
            stopOrder.current = [0, 1, 2].sort(() => Math.random() - 0.5);
            
            // Set target positions for each reel
            stopOrder.current.forEach((reelIndex, i) => {
                setTimeout(() => {
                    // Mark this reel as stopping
                    reelStates.current[reelIndex].stopping = true;
                    
                    // For wins, align all reels to same symbol
                    if (finalResult.aligned) {
                        const targetSymbol = symbols[Math.floor(Math.random() * symbols.length)];
                        const targetPos = symbols.indexOf(targetSymbol);
                        reelStates.current.forEach(reel => {
                            reel.target = targetPos;
                        });
                    } else {
                        // For losses, position cannot be aligned
                        const targetPos = Math.floor(Math.random() * symbols.length);
                        reelStates.current[reelIndex].target = targetPos;
                        while(reelIndex === 3 && reelStates.current[reelIndex-1].target === targetPos) {
                            reelStates.current[reelIndex].target = Math.floor(Math.random() * symbols.length);
                        }
                    
                    }
                }, i * 800); // Stagger the stopping
            });

            // When all reels have stopped
            setTimeout(() => {
                setIsSpinning(false);
                setStatus(`Game Over - ${finalResult.result}! Payout: ${ethers.formatUnits(finalResult.payout, 18)} CST`);
                setFinalResult(null);
                fetchBalance();
            }, stopOrder.current.length * 900 + 1500);
        }
    }, [finalResult]);

    const startSpinning = () => {
        // Reset reel states
        reelStates.current = reelStates.current.map(() => ({
            position: 0,
            speed: 3 + Math.random() * 3,
            target: null,
            stopping: false
        }));

        const animate = () => {
            const newReels = [[], [], []];
            let allStopped = true;

            // Update each reel
            reelStates.current.forEach((reel, reelIndex) => {
                if (reel.stopping) {
                    // Reel is in process of stopping
                    if (reel.target !== null) {
                        // Slow down as we approach target
                        const distance = (reel.target - reel.position + symbols.length) % symbols.length;
                        reel.speed = Math.max(0.1, Math.min(reel.speed, distance * 0.2));
                        
                        // Snap to target when close enough
                        if (distance < 0.1 && reel.speed < 0.2) {
                            reel.position = reel.target;
                            reel.speed = 0;
                        }
                    } else {
                        // Just slowing down naturally
                        reel.speed = Math.max(0, reel.speed - 0.2);
                    }
                }

                // Update position
                reel.position = (reel.position + reel.speed * 0.03) % symbols.length;
                
                // Check if still moving
                if (reel.speed > 0) allStopped = false;

                // Get visible symbols for this reel (current and next ones)
                for (let i = 0; i < visibleSymbols; i++) {
                    const symbolIndex = Math.floor(reel.position + i) % symbols.length;
                    newReels[reelIndex].push(symbols[symbolIndex]);
                }
            });

            setReels(newReels);

            if (!allStopped) {
                animationRef.current = requestAnimationFrame(animate);
            } else {
                animationRef.current = null;
            }
        };

        // Cancel any existing animation
        if (animationRef.current) {
            cancelAnimationFrame(animationRef.current);
        }

        // Start new animation
        animationRef.current = requestAnimationFrame(animate);
    };

    const stopSpinning = () => {
        if (animationRef.current) {
            cancelAnimationFrame(animationRef.current);
            animationRef.current = null;
        }
        setIsSpinning(false);
    };

    const handleSpin = async () => {
        try {
            if (!bet || isNaN(bet) || parseFloat(bet) <= 0) {
                setStatus("Bet must be greater than zero.");
                return;
            }
            
            setIsSpinning(true);
            setStatus("Spinning...");
            startSpinning();

            const decimals = 18;
            const tx = await contract.playSlots(ethers.parseUnits(bet, decimals));
            await tx.wait();

        } catch (err) {
            stopSpinning();
            if (err.reason === "rejected") {
                setStatus("Transaction rejected.");
            } else if (err.reason === "Insufficient allowance") {
                setStatus("Insufficient allowance. Please approve the tokens first.");
            } else if (err.reason === "Bet must be greater than zero") {
                setStatus("Bet must be greater than zero.");
            }
        }
    };

    return (
        <div className="relative p-6 rounded-xl overflow-hidden" style={{
            background: 'linear-gradient(145deg, #1a1a2e, #16213e)',
            border: '8px solid #d4af37',
            boxShadow: '0 10px 25px rgba(0, 0, 0, 0.5), inset 0 0 15px rgba(210, 180, 140, 0.5)',
            maxWidth: '500px',
            margin: '2rem auto'
        }}>
            {/* Slot machine top */}
            <div className="absolute -top-4 left-1/2 transform -translate-x-1/2 w-16 h-8 bg-red-600 rounded-t-full"></div>
            
            {/* Slot machine screen */}
            <div className="relative z-10">
                <h2 className="text-3xl font-extrabold text-center mb-6 text-transparent bg-clip-text bg-gradient-to-r from-yellow-300 to-yellow-500" style={{
                    textShadow: '0 0 5px rgba(255, 215, 0, 0.8)'
                }}>
                    SLOT MACHINE
                </h2>

                {/* Reels container */}
                <div className="bg-black bg-opacity-70 p-4 rounded-lg mb-6 border-4 border-gray-700" style={{
                    boxShadow: 'inset 0 0 20px rgba(0, 0, 0, 0.8)'
                }}>
                    <div className="flex justify-center space-x-4 h-48 overflow-hidden">
                        {reels.map((reelSymbols, reelIndex) => (
                            <div key={reelIndex} className={`w-24 bg-gray-800 border-4 border-yellow-400 rounded-lg overflow-hidden relative`}>
                                <div className="flex flex-col items-center justify-center h-full">
                                    {reelSymbols.map((symbol, i) => (
                                        <div 
                                            key={i} 
                                            className={`w-full h-24 flex items-center justify-center text-7xl 
                                                ${i === 1 ? 'scale-110' : 'scale-90 opacity-70'}`}
                                        >
                                            {symbol}
                                        </div>
                                    ))}
                                </div>
                                {/* Reel mask */}
                                <div className="absolute inset-0 border-4 border-transparent" style={{
                                    boxShadow: 'inset 0 0 15px rgba(0,0,0,0.8)'
                                }}></div>
                            </div>
                        ))}
                    </div>
                </div>

                {/* Bet controls */}
                <div className="flex flex-col sm:flex-row sm:items-center gap-4 mb-6">
                    <input
                        type="text"
                        placeholder="Bet amount in CST"
                        value={bet}
                        onChange={(e) => setBet(e.target.value)}
                        className="flex-1 p-3 rounded-lg bg-gray-800 text-white border-2 border-yellow-500 focus:outline-none focus:ring-2 focus:ring-yellow-400"
                    />
                    <button
                        onClick={handleSpin}
                        disabled={isSpinning}
                        className={`px-8 py-3 rounded-full font-bold text-white transition-all ${isSpinning ? 'bg-gray-600 cursor-not-allowed' : 'bg-gradient-to-r from-red-600 to-red-800 hover:from-red-700 hover:to-red-900 transform hover:scale-105'} shadow-lg`}
                    >
                        {isSpinning ? 'SPINNING...' : 'SPIN'}
                    </button>
                </div>

                {/* Status message */}
                {status && (
                    <div className="p-3 bg-black bg-opacity-60 rounded-lg border border-yellow-500">
                        <p className={`text-center font-mono ${status.includes('Win') || status.includes('Jackpot') ? 'text-green-400 animate-pulse' : 'text-yellow-200'}`}>
                            {status}
                        </p>
                    </div>
                )}
            </div>

            {/* Slot machine base */}
            <div className="absolute -bottom-4 left-0 right-0 h-8 bg-gradient-to-r from-gray-700 via-gray-800 to-gray-700 rounded-b-lg"></div>
        </div>
    );
}