package co.edu.umb.foodies.backend.controller;

import org.junit.jupiter.api.Test;
import javax.sql.DataSource;
import java.sql.SQLException;
import java.sql.Connection;
import java.sql.Statement;
import java.sql.ResultSet;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

class HealthControllerTest {
    @Test
    void healthExposesOnlyStatusForReachableAndUnavailableDatabase() throws Exception {
        DataSource dataSource = mock(DataSource.class);
        Connection connection = mock(Connection.class);
        Statement statement = mock(Statement.class);
        ResultSet row = mock(ResultSet.class);
        when(dataSource.getConnection()).thenReturn(connection);
        when(connection.createStatement()).thenReturn(statement);
        when(statement.executeQuery("SELECT 1")).thenReturn(row);
        when(row.next()).thenReturn(true, false);
        when(row.getInt(1)).thenReturn(1);
        var metadata = mock(java.sql.ResultSetMetaData.class);
        when(row.getMetaData()).thenReturn(metadata);
        when(metadata.getColumnCount()).thenReturn(1);
        var health = new HealthController(dataSource);
        assertThat(health.health().getBody()).containsOnlyKeys("status").containsEntry("status", "UP");

        when(dataSource.getConnection()).thenThrow(new SQLException("internal connection details"));
        var unavailable = health.health();
        assertThat(unavailable.getStatusCode().value()).isEqualTo(503);
        assertThat(unavailable.getBody()).containsOnlyKeys("status").containsEntry("status", "DOWN");
    }
}
