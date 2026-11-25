package co.edu.umb.foodies.backend.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

@Service
public class AuthRateLimitService {

    private final JdbcTemplate jdbc;
    private final int identityLimit;
    private final int sourceLimit;
    private final int windowMinutes;
    private final int resendSeconds;

    public AuthRateLimitService(
            JdbcTemplate jdbc,
            @Value("${app.security.codes.max-per-hour:5}") int identityLimit,
            @Value("${app.security.codes.source-max-per-hour:100}") int sourceLimit,
            @Value("${app.security.codes.window-minutes:60}") int windowMinutes,
            @Value("${app.security.codes.resend-seconds:60}") int resendSeconds) {
        this.jdbc = jdbc;
        this.identityLimit = identityLimit;
        this.sourceLimit = sourceLimit;
        this.windowMinutes = windowMinutes;
        this.resendSeconds = resendSeconds;
    }

    /**
     * Records source attempts independently of the business transaction.
     * Only requests accepted by both buckets use the identity's delivery allowance.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public boolean record(String identityKey, String sourceKey) {
        LocalDateTime now = LocalDateTime.now();
        List<Bucket> buckets = new ArrayList<>();
        buckets.add(new Bucket(identityKey, identityLimit, true));
        if (!sourceKey.equals(identityKey)) {
            buckets.add(new Bucket(sourceKey, sourceLimit, false));
        }
        buckets.sort(Comparator.comparing(Bucket::key));

        for (Bucket bucket : buckets) {
            jdbc.update("""
                    INSERT INTO auth_rate_limits
                      (bucket_key, window_started_at, request_count, last_requested_at)
                    VALUES (?, ?, 0, NULL)
                    ON DUPLICATE KEY UPDATE bucket_key = auth_rate_limits.bucket_key
                    """, bucket.key(), now);
        }

        boolean allowed = true;
        List<LockedBucket> locked = new ArrayList<>();
        for (Bucket bucket : buckets) {
            RateRow row = jdbc.queryForObject("""
                    SELECT window_started_at, request_count, last_requested_at
                    FROM auth_rate_limits WHERE bucket_key = ? FOR UPDATE
                    """, (rs, rowNum) -> new RateRow(
                    rs.getTimestamp("window_started_at").toLocalDateTime(),
                    rs.getInt("request_count"),
                    rs.getTimestamp("last_requested_at") == null
                            ? null : rs.getTimestamp("last_requested_at").toLocalDateTime()
            ), bucket.key());

            boolean expired = !row.windowStartedAt().plusMinutes(windowMinutes).isAfter(now);
            int count = expired ? 0 : row.requestCount();
            boolean coolingDown = bucket.identityBucket() && resendSeconds > 0
                    && row.lastRequestedAt() != null
                    && row.lastRequestedAt().plusSeconds(resendSeconds).isAfter(now);
            if (count >= bucket.limit() || coolingDown) allowed = false;
            locked.add(new LockedBucket(bucket, expired ? now : row.windowStartedAt(), count));
        }

        for (LockedBucket state : locked) {
            Bucket bucket = state.bucket();
            if (bucket.identityBucket() && !allowed) continue;
            jdbc.update("""
                    UPDATE auth_rate_limits
                    SET window_started_at = ?, request_count = ?,
                        last_requested_at = CASE
                          WHEN ? = 1 THEN ?
                          ELSE last_requested_at
                        END
                    WHERE bucket_key = ?
                    """, state.windowStartedAt(), Math.min(state.count() + 1, bucket.limit()),
                    bucket.identityBucket() ? 1 : 0, now, bucket.key());
        }
        return allowed;
    }

    private record Bucket(String key, int limit, boolean identityBucket) {}
    private record LockedBucket(Bucket bucket, LocalDateTime windowStartedAt, int count) {}
    private record RateRow(LocalDateTime windowStartedAt, int requestCount, LocalDateTime lastRequestedAt) {}
}
