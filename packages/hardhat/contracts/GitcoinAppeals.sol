pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "@1hive/celeste-helpers/contracts/Disputable.sol";

contract GitcoinAppeals is Disputable {

    enum Status {NOT_DISPUTED, GITCOIN_EVIDENCE, BEING_DISPUTED, ALLOWED, DENIED, FAILED_TO_RULE}

    address public gitcoinAccount;
    mapping(address => bool) public approvedAppealers;
    mapping(uint256 => Status) public disputeStatus;

    event AppealAllowed(address appealer);
    event AppealCreated(address appealer, uint256 disputeId, bytes originalProposal, bytes evidence);
    event AppealEvidenceFinalised(address gitcoinAccount, uint256 disputeId, bytes evidence);
    event AppealFinalised(uint256 disputeId, Status outcome);

    modifier isGitcoinAccount {
        require(msg.sender == gitcoinAccount, "ERR:BAD_APPROVER");
        _;
    }

    constructor(address _arbitrator, address _arbitratorManifest)Disputable(_arbitrator, _arbitratorManifest){}

    function allowAppeal(address _appealer) public isGitcoinAccount {
        approvedAppealers[_appealer] = true;

        emit AppealAllowed(_appealer);
    }

    function createAppeal(bytes memory _originalProposal, bytes memory _evidence) public {
        require(approvedAppealers[msg.sender], "ERR:NOT_APPROVED");
        approvedAppealers[msg.sender] = false;

        // This will take the necessary fees in Honey from this contract, if it doesn't have them it will revert
        uint256 disputeId = _createDisputeAgainst(msg.sender, gitcoinAccount, _originalProposal);
        arbitrator.submitEvidence(disputeId, msg.sender, _evidence);

        disputeStatus[disputeId] = Status.GITCOIN_EVIDENCE;
        emit AppealCreated(msg.sender, disputeId, _originalProposal, _evidence);
    }

    function submitGitcoinEvidence(uint256 _disputeId, bytes memory _evidence) public isGitcoinAccount {
        arbitrator.submitEvidence(_disputeId, msg.sender, _evidence);

        // This will revert if the evidence period has already been closed, eg if this function has already been called
        arbitrator.closeEvidencePeriod(_disputeId);

        disputeStatus[_disputeId] = Status.BEING_DISPUTED;
        emit AppealEvidenceFinalised(msg.sender, _disputeId, _evidence);
    }

    function finaliseAppeal(uint256 _disputeId) public {
        // This will revert if it's the incorrect time to rule
        uint256 ruling = _getRulingOf(_disputeId);

        if (ruling == 3) {
            disputeStatus[_disputeId] = Status.ALLOWED;
        } else if (ruling == 4) {
            disputeStatus[_disputeId] = Status.DENIED;
        } else {
            disputeStatus[_disputeId] = Status.FAILED_TO_RULE;
        }

        emit AppealFinalised(_disputeId, disputeStatus[_disputeId]);
    }
}
