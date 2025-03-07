
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./TimeUnit.sol";
import "./CommitReveal.sol";

contract RPS {
    uint public numPlayer = 0;
    uint public reward = 0;
    mapping (address => uint) public player_choice;  // 0 - Rock, 1 - Paper , 2 - Scissors  , 3 - Spock , 4 - Lizard
    mapping(address => bool) public player_not_played;
    address[] public players;
    uint public numInput = 0;
    uint256 public gameStartTime;
    uint256 public gameTimeout = 6 minutes; // ตั้งเวลาหมดอายุ 6 นาที

     // สร้างตัวแปรสำหรับใช้เรียกฟังก์ชันใน TimeUnit , CommitReveal
    TimeUnit public timeUnit;
    CommitReveal public commitReveal;

    // ตั้งที่อยู่ของสัญญา TimeUnit และ CommitReveal ใน constructor
     constructor(address _timeUnitAddress, address _commitRevealAddress) {
        // กำหนดที่อยู่ของ contract CommitReveal และ TimeUnit ที่ใช้งาน
        timeUnit = TimeUnit(_timeUnitAddress);
        commitReveal = CommitReveal(_commitRevealAddress);
    }
    

  

     address[4] private allowedPlayers = [
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
        0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
    ];
    //อนุญาตให้ผู้เล่นที่มี Adress ตรงกับที่อยู๋ใน allowedPlayers เท่านั้นที่สามารถเล่นเกม

    modifier  onlyAllowedPlayers() {
        bool isAllowed = false;
        for ( uint i = 0 ; i < allowedPlayers.length; i++) {
            if (msg.sender == allowedPlayers[i]) {
                isAllowed = true;
                break ;
            }
        }
        require(isAllowed, "Not an allowed player");
        _;
    }

    function addPlayer() public payable onlyAllowedPlayers{
        //ให้เพิ่มผู้เล่นเฉพาะคนที่อนุญาตเท่านั้น
        require(numPlayer < 2);
        if (numPlayer > 0) {
            require(msg.sender != players[0]);
        }
        require(msg.value == 1 ether);

        if (numPlayer == 0) {
            timeUnit.setStartTime(); // บันทึกเวลาเริ่มเกม
        }

        reward += msg.value;
        player_not_played[msg.sender] = true;
        players.push(msg.sender);
        numPlayer++;
    }

    function commitChoice(bytes32 dataHash) public {
    // ฟังก์ชัน commit ที่ผู้เล่นส่ง hash ของการเลือก
    require(numPlayer == 2, "Game not started yet");
    require(player_not_played[msg.sender], "You already committed");

    // ทำการ commit โดยเรียกฟังก์ชัน commit ของ CommitReveal
    commitReveal.commit(dataHash);

    // บันทึกการเลือกว่าได้ทำการ commit แล้ว
    player_not_played[msg.sender] = false;
}

  function revealChoice(bytes32 revealHash) public {
    // ฟังก์ชัน reveal ที่เปิดเผยการเลือก
    require(numPlayer == 2, "Game not started yet");
    
    // ทำการ reveal
    commitReveal.reveal(revealHash);

    // คำนวณ player index และ get choice โดยตรง
    uint playerChoice = getChoiceFromReveal(revealHash);

    // หา index ของผู้เล่น
    address player = msg.sender;
    uint playerIndex;
    
    if (players[0] == player) {
        playerIndex = 0;
    } else if (players[1] == player) {
        playerIndex = 1;
    } else {
        revert("Player not found");
    }

    // บันทึกการเลือกของผู้เล่น
    player_choice[players[playerIndex]] = playerChoice;
    numInput++;

    if (numInput == 2) {
        _checkWinnerAndPay();
    }
}


   function getChoiceFromReveal(bytes32 revealHash) private pure returns (uint) {
    // แปลง revealHash กลับไปเป็นตัวเลือก
    // คำนวณผลจาก hash ที่เปิดเผยให้เป็นการเลือก (0 - Rock, 1 - Paper, 2 - Scissors, 3 - Spock, 4 - Lizard)
    uint choice = uint(revealHash) % 5;
    return choice;
}

// ฟังก์ชัน getHash ที่คำนวณ Hash จากข้อมูลที่เราได้ไป random
function getHash(bytes32 data) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(data));
}

   function withdrawIfTimeout() public {
        // กรณีที่มีผู้เล่น 1 คน และเวลาผ่านไปครบ 6 นาที
        if (numPlayer == 1 && timeUnit.elapsedMinutes() >= 6) {
            address payable account0 = payable(players[0]);
            account0.transfer(reward);  // คืนเงินให้ผู้เล่นคนเดียว

            // รีเซ็ตค่าเกม
            reward = 0;
            numPlayer = 0;
            delete players;
            gameStartTime = 0;
        }

        // กรณีที่มีผู้เล่น 2 คน แต่ไม่มีการเลือกช้อยภายใน 6 นาที
        if (numPlayer == 2 && timeUnit.elapsedMinutes() >= 6) {
            address payable account0 = payable(players[0]);
            address payable account1 = payable(players[1]);
            account0.transfer(reward / 2);  // คืนเงินครึ่งหนึ่งให้ผู้เล่นคนแรก
            account1.transfer(reward / 2);  // คืนเงินครึ่งหนึ่งให้ผู้เล่นคนที่สอง

            // รีเซ็ตค่าเกม
            reward = 0;
            numPlayer = 0;
            delete players;
            gameStartTime = 0;
        }
    }


    function input(uint choice) public  onlyAllowedPlayers{
        require(numPlayer == 2);     //ถ้าคนเล่นไม่ถึงสองคนจะไม่ให้เรียกฟังก์ชันนี้ เรียกเฉพาะตอนเริ่มเล่น
        require(player_not_played[msg.sender]);     //คนที่จะมาเรียกฟังก์ชันนี้ msg.sender ต้องเป็น true และเป็น true ได้แค่ 2 address เท่านั้น
        require(choice >= 0 && choice <= 4, "The choice must be between 1 - 4");             //ช้อยที่เลือกต้องเป็นได้แค่ 0,1,2,3,4
        player_choice[msg.sender] = choice;
        player_not_played[msg.sender] = false;
        numInput++;
        if (numInput == 2) {
            _checkWinnerAndPay();
        }
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);
        
        if ((p0Choice + 1) % 5 == p1Choice || p1Choice == (p0Choice + 4) % 5 || p1Choice == (p0Choice + 3) % 5) {
            // to pay player[1]
            account1.transfer(reward);
        }
        else if ((p1Choice + 1) % 5 == p0Choice || p0Choice == (p1Choice + 4) % 5 || p0Choice == (p1Choice + 3) % 5) {
            // to pay player[0]
            account0.transfer(reward);    
        }
        else {
            // to split reward
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }
        delete player_choice[players[0]];
        delete player_choice[players[1]];
        delete player_not_played[players[0]];
        delete player_not_played[players[1]];

        player_not_played[account0] = false;
        player_not_played[account1] = false;
        numInput = 0; //รีเซ็ตค่า Input เมื่อจบเกมเพื่อทำให้เล่นเกมใหม่ได้
        reward = 0;
        numPlayer = 0;
        delete players;
        gameStartTime = 0;
    }
}
