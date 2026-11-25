package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.PasswordResetToken;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PasswordResetTokenRepository extends JpaRepository<PasswordResetToken, String> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select t from PasswordResetToken t where t.id = :id")
    Optional<PasswordResetToken> findByIdForUpdate(@Param("id") String id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            select t from PasswordResetToken t
            where t.identityId = :identityId and t.purpose = :purpose
              and t.consumedAt is null
            order by t.createdAt desc
            """)
    List<PasswordResetToken> findActiveForIdentityForUpdate(
            @Param("identityId") String identityId,
            @Param("purpose") PasswordResetToken.Purpose purpose);

    @Query(value = """
            SELECT * FROM tokens_recuperacion
            WHERE identity_type = :identityType AND purpose = :purpose
              AND active_identity_id = :identityId
            FOR UPDATE
            """, nativeQuery = true)
    Optional<PasswordResetToken> findActiveForUpdate(
            @Param("identityId") String identityId,
            @Param("identityType") String identityType,
            @Param("purpose") String purpose);

    @Modifying
    @Query("""
            update PasswordResetToken t set t.consumedAt = CURRENT_TIMESTAMP
            where t.id = :id and t.consumedAt is null
            """)
    int consumeForResend(@Param("id") String id);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update PasswordResetToken t
            set t.consumedAt = CURRENT_TIMESTAMP
            where t.identityId = :identityId and t.purpose = :purpose
              and t.consumedAt is null
            """)
    int consumeActiveForIdentity(
            @Param("identityId") String identityId,
            @Param("purpose") PasswordResetToken.Purpose purpose);
}
