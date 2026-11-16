-- Select ONE query with the mouse, then press F5.

-- Lab-style queries
SELECT * FROM students WHERE cgpa > 3.4;
SELECT DISTINCT department FROM students;
SELECT name FROM clubs WHERE name LIKE 'R%';
SELECT name, capacity FROM venues ORDER BY capacity DESC;
SELECT name FROM venues WHERE capacity = (SELECT MAX(capacity) FROM venues);
SELECT status, COUNT(*) FROM registrations GROUP BY status;
SELECT department, ROUND(AVG(cgpa), 2) FROM students GROUP BY department HAVING COUNT(*) > 1;
SELECT e.title, c.name FROM events e, clubs c WHERE e.club_id = c.club_id;
SELECT e.title, COUNT(r.registration_id) AS seats_taken
FROM events e LEFT JOIN registrations r ON r.event_id = e.event_id AND r.status IN ('registered', 'attended')
GROUP BY e.title ORDER BY e.title;

-- UPDATE and DELETE
UPDATE students SET cgpa = 3.50 WHERE student_id = 1;
DELETE FROM event_expenses WHERE expense_id = 1;

-- ALTER TABLE (select all 6 lines together; ROLLBACK undoes the changes)
BEGIN;
ALTER TABLE venues ADD COLUMN floor VARCHAR(20);
ALTER TABLE venues ALTER COLUMN floor TYPE VARCHAR(30);
ALTER TABLE venues RENAME COLUMN floor TO floor_name;
ALTER TABLE venues DROP COLUMN floor_name;
ROLLBACK;

-- Rules that must FAIL (each shows an error message)
INSERT INTO registrations (student_id, event_id) VALUES (1, 6);                              -- already registered (UNIQUE)
INSERT INTO venues (name, location, capacity) VALUES ('Test Hall', 'Block A', 0);            -- capacity must be > 0 (CHECK)
UPDATE events SET end_date = start_date - INTERVAL '1 hour' WHERE event_id = 1;              -- end before start (CHECK)
DELETE FROM clubs WHERE club_id = 1;                                                         -- club still has events (FOREIGN KEY)

-- ROLES: who is in which group
SELECT r.rolname AS member, g.rolname AS group_role
FROM pg_auth_members m
JOIN pg_roles r ON r.oid = m.member
JOIN pg_roles g ON g.oid = m.roleid
WHERE g.rolname LIKE 'event_%';

-- ROLES: what each group may do on each table
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('event_admins', 'event_club_admins', 'event_students')
ORDER BY grantee, table_name, privilege_type;

-- ROLES: act as a student (run these one by one; the last line returns you to normal)
SET ROLE event_students;
SELECT * FROM venues;                                                                        -- works
INSERT INTO venues (name, location, capacity) VALUES ('New Hall', 'Block B', 120);          -- permission denied
SELECT * FROM event_expenses;                                                                -- permission denied
RESET ROLE;

-- ROLES: take a permission away, then give it back
REVOKE INSERT ON registrations FROM event_students;
GRANT INSERT ON registrations TO event_students;