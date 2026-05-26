package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.PasswordResetToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface PasswordResetTokenRepository extends JpaRepository<PasswordResetToken, String> {
    Optional<PasswordResetToken> findByEmailAndCode(String email, String code);
    
    @Modifying
    @Query("DELETE FROM PasswordResetToken p WHERE p.email = ?1")
    void deleteByEmail(String email);
}
