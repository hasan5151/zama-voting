// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint32, externalEuint32, ebool } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

/// @title Gizli Oylama Kontratı
/// @notice Bu kontrat FHE kullanarak tamamen gizli bir oylama sistemi sağlar
/// @dev Oylar şifreli olarak saklanır ve sadece oylama bittiğinde sonuç açıklanabilir
contract ConfidentialVoting is SepoliaConfig {
    
    // Oylama durumu
    enum VotingState { Active, Ended }
    
    // Kontrat sahibi (oylama yöneticisi)
    address public admin;
    
    // Oylama durumu
    VotingState public state;
    
    // Oylama konusu
    string public proposal;
    
    // Şifreli oy sayıları
    euint32 private yesVotes;
    euint32 private noVotes;
    
    // Oy kullanan adreslerin kaydı
    mapping(address => bool) public hasVoted;
    
    // Toplam oy sayısı (açık)
    uint32 public totalVotes;
    
    // Events
    event VoteCast(address indexed voter);
    event VotingEnded(uint32 yesCount, uint32 noCount);
    event VotingStarted(string proposal);
    
    /// @notice Kontrat oluşturulurken oylama konusu belirlenir
    /// @param _proposal Oylanacak konu
    constructor(string memory _proposal) {
        admin = msg.sender;
        proposal = _proposal;
        state = VotingState.Active;
        
        // Şifreli sayıları 0 ile başlat
        yesVotes = FHE.asEuint32(0);
        noVotes = FHE.asEuint32(0);
        
        emit VotingStarted(_proposal);
    }
    
    /// @notice Sadece admin kontrolü
    modifier onlyAdmin() {
        require(msg.sender == admin, "Sadece yonetici bu islemi yapabilir");
        _;
    }
    
    /// @notice Oylama aktif mi kontrolü
    modifier votingActive() {
        require(state == VotingState.Active, "Oylama bitmis");
        _;
    }
    
    /// @notice Şifreli oy kullanma fonksiyonu
    /// @param voteYes true ise evet, false ise hayır oyu
    /// @param inputEuint32 Şifreli input değeri (1 olarak gönderilmeli)
    /// @param inputProof Şifreleme kanıtı
    function vote(
        bool voteYes,
        externalEuint32 inputEuint32,
        bytes calldata inputProof
    ) external votingActive {
        require(!hasVoted[msg.sender], "Bu adres zaten oy kullanmis");
        
        // Şifreli değeri doğrula ve içe aktar
        euint32 encryptedVote = FHE.fromExternal(inputEuint32, inputProof);
        
        // Oya göre ilgili sayacı artır
        if (voteYes) {
            yesVotes = FHE.add(yesVotes, encryptedVote);
            FHE.allowThis(yesVotes);
        } else {
            noVotes = FHE.add(noVotes, encryptedVote);
            FHE.allowThis(noVotes);
        }
        
        // Oy kullandığını kaydet
        hasVoted[msg.sender] = true;
        totalVotes++;
        
        emit VoteCast(msg.sender);
    }
    
    /// @notice Basitleştirilmiş oy kullanma (test için)
    /// @param voteYes true ise evet, false ise hayır
    function voteSimple(bool voteYes) external votingActive {
        require(!hasVoted[msg.sender], "Bu adres zaten oy kullanmis");
        
        // 1 değerini şifreli olarak ekle
        euint32 one = FHE.asEuint32(1);
        
        if (voteYes) {
            yesVotes = FHE.add(yesVotes, one);
            FHE.allowThis(yesVotes);
        } else {
            noVotes = FHE.add(noVotes, one);
            FHE.allowThis(noVotes);
        }
        
        hasVoted[msg.sender] = true;
        totalVotes++;
        
        emit VoteCast(msg.sender);
    }
    
    /// @notice Oylamayı sonlandır ve sonuçları açıkla
    /// @dev Sadece admin çağırabilir
    function endVoting() external onlyAdmin {
        require(state == VotingState.Active, "Oylama zaten bitmis");
        
        state = VotingState.Ended;
        
        // Sonuçları çöz (decrypt)
        uint32 yesCount = FHE.decrypt(yesVotes);
        uint32 noCount = FHE.decrypt(noVotes);
        
        emit VotingEnded(yesCount, noCount);
    }
    
    /// @notice Şifreli evet oylarını döndürür (sadece contract erişebilir)
    function getEncryptedYesVotes() external view returns (euint32) {
        return yesVotes;
    }
    
    /// @notice Şifreli hayır oylarını döndürür (sadece contract erişebilir)
    function getEncryptedNoVotes() external view returns (euint32) {
        return noVotes;
    }
    
    /// @notice Oylama bilgilerini döndürür
    function getVotingInfo() external view returns (
        string memory _proposal,
        VotingState _state,
        uint32 _totalVotes,
        address _admin
    ) {
        return (proposal, state, totalVotes, admin);
    }
    
    /// @notice Belirli bir adresin oy kullanıp kullanmadığını kontrol eder
    function checkIfVoted(address voter) external view returns (bool) {
        return hasVoted[voter];
    }
}
