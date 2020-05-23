pragma solidity 0.4.24;
pragma experimental ABIEncoderV2;

import "https://github.com/smartcontractkit/chainlink/evm-contracts/src/v0.4/ChainlinkClient.sol";
import "https://github.com/smartcontractkit/chainlink/evm-contracts/src/v0.4/vendor/Ownable.sol";

contract ATestnetConsumer2 is ChainlinkClient, Ownable {
  uint256 constant private ORACLE_PAYMENT = 1 * LINK;

  constructor() public Ownable() {
    setPublicChainlinkToken();
    jobIdBytes = stringToBytes32(jobId);
  }
  
  struct User {
        address publicAddress;
        string name;
    }
    
    struct Challenge {
        uint256 bid;
        User[] users;
    }
    
    mapping (string => Challenge) challenges;
    address public owner;
    
  mapping (bytes32 => string) challengeForRequestId;
  mapping (string => string) winner;
  
  address oracleAddress = 0xc99B3D447826532722E41bc36e644ba3479E4365;
  string jobId = "76ca51361e4e444f8a9b18ae350a5725";
  bytes32 jobIdBytes;
  uint256 payment = 10**18;
  
  string winnerUrlPrefix = "https://aqueous-depths-28970.herokuapp.com/?id=";
  
  function challengeFullUrl(string challengeId) public view returns (string url) {
    Challenge memory currentChallenge = challenges[challengeId];
    uint usersCount = currentChallenge.users.length;
    string memory names = "";
    for (uint i = 0; i < usersCount; i++) {
        names = string(abi.encodePacked(names, "&n=", currentChallenge.users[i].name));
    }
    
    string memory result = string(abi.encodePacked(winnerUrlPrefix, challengeId, names));
    return result;
  }
  
 function setChallengeForRequest(bytes32 _requestId, string challengeId) public {  // for testing only
     challengeForRequestId[_requestId] = challengeId;
 }
  
function requestWinner(string challengeId)
    public
  {
    require(moneySent[challengeId] == false);
    Chainlink.Request memory req = buildChainlinkRequest(jobIdBytes, this, this.fulfillWinner.selector);
    // req.add("get", "https://aqueous-depths-28970.herokuapp.com/winner-of/1269fde8-1e13-463b-b93d-6bcf69a83ac2_1589570307693");
    string memory fullUrl = challengeFullUrl(challengeId);
    req.add("get", fullUrl);

    bytes32 requestId = sendChainlinkRequestTo(oracleAddress, req, ORACLE_PAYMENT);
    challengeForRequestId[requestId] = challengeId;
  }
  
  function getChallengeWinner(string challengeId) public view returns (string) {
      return winner[challengeId];
  }
  
  bytes32 returnName;
  
//       function fulfillWinner(bytes32 _requestId, bytes32 _winnerNameBytes)
//     public
//     recordChainlinkFulfillment(_requestId)
//   {
//     returnName = _winnerNameBytes;
    
//     string memory _winnerName = bytes32ToString(_winnerNameBytes);
//      bytes32 _winnerNameHash = keccak256(bytes(_winnerName));
     
//     string memory challengeId = challengeForRequestId[_requestId];
//     // require(bytes(challengeId).length > 0);
    
//     Challenge memory currentChallenge = challenges[challengeId];
//     uint256 winnerAmount = currentChallenge.bid * currentChallenge.users.length;
//     bool moneyHasSent = false;
//     for (uint i = 0; i < currentChallenge.users.length; i++) {
//         string memory userName = currentChallenge.users[i].name;
//         bytes32 userNameHash = keccak256(bytes(userName));
//         if (userNameHash == _winnerNameHash) {
//             // address payable winnerAddress = payable(currentChallenge.users[i].publicAddress);
//             address winnerAddress = currentChallenge.users[i].publicAddress;
//             winnerAddress.transfer(winnerAmount);
//             moneySent[challengeId] = true;
//             moneyHasSent = true;
//             break;
//         }
//     }
//     require(moneyHasSent);
//   }
  
    function fulfillWinner(bytes32 _requestId, bytes32 _winnerNameBytes)
    public
    recordChainlinkFulfillment(_requestId)
  {
    returnName = _winnerNameBytes;
    
    string memory _winnerName = bytes32ToString(_winnerNameBytes);
     bytes32 _winnerNameHash = keccak256(bytes(_winnerName));
     
    string memory challengeId = challengeForRequestId[_requestId];
    require(bytes(challengeId).length > 0);
    winner[challengeId] = _winnerName;

    Challenge memory currentChallenge = challenges[challengeId];
    uint256 winnerAmount = currentChallenge.bid * currentChallenge.users.length;
    uint winnerNameLength = bytes(_winnerName).length;
    bool moneyHasSent = false;
    for (uint i = 0; i < currentChallenge.users.length; i++) {
        address winnerAddress = currentChallenge.users[i].publicAddress;
        if (winnerNameLength > 0) {
            string memory userName = currentChallenge.users[i].name;
            bytes32 userNameHash = keccak256(bytes(userName));
    
            if (userNameHash == _winnerNameHash) {
                // address payable winnerAddress = payable(currentChallenge.users[i].publicAddress);
                winnerAddress.transfer(winnerAmount);
                moneyHasSent = true;
                break;
            }
        } else {
            winnerAddress.transfer(currentChallenge.bid); 
            moneyHasSent = true;
        }
    }
    require(moneyHasSent == true);
    moneySent[challengeId] = true;
  }
  
  function bytes32ToString(bytes32 x) public pure returns (string) {
    bytes memory bytesString = new bytes(32);
    uint charCount = 0;
    for (uint j = 0; j < 32; j++) {
        byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
        if (char != 0) {
            bytesString[charCount] = char;
            charCount++;
        }
    }
    bytes memory bytesStringTrimmed = new bytes(charCount);
    for (j = 0; j < charCount; j++) {
        bytesStringTrimmed[j] = bytesString[j];
    }
    return string(bytesStringTrimmed);
}
  
  function getName() public view returns (string name) {
      return  bytes32ToString(returnName);
  }
  
  function getNameBytes() public view returns (bytes32 name) {
      return returnName;
  }

  function getChainlinkToken() public view returns (address) {
    return chainlinkTokenAddress();
  }
  
    mapping (string => bool) moneySent;
    
    function createNewChallange(string memory challengeId, string memory creatorName) public payable returns (bool success) {
        require(challenges[challengeId].users.length == 0);
        require(msg.value > 0);

        User memory newUser = User(msg.sender, creatorName);
        challenges[challengeId].users.push(newUser);
        challenges[challengeId].bid = msg.value;
        return true;
    }
  
      function getChallengeInfo(string memory challengeId) public view returns (Challenge returnChallenge) {
        return challenges[challengeId];
    }
    
    function getChallengeBid(string memory challengeId) public view returns (uint256 bid) {
        return challenges[challengeId].bid;
    }
    
    function getChallengeNames(string memory challengeId) public view returns (string[] names) {
        Challenge memory currentChallenge = challenges[challengeId];
        uint usersCount = currentChallenge.users.length;
        string[] memory result = new string[](usersCount);
        for (uint i = 0; i < currentChallenge.users.length; i++) {
            result[i] = currentChallenge.users[i].name;
        }
        return result;
    }

    function connectToChallenge(string memory challengeId, string memory playerName) public payable returns (bool success) {
        Challenge memory currentChallenge = challenges[challengeId];
        require(currentChallenge.users.length > 0);
        require(currentChallenge.bid == msg.value);
        bytes32 playerNameHash = keccak256(bytes(playerName));
        for (uint i = 0; i < currentChallenge.users.length; i++) {
            string memory userName = currentChallenge.users[i].name;
            bytes32 userNameHash = keccak256(bytes(userName));
            require(userNameHash != playerNameHash);
        }

        User memory newUser = User(msg.sender, playerName);
        challenges[challengeId].users.push(newUser);
        return true;
    }
  
      function sendFunds(string memory challengeId) public {
        requestWinner(challengeId);
    }

    
    function didSentFunds(string memory challengeId) public view returns (bool success) {
        return moneySent[challengeId];
    }

  
  
  
  

  function withdrawLink() public onlyOwner {
    LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
    require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
  }

  function cancelRequest(
    bytes32 _requestId,
    uint256 _payment,
    bytes4 _callbackFunctionId,
    uint256 _expiration
  )
    public
    onlyOwner
  {
    cancelChainlinkRequest(_requestId, _payment, _callbackFunctionId, _expiration);
  }

  function stringToBytes32(string memory source) public pure returns (bytes32 result) {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0) {
      return 0x0;
    }

    assembly { // solhint-disable-line no-inline-assembly
      result := mload(add(source, 32))
    }
  }

}
