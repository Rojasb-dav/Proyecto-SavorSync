package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.Comment;
import co.edu.umb.foodies.backend.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CommentRepository extends JpaRepository<Comment, String> {
    @Query("""
            select c as comment, author as author
            from Comment c join User author on author.id = c.clienteId
            where c.postId = :postId and c.status = 'activo' and author.isActive = true
            """)
    List<CommentWithAuthor> findActiveWithAuthor(String postId);

    interface CommentWithAuthor {
        Comment getComment();
        User getAuthor();
    }
}
