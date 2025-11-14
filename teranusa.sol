// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILandViewer {
    function viewLand(uint certificate) external view returns (address, uint, string memory);
}

contract LandBase {
    struct Land {
        uint certificate;
        uint size;
        address owner;
        Status status;
    }

    enum Status {
        None,
        Pending,
        Verified
    }

    mapping(uint => Land) internal lands;
    uint[] internal landCertificates;

    function _createLand(uint certificate, uint size, address owner) internal {
        lands[certificate] = Land(certificate, size, owner, Status.Pending);
        landCertificates.push(certificate);
    }

    function _verifyLand(uint certificate) internal {
        lands[certificate].status = Status.Verified;
    }

    function _transferLand(uint certificate, address newOwner) internal {
        lands[certificate].owner = newOwner;
    }
}

contract TeranusaLand is LandBase, ILandViewer {
    address public immutable developer;
    uint public constant registrationFee = 0.01 ether;

    mapping(address => bool) public isAgent;
    address[] public agentList;

    event LandRegistered(uint certificate, address owner);
    event LandVerified(uint certificate, address agent);
    event LandTransferred(uint certificate, address from, address to);
    event AgentAdded(address agent);
    event AgentRevoked(address agent);
    event FeePaid(address citizen, uint amount);
    event ExternalViewResult(bool success, address owner);

    error NotDeveloper();
    error NotAgent();
    error NotOwner();
    error NotVerified();
    error AlreadyExists();
    error InvalidCertificate();

    constructor() {
        developer = msg.sender;
    }

    modifier onlyDeveloper() {
        if (msg.sender != developer) revert NotDeveloper();
        _;
    }

    modifier onlyAgent() {
        if (!isAgent[msg.sender]) revert NotAgent();
        _;
    }

    modifier onlyOwnerOf(uint certificate) {
        if (lands[certificate].owner != msg.sender) revert NotOwner();
        _;
    }

    // ----------------------------------
    // AGENT MANAGEMENT
    // ----------------------------------
    function addAgent(address newAgent) external onlyDeveloper {
        require(!isAgent[newAgent], "Already agent");
        isAgent[newAgent] = true;
        agentList.push(newAgent);
        emit AgentAdded(newAgent);
    }

    function revokeAgent(address agent) external onlyDeveloper {
        require(isAgent[agent], "Not agent");
        isAgent[agent] = false;

        for (uint i = 0; i < agentList.length; i++) {
            if (agentList[i] == agent) {
                agentList[i] = agentList[agentList.length - 1];
                agentList.pop();
                break;
            }
        }

        emit AgentRevoked(agent);
    }

    function getAgents() external view returns (address[] memory) {
        return agentList;
    }

    // ----------------------------------
    // CITIZEN — PAYABLE FOR REGISTRATION
    // ----------------------------------
    function registerLand(uint certificate, uint size) external payable {
        if (lands[certificate].certificate != 0) revert AlreadyExists();
        require(msg.value == registrationFee, "Incorrect fee");

        _createLand(certificate, size, msg.sender);

        // Send fee to developer (ETHER TRANSFER)
        payable(developer).transfer(msg.value);

        emit FeePaid(msg.sender, msg.value);
        emit LandRegistered(certificate, msg.sender);
    }

    // ----------------------------------
    // AGENT — VERIFY OWNERSHIP
    // ----------------------------------
    function verifyOwnership(uint certificate) external onlyAgent {
        if (lands[certificate].certificate == 0) revert InvalidCertificate();

        _verifyLand(certificate);
        emit LandVerified(certificate, msg.sender);
    }

    // ----------------------------------
    // CITIZEN — TRANSFER LAND
    // ----------------------------------
    function transferLand(uint certificate, address newOwner)
        external
        onlyOwnerOf(certificate)
    {
        if (lands[certificate].status != Status.Verified) revert NotVerified();

        _transferLand(certificate, newOwner);
        emit LandTransferred(certificate, msg.sender, newOwner);
    }

    // ----------------------------------
    // PUBLIC VIEWERS
    // ----------------------------------
    function viewLand(uint certificate)
        external
        view
        override
        returns (address, uint, string memory)
    {
        Land memory l = lands[certificate];
        if (l.certificate == 0) revert InvalidCertificate();

        string memory st = l.status == Status.Pending
            ? "Pending"
            : (l.status == Status.Verified ? "Verified" : "None");

        return (l.owner, l.size, st);
    }

    function viewAllCertificates() external view returns (uint[] memory) {
        return landCertificates;
    }

    // ----------------------------------
    // PURE & VIEW EXAMPLES
    // ----------------------------------
    function examplePure() external pure returns (uint) {
        return 999;
    }

    function exampleView() external view returns (address) {
        return developer;
    }

    // ----------------------------------
    // TRY / CATCH DEMONSTRATION
    // ----------------------------------
    function tryExternalView(address contractAddress, uint certificate)
        external
        returns (bool success, address owner)
    {
        try ILandViewer(contractAddress).viewLand(certificate) returns (
            address o,
            uint,
            string memory
        ) {
            emit ExternalViewResult(true, o);
            return (true, o);
        } catch {
            emit ExternalViewResult(false, address(0));
            return (false, address(0));
        }
    }
}
