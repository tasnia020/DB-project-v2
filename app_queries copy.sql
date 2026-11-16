-- Each query starts with a line like "-- name: students_list" and is loaded by name in app.py.
-- The %(x)s parts are placeholders that Python fills in. To test one in pgAdmin, replace them with real values.

-- name: home_stats
SELECT (SELECT COUNT(*) FROM students) AS students,
       (SELECT COUNT(*) FROM clubs) AS clubs,
       (SELECT COUNT(*) FROM venues) AS venues,
       (SELECT COUNT(*) FROM events) AS events,
       (SELECT COUNT(*) FROM events WHERE status = 'scheduled' AND start_date > LOCALTIMESTAMP) AS upcoming_events,
       (SELECT COUNT(*) FROM registrations WHERE status IN ('registered', 'attended')) AS seats_taken;

-- name: students_list
SELECT student_id, name, email, phone, department, year, cgpa
FROM students
WHERE name ILIKE %(q)s OR email ILIKE %(q)s OR department ILIKE %(q)s
ORDER BY student_id;

-- name: students_get
SELECT * FROM students WHERE student_id = %(id)s;

-- name: students_insert
INSERT INTO students (name, email, phone, department, year, cgpa)
VALUES (%(name)s, %(email)s, %(phone)s, %(department)s, %(year)s, %(cgpa)s);

-- name: students_update
UPDATE students
SET name = %(name)s, email = %(email)s, phone = %(phone)s,
    department = %(department)s, year = %(year)s, cgpa = %(cgpa)s
WHERE student_id = %(id)s;

-- name: students_delete
DELETE FROM students WHERE student_id = %(id)s;

-- name: clubs_list
SELECT c.club_id, c.name, c.faculty_advisor,
       COALESCE(m.member_count, 0) AS member_count,
       COALESCE(ev.event_count, 0) AS event_count
FROM clubs c
LEFT JOIN (SELECT club_id, COUNT(*) AS member_count FROM club_members GROUP BY club_id) m
       ON m.club_id = c.club_id
LEFT JOIN (SELECT club_id, COUNT(*) AS event_count FROM events GROUP BY club_id) ev
       ON ev.club_id = c.club_id
WHERE c.name ILIKE %(q)s OR c.faculty_advisor ILIKE %(q)s
ORDER BY c.club_id;

-- name: clubs_get
SELECT * FROM clubs WHERE club_id = %(id)s;

-- name: clubs_insert
INSERT INTO clubs (name, description, email, faculty_advisor)
VALUES (%(name)s, %(description)s, %(email)s, %(faculty_advisor)s);

-- name: clubs_update
UPDATE clubs
SET name = %(name)s, description = %(description)s, email = %(email)s, faculty_advisor = %(faculty_advisor)s
WHERE club_id = %(id)s;

-- name: clubs_delete
DELETE FROM clubs WHERE club_id = %(id)s;

-- name: venues_list
SELECT venue_id, name, location, capacity
FROM venues
WHERE name ILIKE %(q)s OR location ILIKE %(q)s
ORDER BY venue_id;

-- name: venues_get
SELECT * FROM venues WHERE venue_id = %(id)s;

-- name: venues_insert
INSERT INTO venues (name, location, capacity)
VALUES (%(name)s, %(location)s, %(capacity)s);

-- name: venues_update
UPDATE venues SET name = %(name)s, location = %(location)s, capacity = %(capacity)s
WHERE venue_id = %(id)s;

-- name: venues_delete
DELETE FROM venues WHERE venue_id = %(id)s;

-- name: events_list
SELECT e.event_id, e.title, c.name AS club, v.name AS venue, e.start_date, e.status, e.capacity,
       COALESCE(r.seats_taken, 0) AS seats_taken,
       e.capacity - COALESCE(r.seats_taken, 0) AS seats_left
FROM events e
JOIN clubs c ON c.club_id = e.club_id
JOIN venues v ON v.venue_id = e.venue_id
LEFT JOIN (SELECT event_id, COUNT(*) AS seats_taken
           FROM registrations
           WHERE status IN ('registered', 'attended')
           GROUP BY event_id) r ON r.event_id = e.event_id
WHERE e.title ILIKE %(q)s OR c.name ILIKE %(q)s OR v.name ILIKE %(q)s OR e.status ILIKE %(q)s
ORDER BY e.start_date;

-- name: events_get
SELECT * FROM events WHERE event_id = %(id)s;

-- name: events_insert
INSERT INTO events (title, description, start_date, end_date, capacity, status, club_id, venue_id)
SELECT %(title)s::text, %(description)s::text, %(start_date)s::timestamp, %(end_date)s::timestamp,
       %(capacity)s::int, %(status)s::text, %(club_id)s::int, %(venue_id)s::int
WHERE %(capacity)s::int <= (SELECT capacity FROM venues WHERE venue_id = %(venue_id)s::int)
  AND NOT EXISTS (SELECT 1 FROM events e
                  WHERE e.venue_id = %(venue_id)s::int
                    AND e.status <> 'cancelled'
                    AND %(status)s::text <> 'cancelled'
                    AND e.start_date < %(end_date)s::timestamp
                    AND e.end_date > %(start_date)s::timestamp);

-- name: events_update
UPDATE events
SET title = %(title)s::text, description = %(description)s::text,
    start_date = %(start_date)s::timestamp, end_date = %(end_date)s::timestamp,
    capacity = %(capacity)s::int, status = %(status)s::text,
    club_id = %(club_id)s::int, venue_id = %(venue_id)s::int
WHERE event_id = %(id)s::int
  AND %(capacity)s::int <= (SELECT capacity FROM venues WHERE venue_id = %(venue_id)s::int)
  AND %(capacity)s::int >= (SELECT COUNT(*) FROM registrations
                            WHERE event_id = %(id)s::int AND status IN ('registered', 'attended'))
  AND NOT EXISTS (SELECT 1 FROM events e
                  WHERE e.event_id <> %(id)s::int
                    AND e.venue_id = %(venue_id)s::int
                    AND e.status <> 'cancelled'
                    AND %(status)s::text <> 'cancelled'
                    AND e.start_date < %(end_date)s::timestamp
                    AND e.end_date > %(start_date)s::timestamp);

-- name: events_delete
DELETE FROM events WHERE event_id = %(id)s;

-- name: club_members_list
SELECT cm.club_member_id, s.name AS student, c.name AS club, cm.join_date
FROM club_members cm
JOIN students s ON s.student_id = cm.student_id
JOIN clubs c ON c.club_id = cm.club_id
WHERE s.name ILIKE %(q)s OR c.name ILIKE %(q)s
ORDER BY c.name, s.name;

-- name: club_members_get
SELECT * FROM club_members WHERE club_member_id = %(id)s;

-- name: club_members_insert
INSERT INTO club_members (student_id, club_id) VALUES (%(student_id)s, %(club_id)s);

-- name: club_members_update
UPDATE club_members SET student_id = %(student_id)s, club_id = %(club_id)s
WHERE club_member_id = %(id)s;

-- name: club_members_delete
DELETE FROM club_members WHERE club_member_id = %(id)s;

-- name: registrations_list
SELECT r.registration_id, s.name AS student, e.title AS event,
       to_char(r.registration_date, 'YYYY-MM-DD HH24:MI') AS registered_on, r.status
FROM registrations r
JOIN students s ON s.student_id = r.student_id
JOIN events e ON e.event_id = r.event_id
WHERE s.name ILIKE %(q)s OR e.title ILIKE %(q)s OR r.status ILIKE %(q)s
ORDER BY e.title, s.name;

-- name: registrations_get
SELECT * FROM registrations WHERE registration_id = %(id)s;

-- name: registrations_insert
INSERT INTO registrations (student_id, event_id, status)
SELECT %(student_id)s::int, %(event_id)s::int, 'registered'
WHERE EXISTS (SELECT 1 FROM events e
              WHERE e.event_id = %(event_id)s::int
                AND e.status = 'scheduled'
                AND e.start_date > LOCALTIMESTAMP)
  AND (SELECT COUNT(*) FROM registrations r
       WHERE r.event_id = %(event_id)s::int AND r.status IN ('registered', 'attended'))
      < (SELECT capacity FROM events WHERE event_id = %(event_id)s::int);

-- name: registrations_update
UPDATE registrations
SET status = %(status)s::text
WHERE registration_id = %(id)s::int
  AND (%(status)s::text = 'cancelled'
       OR status IN ('registered', 'attended')
       OR (SELECT COUNT(*) FROM registrations r
           WHERE r.event_id = registrations.event_id AND r.status IN ('registered', 'attended'))
          < (SELECT e.capacity FROM events e WHERE e.event_id = registrations.event_id));

-- name: registrations_delete
DELETE FROM registrations WHERE registration_id = %(id)s;

-- name: expenses_list
SELECT x.expense_id, e.title AS event, x.description, x.amount, x.expense_date
FROM event_expenses x
JOIN events e ON e.event_id = x.event_id
WHERE e.title ILIKE %(q)s OR x.description ILIKE %(q)s
ORDER BY x.expense_date DESC, x.expense_id;

-- name: expenses_get
SELECT * FROM event_expenses WHERE expense_id = %(id)s;

-- name: expenses_insert
INSERT INTO event_expenses (event_id, description, amount, expense_date)
VALUES (%(event_id)s, %(description)s, %(amount)s, %(expense_date)s);

-- name: expenses_update
UPDATE event_expenses
SET event_id = %(event_id)s, description = %(description)s, amount = %(amount)s, expense_date = %(expense_date)s
WHERE expense_id = %(id)s;

-- name: expenses_delete
DELETE FROM event_expenses WHERE expense_id = %(id)s;

-- name: students_options
SELECT student_id AS id, name AS label FROM students ORDER BY name;

-- name: clubs_options
SELECT club_id AS id, name AS label FROM clubs ORDER BY name;

-- name: venues_options
SELECT venue_id AS id, name AS label FROM venues ORDER BY name;

-- name: events_options
SELECT event_id AS id, title AS label FROM events ORDER BY start_date;

-- name: report_registrations
SELECT e.title, c.name AS club, e.status, e.capacity,
       COALESCE(r.seats_taken, 0) AS seats_taken,
       e.capacity - COALESCE(r.seats_taken, 0) AS seats_left,
       ROUND(100.0 * COALESCE(r.seats_taken, 0) / e.capacity, 1) AS occupancy_pct
FROM events e
JOIN clubs c ON c.club_id = e.club_id
LEFT JOIN (SELECT event_id, COUNT(*) AS seats_taken
           FROM registrations
           WHERE status IN ('registered', 'attended')
           GROUP BY event_id) r ON r.event_id = e.event_id
ORDER BY seats_taken DESC, e.title;

-- name: report_clubs
SELECT c.name AS club, c.faculty_advisor,
       COALESCE(m.member_count, 0) AS member_count,
       COALESCE(ev.event_count, 0) AS event_count
FROM clubs c
LEFT JOIN (SELECT club_id, COUNT(*) AS member_count FROM club_members GROUP BY club_id) m
       ON m.club_id = c.club_id
LEFT JOIN (SELECT club_id, COUNT(*) AS event_count FROM events GROUP BY club_id) ev
       ON ev.club_id = c.club_id
ORDER BY event_count DESC, c.name;

-- name: report_expenses_event
SELECT e.title, c.name AS club, SUM(x.amount) AS total_expenses
FROM event_expenses x
JOIN events e ON e.event_id = x.event_id
JOIN clubs c ON c.club_id = e.club_id
GROUP BY e.event_id, e.title, c.name
ORDER BY total_expenses DESC;

-- name: report_expenses_club
SELECT c.name AS club, COUNT(x.expense_id) AS expense_entries, COALESCE(SUM(x.amount), 0) AS total_expenses
FROM clubs c
LEFT JOIN events e ON e.club_id = c.club_id
LEFT JOIN event_expenses x ON x.event_id = e.event_id
GROUP BY c.club_id, c.name
ORDER BY total_expenses DESC;

-- name: report_expenses_month
SELECT to_char(expense_date, 'YYYY-MM') AS month, COUNT(*) AS entries, SUM(amount) AS total
FROM event_expenses
GROUP BY to_char(expense_date, 'YYYY-MM')
ORDER BY month;

-- name: report_top_students
SELECT s.name, s.department, COUNT(*) AS events_joined
FROM students s
JOIN registrations r ON r.student_id = s.student_id
WHERE r.status IN ('registered', 'attended')
GROUP BY s.student_id, s.name, s.department
ORDER BY events_joined DESC, s.name
LIMIT 5;

-- name: report_departments
SELECT department, COUNT(*) AS students, ROUND(AVG(cgpa), 2) AS avg_cgpa
FROM students
GROUP BY department
HAVING COUNT(*) >= 1
ORDER BY students DESC, department;