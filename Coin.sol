// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

contract CoinFlip {
    mapping(address => bool) private oldUser;
    mapping(address => uint256) private balances;

    struct Bet {
        address user; // address of the user
        uint128 amount; // bet amount
        uint8 side; // 0 = heads, 1 = tails
        uint8 completed; // 0 = not completed, 1 = completed
        uint8 doesWin; // 0 = Lose, 1 = Win
    }

    Bet[] public bets;
    uint256 public completedBetsCounter; // = (index of the last completed bet) + 1

    mapping(address => bool) public isBetting; // is the user betting on this round?

    event Win(address indexed user, uint128 amount);

    function balanceOf(address _user) public view returns (uint256) {
        // returns the balance of the user and 100 for new user
        if (oldUser[_user] == false) return 100;
        return balances[_user];
    }

    function bet(uint128 _amount, uint8 _side) public {
        require(_side == 0 || _side == 1, "Invalid bet");
        require(isBetting[msg.sender] == false, "Already betting");

        if (oldUser[msg.sender] == false) {
            // give new user 100 coins
            oldUser[msg.sender] = true;
            balances[msg.sender] = 100;
        }

        require(balances[msg.sender] >= _amount, "Not enough balance");
        balances[msg.sender] -= _amount;

        isBetting[msg.sender] = true;
        bets.push(Bet(msg.sender, _amount, _side, 0, 0));
    }

    function vrf() public view returns (bytes32 result) {
        uint256[1] memory bn;
        bn[0] = block.number;
        assembly {
            let memPtr := mload(0x40)
            if iszero(staticcall(not(0), 0xff, bn, 0x20, memPtr, 0x20)) {
                invalid()
            }
            result := mload(memPtr)
        }
    }

    function rewardBets() public {
        // todo : openzeppelin ownable contract can be used to make function only callable by owner
        require(completedBetsCounter < bets.length, "No ongoing bets");

        uint8 result = uint8(uint256(vrf()) % 2);

        for (uint256 i = completedBetsCounter; i < bets.length; i++) {
            Bet memory b = bets[i];
            if (b.side == result) {
                balances[b.user] += b.amount * 2;
                emit Win(b.user, b.amount);
                bets[i].doesWin = 1;
            }
            bets[i].completed = 1;
            isBetting[b.user] = false;
        }
        completedBetsCounter = bets.length;
    }
}
