-- 03_roles.sql : database roles. Roles belong to the whole PostgreSQL server,
-- not to one database, so run this file only once.
-- If you ever need to start over, see the reset lines at the bottom.

-- group roles (hold the permissions; nobody logs in with these)
CREATE ROLE event_admins NOLOGIN;
CREATE ROLE event_club_admins NOLOGIN;
CREATE ROLE event_students NOLOGIN;

-- login roles (the website connects as these); each one joins a group
CREATE ROLE admin_user      LOGIN PASSWORD 'event_pass_123' IN ROLE event_admins;
CREATE ROLE club_admin_user LOGIN PASSWORD 'event_pass_123' IN ROLE event_club_admins;
CREATE ROLE student_user    LOGIN PASSWORD 'event_pass_123' IN ROLE event_students;

-- RESET (only if you must start over; select these lines and run them):
-- DROP OWNED BY admin_user, club_admin_user, student_user, event_admins, event_club_admins, event_students;
-- DROP ROLE admin_user, club_admin_user, student_user, event_admins, event_club_admins, event_students;