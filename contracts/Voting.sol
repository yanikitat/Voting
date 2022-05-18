//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {
    uint constant public VOTING_FEE = 0.01 ether;
    uint32 constant public VOTE_DURATION = 3 days;
    uint8 constant public FEE = 10; // 10%

    // amount of vee that owner can withdraw
    uint availableEtherForWithdraw;

    struct Candidate {
        address addr;
        uint32 voteOf;
    }

    struct Vote {
        Candidate[] candidates;
        string name;
        string description;
        uint pool;
        uint64 endTime;
        bool isEnded;
        mapping(address => bool) alreadyVoted;
    }

    Vote[] public votes;

    /*
        MODIFIERS
    */
    modifier voteIsExist(uint voteID) {
        require(voteID < votes.length, "Voting: vote with such ID doesn't exists");
        _;
    }


    /*
        EVENTS
    */

    /**
     * @dev Emitted when new vote is created by {createVote} function.
     */
    event VoteIsCreated(uint indexed voteID, string voteName, uint64 endTime);


    /*
        FUNCTIONS
    */

    /**
     * @dev Creates a new vote with `voteName` as name, `voteDeiscription` as
     * description and `candidateAddres` as list of candidates. end time of
     * vote is equal to current timestamp plus three days. 
     *
     * Requirements:
     * - `voteName` and `voteDescription` can't be an empty
     * - `candidateAddres` size must beat least 2. 
     *
     * IMPORTANT: the function doesn't check uniqueness of the voteName. It allows
     * to create two votes with the same voteName. Keep this in mind. 
     *
     * Emit an {VoteIsCreated} event.
     */
    function createVote(
        string calldata voteName,
        string calldata voteDescription,
        address[] calldata candidateAddrs
        )
        external
        onlyOwner
    {
        require(candidateAddrs.length >= 2,
                "Voting: amount of candidates must be at least 2");
        require(bytes(voteName).length > 0,
                "Voting: voteName can't be an empty");
        require(bytes(voteDescription).length > 0,
                "Voting: voteDescription can't be an empty");

        Vote storage vote = votes.push();

        vote.name = voteName;
        vote.description = voteDescription;
        vote.endTime = uint64(block.timestamp + VOTE_DURATION);

        for (uint i = 0; i < candidateAddrs.length; i++) {
            vote.candidates.push(Candidate(
                candidateAddrs[i], 0
            ));
        }

        emit VoteIsCreated(votes.length - 1, voteName, vote.endTime);
    }

    /**
     * @dev Returns information about the vote by voteID.
     * The function returns:
     *  - list of candidates (please chech the Candidate struct)
     *  - name of vote
     *  - description of vote
     *  - current pool of vote
     *  - current end time of vote
     *  - status of vote (is ended or not)
     *
     * Requirements:
     * - vote with `voteID` should be exists.
     *
     */
    function getVote(uint voteID)
        external
        view
        voteIsExist(voteID)
        returns(
            Candidate[] memory candidates,
            string memory name,
            string memory description,
            uint pool,
            uint64 endTime,
            bool isEnded)
    {    
        Vote storage vote = votes[voteID];

        return (vote.candidates, vote.name, vote.description,
                vote.pool, vote.endTime, vote.isEnded);
    }

    function getCandidateID(uint voteID, address candadiateAddr)
        public
        view
        voteIsExist(voteID)
        returns(uint)
    {
        Vote storage vote = votes[voteID];

        for (uint i = 0; i < vote.candidates.length; i++) {
            if (candadiateAddr == vote.candidates[i].addr) {
                return i;
            }
        }
        revert("Voting: candidate with such address doesn't exists");
    }

    /**
     * @dev Returns information about the vote by voteID.
     *
     * Requirements:
     * - vote with `voteID` should be exists.
     *
     */
    function doVoteByID(uint voteID, uint candidateID)
        public
        payable
        voteIsExist(voteID)
    {
        require(msg.value >= VOTING_FEE, "Voting: voting fee isn't enough");

        Vote storage vote = votes[voteID];

        require(vote.endTime >= uint64(block.timestamp), "Voting: voting time is over");
        require(vote.alreadyVoted[msg.sender] != true, "Voting: you already has voted");
        require(candidateID < vote.candidates.length,
                "Voting: candidate with such ID doesn't exists");

        vote.alreadyVoted[msg.sender] = true;
        vote.pool += msg.value;
        vote.candidates[candidateID].voteOf++;

        // Current winner is always on the first place in the array of candidates.
        // So we can to avoid loop when we will choose winner of vote.
        if (vote.candidates[candidateID].voteOf > vote.candidates[0].voteOf) {
            Candidate storage newCurrentWinner = vote.candidates[candidateID];
            vote.candidates[candidateID] = vote.candidates[0]; 
            vote.candidates[0] = newCurrentWinner; 
        }
    }

    function doVoteByAddress(uint voteID, address candidateAddr)
        external
        payable
    {
        uint candidateID = getCandidateID(voteID, candidateAddr);
        doVoteByID(voteID, candidateID);
    }
}
