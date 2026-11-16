-- 02_sample_data.sql : sample records (dates are relative to today, so demos always work)
TRUNCATE event_expenses, registrations, club_members, events, venues, clubs, students RESTART IDENTITY CASCADE;

INSERT INTO students (name, email, phone, department, year, cgpa) VALUES
('Rafi Ahmed',     'rafi@example.edu',   '01711000001', 'ECE', 3, 3.45),
('Tasnim Akter',   'tasnim@example.edu', '01711000002', 'CSE', 3, 3.60),
('Sabbir Hossain', 'sabbir@example.edu', '01711000003', 'EEE', 2, 3.10),
('Mahin Islam',    'mahin@example.edu',  '01711000004', 'ECE', 3, 3.25),
('Nabila Khan',    'nabila@example.edu', '01711000005', 'CSE', 2, 3.80),
('Imran Hossain',  'imran@example.edu',  '01711000006', 'ME',  1, 2.95),
('Sadia Rahman',   'sadia@example.edu',  '01711000007', 'ECE', 2, 3.55),
('Arif Chowdhury', 'arif@example.edu',   '01711000008', 'CE',  4, 3.35),
('Fahim Reza',     'fahim@example.edu',  '01711000009', 'CSE', 4, 3.05),
('Lamia Sultana',  'lamia@example.edu',  '01711000010', 'EEE', 1, 3.70);

INSERT INTO clubs (name, description, email, faculty_advisor) VALUES
('Robotics Club',         'Builds robots and runs electronics workshops.', 'robotics@example.edu', 'Dr. Karim'),
('Cultural Society',      'Music, poetry, and cultural nights.',           'culture@example.edu',  'Ms. Sultana'),
('Sports Club',           'Inter-department tournaments.',                 'sports@example.edu',   'Mr. Alam'),
('Entrepreneurship Club', 'Startup talks and pitch days.',                 'startup@example.edu',  'Dr. Haque');

INSERT INTO venues (name, location, capacity) VALUES
('ECE Seminar Room',      'ECE Building, Floor 3',   80),
('University Auditorium', 'Administrative Building', 500),
('Central Field',         'Campus Center',           1000),
('Computer Lab 2',        'CSE Building, Floor 2',   50);

INSERT INTO club_members (student_id, club_id) VALUES
(1,1),(2,1),(3,1),(4,1),
(5,2),(7,2),(6,2),(8,2),
(3,3),(6,3),(8,3),(4,3),
(2,4),(7,4),(1,4),(9,4);

INSERT INTO events (title, description, start_date, end_date, capacity, status, club_id, venue_id) VALUES
('Line Follower Workshop',    'Hands-on robot building.',         (CURRENT_DATE - 10) + TIME '10:00', (CURRENT_DATE - 10) + TIME '13:00',  40, 'completed', 1, 4),
('Poetry Evening',            'Poetry and storytelling.',         (CURRENT_DATE - 7)  + TIME '18:00', (CURRENT_DATE - 7)  + TIME '20:00',  50, 'completed', 2, 1),
('Arduino Basics Bootcamp',   'Small group, only 3 seats.',       (CURRENT_DATE + 7)  + TIME '10:00', (CURRENT_DATE + 7)  + TIME '14:00',   3, 'scheduled', 1, 4),
('Inter-Department Football', 'Football between departments.',   (CURRENT_DATE + 10) + TIME '15:00', (CURRENT_DATE + 10) + TIME '18:00', 200, 'scheduled', 3, 3),
('Cricket Tournament',        'Cancelled: same field and time.',  (CURRENT_DATE + 10) + TIME '15:00', (CURRENT_DATE + 10) + TIME '18:00', 200, 'cancelled', 3, 3),
('Startup Pitch Day',         'Students pitch startup ideas.',    (CURRENT_DATE + 14) + TIME '14:00', (CURRENT_DATE + 14) + TIME '17:00',  60, 'scheduled', 4, 1),
('Winter Cultural Night',     'Music and dance performances.',    (CURRENT_DATE + 20) + TIME '17:00', (CURRENT_DATE + 20) + TIME '21:00', 400, 'scheduled', 2, 2);

INSERT INTO registrations (student_id, event_id, status) VALUES
(1,1,'attended'),(2,1,'attended'),(3,1,'attended'),(5,1,'cancelled'),
(5,2,'attended'),(7,2,'attended'),(6,2,'attended'),(8,2,'cancelled'),
(1,3,'registered'),(2,3,'registered'),(3,3,'registered'),(4,3,'cancelled'),
(3,4,'registered'),(6,4,'registered'),(8,4,'registered'),(4,4,'registered'),
(2,6,'registered'),(7,6,'registered'),(1,6,'registered'),
(5,7,'registered'),(7,7,'registered'),(6,7,'registered'),(8,7,'registered');

INSERT INTO event_expenses (event_id, description, amount, expense_date) VALUES
(1, 'Soldering kits',      4500.00, CURRENT_DATE - 12),
(1, 'Snacks',              1800.50, CURRENT_DATE - 10),
(2, 'Sound system rental', 3000.00, CURRENT_DATE - 8),
(2, 'Printing posters',     650.00, CURRENT_DATE - 9),
(3, 'Arduino boards',      7500.00, CURRENT_DATE - 2),
(4, 'Football kits',       5200.00, CURRENT_DATE - 1),
(4, 'Referee fee',         1500.00, CURRENT_DATE - 1),
(6, 'Banner printing',      900.00, CURRENT_DATE - 1),
(7, 'Stage decoration',   12000.00, CURRENT_DATE - 3);