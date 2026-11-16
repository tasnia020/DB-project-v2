-- 04_grants.sql : who may do what.
-- Permissions belong to the tables, so run this again whenever you re-run 01_schema.sql.

-- Admin: everything
GRANT ALL PRIVILEGES ON students, clubs, venues, events, club_members, registrations, event_expenses
TO event_admins;

-- Club admin: read everything; change events, members, registrations, and expenses
GRANT SELECT ON students, clubs, venues, events, club_members, registrations, event_expenses
TO event_club_admins;
GRANT INSERT, UPDATE, DELETE ON events, club_members, registrations, event_expenses
TO event_club_admins;

-- Student: read most things (but not expenses); register for events; join clubs
GRANT SELECT ON students, clubs, venues, events, club_members, registrations
TO event_students;
GRANT INSERT, UPDATE ON registrations TO event_students;
GRANT INSERT ON club_members TO event_students;