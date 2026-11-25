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

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            select t from PasswordResetToken t
            where lower(t.email) = :email and t.identityType = :identityType
              and t.purpose = :purpose and t.consumedAt is null
            order by t.createdAt desc
            """)
    List<PasswordResetToken> findActiveForIdentityForUpdateByEmail(
            @Param("email") String email,
            @Param("identityType") PasswordResetToken.IdentityType identityType,
            @Param("purpose") PasswordResetToken.Purpose purpose);

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
