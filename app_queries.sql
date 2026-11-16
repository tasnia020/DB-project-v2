-- Every query the website runs. Each query starts with a "-- name:" line.
-- %(name)s parts are filled in by Python.

-- ============================================================ HOME
-- name: home_stats
SELECT (SELECT COUNT(*) FROM students) AS students,
       (SELECT COUNT(*) FROM clubs)    AS clubs,
       (SELECT COUNT(*) FROM venues)   AS venues,
       (SELECT COUNT(*) FROM events)   AS events,
       (SELECT COUNT(*) FROM events WHERE status = 'scheduled' AND start_date > now()) AS upcoming_events,
       (SELECT COUNT(*) FROM registrations WHERE status IN ('registered', 'attended')) AS seats_taken;

-- ============================================================ DROPDOWNS
-- name: clubs_options
SELECT club_id AS id, name AS label FROM clubs ORDER BY name;

-- name: venues_options
SELECT venue_id AS id, name AS label FROM venues ORDER BY name;

-- name: students_options
SELECT student_id AS id, student_roll || ' - ' || name AS label
FROM students
ORDER BY student_roll;

-- name: events_options
SELECT event_id AS id, title || ' (' || status || ')' AS label
FROM events
ORDER BY start_date DESC;

-- ============================================================ STUDENTS
-- name: students_list
SELECT student_id, student_roll, name, email, phone, department, year, cgpa
FROM students
WHERE name ILIKE %(q)s OR email ILIKE %(q)s OR student_roll ILIKE %(q)s OR department ILIKE %(q)s
ORDER BY student_id;

-- name: students_get
SELECT student_id, student_roll, name, email, phone, department, year, cgpa
FROM students
WHERE student_id = %(id)s;

-- name: students_insert
INSERT INTO students (student_roll, name, email, phone, department, year, cgpa)
VALUES (%(student_roll)s, %(name)s, %(email)s, %(phone)s, %(department)s,
        %(year)s::smallint, %(cgpa)s::numeric);

-- name: students_update
UPDATE students
SET student_roll = %(student_roll)s, name = %(name)s, email = %(email)s, phone = %(phone)s,
    department = %(department)s, year = %(year)s::smallint, cgpa = %(cgpa)s::numeric
WHERE student_id = %(id)s;

-- name: students_delete
DELETE FROM students WHERE student_id = %(id)s;

-- ============================================================ CLUBS
-- name: clubs_list
SELECT c.club_id, c.name, c.faculty_advisor,
       (SELECT COUNT(*) FROM club_members m WHERE m.club_id = c.club_id) AS member_count,
       (SELECT COUNT(*) FROM events e WHERE e.club_id = c.club_id)       AS event_count
FROM clubs c
WHERE c.name ILIKE %(q)s OR c.faculty_advisor ILIKE %(q)s
ORDER BY c.club_id;

-- name: clubs_get
SELECT club_id, name, description, email, faculty_advisor FROM clubs WHERE club_id = %(id)s;

-- name: clubs_insert
INSERT INTO clubs (name, description, email, faculty_advisor)
VALUES (%(name)s, %(description)s, %(email)s, %(faculty_advisor)s);

-- name: clubs_update
UPDATE clubs
SET name = %(name)s, description = %(description)s, email = %(email)s,
    faculty_advisor = %(faculty_advisor)s
WHERE club_id = %(id)s;

-- name: clubs_delete
DELETE FROM clubs WHERE club_id = %(id)s;

-- ============================================================ VENUES
-- name: venues_list
SELECT venue_id, name, location, capacity
FROM venues
WHERE name ILIKE %(q)s OR location ILIKE %(q)s
ORDER BY venue_id;

-- name: venues_get
SELECT venue_id, name, location, capacity FROM venues WHERE venue_id = %(id)s;

-- name: venues_insert
INSERT INTO venues (name, location, capacity)
VALUES (%(name)s, %(location)s, %(capacity)s::int);

-- name: venues_update
UPDATE venues
SET name = %(name)s, location = %(location)s, capacity = %(capacity)s::int
WHERE venue_id = %(id)s;

-- name: venues_delete
DELETE FROM venues WHERE venue_id = %(id)s;

-- ============================================================ EVENTS
-- name: events_list
SELECT e.event_id, e.title, c.name AS club, v.name AS venue, e.start_date, e.status,
       e.capacity,
       COALESCE(t.seats_taken, 0) AS seats_taken,
       e.capacity - COALESCE(t.seats_taken, 0) AS seats_left
FROM events e
JOIN clubs c  ON c.club_id  = e.club_id
JOIN venues v ON v.venue_id = e.venue_id
LEFT JOIN (SELECT event_id, COUNT(*) AS seats_taken
           FROM registrations
           WHERE status IN ('registered', 'attended')
           GROUP BY event_id) t ON t.event_id = e.event_id
WHERE e.title ILIKE %(q)s OR c.name ILIKE %(q)s OR v.name ILIKE %(q)s
ORDER BY e.start_date DESC;

-- name: events_get
SELECT event_id, title, description, start_date, end_date, capacity, status, club_id, venue_id
FROM events
WHERE event_id = %(id)s;

-- name: events_insert
INSERT INTO events (title, description, start_date, end_date, capacity, status, club_id, venue_id)
SELECT %(title)s, %(description)s, %(start_date)s::timestamp, %(end_date)s::timestamp,
       %(capacity)s::int, %(status)s, %(club_id)s::int, v.venue_id
FROM venues v
WHERE v.venue_id = %(venue_id)s::int
  AND %(capacity)s::int <= v.capacity
  AND (%(status)s = 'cancelled'
       OR NOT EXISTS (SELECT 1 FROM events x
                      WHERE x.venue_id = v.venue_id
                        AND x.status <> 'cancelled'
                        AND x.start_date < %(end_date)s::timestamp
                        AND x.end_date   > %(start_date)s::timestamp));

-- name: events_update
UPDATE events e
SET title = %(title)s, description = %(description)s,
    start_date = %(start_date)s::timestamp, end_date = %(end_date)s::timestamp,
    capacity = %(capacity)s::int, status = %(status)s,
    club_id = %(club_id)s::int, venue_id = %(venue_id)s::int
WHERE e.event_id = %(id)s
  AND %(capacity)s::int <= (SELECT v.capacity FROM venues v WHERE v.venue_id = %(venue_id)s::int)
  AND %(capacity)s::int >= (SELECT COUNT(*) FROM registrations r
                            WHERE r.event_id = e.event_id AND r.status IN ('registered', 'attended'))
  AND (%(status)s = 'cancelled'
       OR NOT EXISTS (SELECT 1 FROM events x
                      WHERE x.venue_id = %(venue_id)s::int
                        AND x.event_id <> e.event_id
                        AND x.status <> 'cancelled'
                        AND x.start_date < %(end_date)s::timestamp
                        AND x.end_date   > %(start_date)s::timestamp));

-- name: events_delete
DELETE FROM events WHERE event_id = %(id)s;

-- ============================================================ CLUB MEMBERS
-- name: club_members_list
SELECT m.club_member_id, s.student_roll || ' - ' || s.name AS student, c.name AS club, m.join_date
FROM club_members m
JOIN students s ON s.student_id = m.student_id
JOIN clubs c    ON c.club_id    = m.club_id
WHERE s.name ILIKE %(q)s OR s.student_roll ILIKE %(q)s OR c.name ILIKE %(q)s
ORDER BY m.club_member_id;

-- name: club_members_get
SELECT club_member_id, student_id, club_id FROM club_members WHERE club_member_id = %(id)s;

-- name: club_members_insert
INSERT INTO club_members (student_id, club_id)
VALUES (%(student_id)s::int, %(club_id)s::int);

-- name: club_members_update
UPDATE club_members
SET student_id = %(student_id)s::int, club_id = %(club_id)s::int
WHERE club_member_id = %(id)s;

-- name: club_members_delete
DELETE FROM club_members WHERE club_member_id = %(id)s;

-- ============================================================ REGISTRATIONS
-- name: registrations_list
SELECT r.registration_id, s.name AS student, e.title AS event,
       r.registration_date AS registered_on, r.status
FROM registrations r
JOIN students s ON s.student_id = r.student_id
JOIN events e   ON e.event_id   = r.event_id
WHERE s.name ILIKE %(q)s OR s.student_roll ILIKE %(q)s OR e.title ILIKE %(q)s
ORDER BY r.registration_id;

-- name: registrations_get
SELECT registration_id, student_id, event_id, status
FROM registrations
WHERE registration_id = %(id)s;

-- name: registrations_insert
INSERT INTO registrations (student_id, event_id, status)
SELECT %(student_id)s::int, e.event_id, 'registered'
FROM events e
WHERE e.event_id = %(event_id)s::int
  AND e.status = 'scheduled'
  AND e.start_date > now()
  AND (SELECT COUNT(*) FROM registrations r
       WHERE r.event_id = e.event_id AND r.status IN ('registered', 'attended')) < e.capacity;

-- name: registrations_update
UPDATE registrations r
SET status = %(status)s
WHERE r.registration_id = %(id)s
  AND (%(status)s = 'cancelled'
       OR (SELECT COUNT(*) FROM registrations x
           WHERE x.event_id = r.event_id
             AND x.registration_id <> r.registration_id
             AND x.status IN ('registered', 'attended'))
          < (SELECT e.capacity FROM events e WHERE e.event_id = r.event_id));

-- name: registrations_delete
DELETE FROM registrations WHERE registration_id = %(id)s;

-- name: registrations_mine
SELECT r.registration_id, s.name AS student, e.title AS event,
       r.registration_date AS registered_on, r.status
FROM registrations r
JOIN students s ON s.student_id = r.student_id
JOIN events e   ON e.event_id   = r.event_id
WHERE r.student_id = %(student_id)s AND e.title ILIKE %(q)s
ORDER BY r.registration_id;

-- ============================================================ EXPENSES
-- name: expenses_list
SELECT x.expense_id, e.title AS event, x.description, x.amount, x.expense_date
FROM event_expenses x
JOIN events e ON e.event_id = x.event_id
WHERE e.title ILIKE %(q)s OR x.description ILIKE %(q)s
ORDER BY x.expense_date DESC, x.expense_id DESC;

-- name: expenses_get
SELECT expense_id, event_id, description, amount, expense_date
FROM event_expenses
WHERE expense_id = %(id)s;

-- name: expenses_insert
INSERT INTO event_expenses (event_id, description, amount, expense_date)
VALUES (%(event_id)s::int, %(description)s, %(amount)s::numeric, %(expense_date)s::date);

-- name: expenses_update
UPDATE event_expenses
SET event_id = %(event_id)s::int, description = %(description)s,
    amount = %(amount)s::numeric, expense_date = %(expense_date)s::date
WHERE expense_id = %(id)s;

-- name: expenses_delete
DELETE FROM event_expenses WHERE expense_id = %(id)s;

-- ============================================================ USERS (admin only)
-- name: users_list
SELECT u.user_id, u.username, u.role,
       s.student_roll || ' - ' || s.name AS student, c.name AS club
FROM users u
LEFT JOIN students s ON s.student_id = u.student_id
LEFT JOIN clubs c    ON c.club_id    = u.club_id
WHERE u.username ILIKE %(q)s OR u.role ILIKE %(q)s
ORDER BY u.user_id;

-- name: users_get
SELECT user_id, username, role, club_id, student_id FROM users WHERE user_id = %(id)s;

-- name: users_insert
INSERT INTO users (username, password_hash, role, club_id, student_id)
VALUES (%(username)s, crypt(%(password)s, gen_salt('bf')), %(role)s,
        %(club_id)s::int, %(student_id)s::int);

-- name: users_update
UPDATE users
SET role = %(role)s, club_id = %(club_id)s::int, student_id = %(student_id)s::int
WHERE user_id = %(id)s;

-- name: users_delete
DELETE FROM users WHERE user_id = %(id)s;

-- ============================================================ LOGIN AND SIGN-UP
-- name: auth_login
SELECT u.user_id, u.username, u.role, u.student_id, u.club_id,
       c.name AS club_name, s.name AS student_name
FROM users u
LEFT JOIN clubs c    ON c.club_id    = u.club_id
LEFT JOIN students s ON s.student_id = u.student_id
WHERE u.username = %(username)s
  AND u.password_hash = crypt(%(password)s, u.password_hash);

-- name: signup_student
WITH s AS (
    INSERT INTO students (student_roll, name, email, phone, department, year)
    VALUES (%(student_roll)s, %(name)s, %(email)s, %(phone)s, %(department)s, %(year)s::smallint)
    ON CONFLICT (student_roll) DO UPDATE SET student_roll = EXCLUDED.student_roll
    WHERE students.email = EXCLUDED.email
    RETURNING student_id
)
INSERT INTO users (username, password_hash, role, student_id)
SELECT %(student_roll)s, crypt(%(password)s, gen_salt('bf')), 'student', student_id FROM s;

-- ============================================================ OWNERSHIP CHECKS
-- name: event_club
SELECT club_id FROM events WHERE event_id = %(id)s;

-- name: member_club
SELECT club_id FROM club_members WHERE club_member_id = %(id)s;

-- name: expense_club
SELECT e.club_id
FROM event_expenses x JOIN events e ON e.event_id = x.event_id
WHERE x.expense_id = %(id)s;

-- name: registration_owner
SELECT student_id FROM registrations WHERE registration_id = %(id)s;

-- ============================================================ REPORTS
-- name: report_registrations
SELECT e.title AS event, c.name AS club, e.capacity,
       COALESCE(t.seats_taken, 0) AS seats_taken,
       e.capacity - COALESCE(t.seats_taken, 0) AS seats_left,
       ROUND(100.0 * COALESCE(t.seats_taken, 0) / e.capacity, 1) AS occupancy_pct
FROM events e
JOIN clubs c ON c.club_id = e.club_id
LEFT JOIN (SELECT event_id, COUNT(*) AS seats_taken
           FROM registrations
           WHERE status IN ('registered', 'attended')
           GROUP BY event_id) t ON t.event_id = e.event_id
ORDER BY e.title;

-- name: report_clubs
SELECT c.name AS club,
       COUNT(DISTINCT m.club_member_id) AS members,
       COUNT(DISTINCT e.event_id)       AS events
FROM clubs c
LEFT JOIN club_members m ON m.club_id = c.club_id
LEFT JOIN events e       ON e.club_id = c.club_id
GROUP BY c.club_id, c.name
ORDER BY c.name;

-- name: report_expenses_event
SELECT e.title AS event, COUNT(x.expense_id) AS expense_count,
       COALESCE(SUM(x.amount), 0) AS total_amount
FROM events e
LEFT JOIN event_expenses x ON x.event_id = e.event_id
GROUP BY e.event_id, e.title
ORDER BY total_amount DESC, e.title;

-- name: report_expenses_club
SELECT c.name AS club, COALESCE(SUM(x.amount), 0) AS total_amount
FROM clubs c
LEFT JOIN events e         ON e.club_id  = c.club_id
LEFT JOIN event_expenses x ON x.event_id = e.event_id
GROUP BY c.club_id, c.name
ORDER BY total_amount DESC, c.name;

-- name: report_expenses_month
SELECT to_char(expense_date, 'YYYY-MM') AS month,
       COUNT(*) AS expense_count, SUM(amount) AS total_amount
FROM event_expenses
GROUP BY to_char(expense_date, 'YYYY-MM')
ORDER BY month;

-- name: report_top_students
SELECT s.student_roll, s.name AS student, s.department,
       COUNT(r.registration_id) AS registrations
FROM students s
JOIN registrations r ON r.student_id = s.student_id
WHERE r.status IN ('registered', 'attended')
GROUP BY s.student_id, s.student_roll, s.name, s.department
HAVING COUNT(r.registration_id) >= 1
ORDER BY registrations DESC, s.name
LIMIT 10;

-- name: report_departments
SELECT department, COUNT(*) AS students, ROUND(AVG(cgpa), 2) AS average_cgpa
FROM students
GROUP BY department
HAVING COUNT(*) >= 1
ORDER BY students DESC, department;