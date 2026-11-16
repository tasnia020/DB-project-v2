-- 01_schema.sql : tables, keys, and rules
-- You can run this file again at any time to rebuild everything from zero.

-- cleanup of the earlier version (harmless if these do not exist)
DROP VIEW IF EXISTS v_monthly_expenses, v_club_summary, v_event_summary;
DROP FUNCTION IF EXISTS check_event_rules() CASCADE;
DROP FUNCTION IF EXISTS check_registration() CASCADE;
DROP FUNCTION IF EXISTS seats_left(INT);

DROP TABLE IF EXISTS event_expenses, registrations, club_members, events, venues, clubs, students CASCADE;

CREATE TABLE students (
    student_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    email       VARCHAR(150) NOT NULL UNIQUE,
    phone       VARCHAR(20),
    department  VARCHAR(50)  NOT NULL,
    year        SMALLINT     NOT NULL CHECK (year BETWEEN 1 AND 4),
    cgpa        NUMERIC(3,2) CHECK (cgpa BETWEEN 0 AND 4)
);

CREATE TABLE clubs (
    club_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            VARCHAR(100) NOT NULL UNIQUE,
    description     TEXT,
    email           VARCHAR(150),
    faculty_advisor VARCHAR(100)
);

CREATE TABLE venues (
    venue_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name     VARCHAR(100) NOT NULL UNIQUE,
    location VARCHAR(150) NOT NULL,
    capacity INT NOT NULL CHECK (capacity > 0)
);

CREATE TABLE events (
    event_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title       VARCHAR(150) NOT NULL,
    description TEXT,
    start_date  TIMESTAMP NOT NULL,
    end_date    TIMESTAMP NOT NULL,
    capacity    INT NOT NULL CHECK (capacity > 0),
    status      VARCHAR(20) NOT NULL DEFAULT 'scheduled'
                CHECK (status IN ('scheduled', 'completed', 'cancelled')),
    club_id     INT NOT NULL REFERENCES clubs(club_id)   ON DELETE RESTRICT,
    venue_id    INT NOT NULL REFERENCES venues(venue_id) ON DELETE RESTRICT,
    CONSTRAINT valid_time CHECK (end_date > start_date)
);

CREATE TABLE club_members (
    club_member_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id INT NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
    club_id    INT NOT NULL REFERENCES clubs(club_id)       ON DELETE CASCADE,
    join_date  DATE NOT NULL DEFAULT CURRENT_DATE,
    UNIQUE (student_id, club_id)
);

CREATE TABLE registrations (
    registration_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id        INT NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
    event_id          INT NOT NULL REFERENCES events(event_id)     ON DELETE CASCADE,
    registration_date TIMESTAMP NOT NULL DEFAULT now(),
    status            VARCHAR(20) NOT NULL DEFAULT 'registered'
                      CHECK (status IN ('registered', 'cancelled', 'attended')),
    UNIQUE (student_id, event_id)
);

CREATE TABLE event_expenses (
    expense_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id     INT NOT NULL REFERENCES events(event_id) ON DELETE CASCADE,
    description  VARCHAR(200) NOT NULL,
    amount       NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE
);

-- indexes on foreign keys (faster joins)
CREATE INDEX ix_events_club      ON events (club_id);
CREATE INDEX ix_events_venue     ON events (venue_id);
CREATE INDEX ix_reg_event_status ON registrations (event_id, status);
CREATE INDEX ix_expenses_event   ON event_expenses (event_id);
CREATE INDEX ix_members_club     ON club_members (club_id);