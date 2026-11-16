"""Event and Club Management. Every SQL query lives in sql/app_queries.sql.
Users log in with a username and password. The website then connects to PostgreSQL
AS the matching database role, so the database also enforces permissions."""
import os

import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
from flask import Flask, abort, flash, g, redirect, render_template, request, session, url_for
from markupsafe import escape

load_dotenv()
app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "dev-only-secret")

# PostgreSQL login role -> label shown on the website (created in sql/03_roles.sql)
ROLES = {"admin_user": "Admin", "club_admin_user": "Club Authority", "student_user": "Student"}
# users.role (in the users table) -> PostgreSQL login role
APP_ROLE = {"admin": "admin_user", "club_authority": "club_admin_user", "student": "student_user"}


def load_queries(path):
    """Read 'name -> SQL text' pairs from the .sql file."""
    queries, name, lines = {}, None, []
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("-- name:"):
                if name:
                    queries[name] = "".join(lines).strip()
                name, lines = line.split(":", 1)[1].strip(), []
            elif name:
                lines.append(line)
    if name:
        queries[name] = "".join(lines).strip()
    return queries


Q = load_queries(os.path.join(app.root_path, "sql", "app_queries.sql"))


def connect_as(role):
    return psycopg.connect(
        host=os.getenv("DB_HOST", "localhost"), port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "event_db"), user=role,
        password=os.environ["ROLE_PASSWORD"], row_factory=dict_row)


def db():
    if "db" not in g:
        g.db = connect_as(session["role"])
    return g.db


def admin_run(name, params=None):
    """Used only for login and sign-up (the user has no session yet). Returns (rows, rowcount)."""
    with connect_as("admin_user") as conn:
        with conn.cursor() as cur:
            cur.execute(Q[name], params)
            rows = cur.fetchall() if cur.description else []
            return rows, cur.rowcount


@app.teardown_appcontext
def close_db(error):
    conn = g.pop("db", None)
    if conn is not None:
        conn.close()


def error_text(err):
    d = err.diag
    return " ".join(x for x in (d.message_primary, d.message_detail) if x) or str(err)


@app.errorhandler(psycopg.OperationalError)
def cannot_connect(err):
    return ("<h3>Cannot connect to the database</h3><p>" + str(escape(error_text(err))) +
            "</p><p>Check: PostgreSQL is running, the .env file is correct, "
            "and sql/03_roles.sql was run.</p>"), 500


@app.errorhandler(403)
def not_allowed(err):
    return ("<h3>Not allowed</h3><p>Your role cannot do this.</p>"
            "<p><a href='/'>Back to home</a></p>"), 403


def fetch(name, params=None):
    with db().cursor() as cur:
        cur.execute(Q[name], params)
        return cur.fetchall()


def fetch_safe(name, params=None):
    """Like fetch, but a database error (for example 'permission denied') is shown as a message."""
    try:
        return fetch(name, params)
    except psycopg.Error as err:
        db().rollback()
        flash(error_text(err), "error")
        return []


def execute(name, params=None):
    """Run a write query, commit, and return how many rows it changed."""
    try:
        with db().cursor() as cur:
            cur.execute(Q[name], params)
            count = cur.rowcount
        db().commit()
        return count
    except psycopg.Error:
        db().rollback()
        raise


def F(name, label, type="text", opt=None, req=True, on="both"):
    """A form field. on = 'both', 'new' (only when adding), or 'edit' (only when editing)."""
    return dict(name=name, label=label, type=type, opt=opt, req=req, on=on)


ENT = {
    "students": dict(title="Students", pk="student_id",
        cols=["student_id", "student_roll", "name", "email", "phone", "department", "year", "cgpa"],
        fields=[F("student_roll", "Student roll"), F("name", "Name"), F("email", "Email", "email"),
                F("phone", "Phone", req=False), F("department", "Department"),
                F("year", "Year (1-4)", "number"), F("cgpa", "CGPA", "number", req=False)]),
    "clubs": dict(title="Clubs", pk="club_id",
        cols=["club_id", "name", "faculty_advisor", "member_count", "event_count"],
        fields=[F("name", "Name"), F("description", "Description", req=False),
                F("email", "Email", "email", req=False), F("faculty_advisor", "Faculty advisor", req=False)]),
    "venues": dict(title="Venues", pk="venue_id",
        cols=["venue_id", "name", "location", "capacity"],
        fields=[F("name", "Name"), F("location", "Location"), F("capacity", "Capacity", "number")]),
    "events": dict(title="Events", pk="event_id",
        cols=["event_id", "title", "club", "venue", "start_date", "status", "capacity", "seats_taken", "seats_left"],
        reject="Not saved. The capacity must not be above the venue capacity or below the seats already taken, "
               "and the venue must be free at that time.",
        fields=[F("title", "Title"), F("description", "Description", req=False),
                F("start_date", "Start", "datetime-local"), F("end_date", "End", "datetime-local"),
                F("capacity", "Capacity", "number"),
                F("status", "Status", "select", ["scheduled", "completed", "cancelled"]),
                F("club_id", "Club", "select", "clubs_options"),
                F("venue_id", "Venue", "select", "venues_options")]),
    "club_members": dict(title="Club members", pk="club_member_id",
        cols=["club_member_id", "student", "club", "join_date"],
        fields=[F("student_id", "Student", "select", "students_options"),
                F("club_id", "Club", "select", "clubs_options")]),
    "registrations": dict(title="Registrations", pk="registration_id",
        cols=["registration_id", "student", "event", "registered_on", "status"],
        reject="Not saved. The event is full, or it is not an upcoming scheduled event.",
        fields=[F("student_id", "Student", "select", "students_options", on="new"),
                F("event_id", "Event", "select", "events_options", on="new"),
                F("status", "Status", "select", ["registered", "cancelled", "attended"], on="edit")]),
    "expenses": dict(title="Expenses", pk="expense_id",
        cols=["expense_id", "event", "description", "amount", "expense_date"],
        fields=[F("event_id", "Event", "select", "events_options"), F("description", "Description"),
                F("amount", "Amount", "number"), F("expense_date", "Date", "date")]),
    "users": dict(title="Users", pk="user_id",
        cols=["user_id", "username", "role", "student", "club"],
        fields=[F("username", "Username", on="new"),
                F("password", "Password", "password", on="new"),
                F("role", "Role", "select", ["admin", "club_authority", "student"]),
                F("club_id", "Club (club authority only)", "select", "clubs_options", req=False),
                F("student_id", "Student (student only)", "select", "students_options", req=False)]),
}

REPORTS = [("report_registrations", "Registrations per event"),
           ("report_clubs", "Club activity"),
           ("report_expenses_event", "Expenses per event"),
           ("report_expenses_club", "Expenses per club"),
           ("report_expenses_month", "Expenses per month"),
           ("report_top_students", "Most active students"),
           ("report_departments", "Students per department")]

# ---------------------------------------------------------------- permissions
ALL = {"list", "new", "edit", "delete"}
PERMS = {
    "admin": {key: ALL for key in ENT},
    "club_authority": {"students": {"list"}, "clubs": {"list"}, "venues": {"list"},
                       "events": ALL, "club_members": ALL, "expenses": ALL,
                       "registrations": {"list", "new", "edit"}},
    "student": {"clubs": {"list"}, "venues": {"list"}, "events": {"list"},
                "registrations": {"list", "new", "edit"}},
}
CLUB_REPORTS = {"report_registrations", "report_clubs", "report_expenses_event", "report_expenses_club"}
ACTION = {"listing": "list", "new_form": "new", "edit_form": "edit", "delete": "delete"}


def can(ent, action="list"):
    return action in PERMS.get(session.get("app_role"), {}).get(ent, set())


def my_event_titles():
    """Titles of the events that belong to the logged-in club authority's club."""
    if "my_titles" not in g:
        rows = fetch_safe("events_list", {"q": "%%"})
        g.my_titles = {r["title"] for r in rows if r["club"] == session["club_name"]}
    return g.my_titles


def scope_rows(ent, rows):
    """Club authority sees only their own club's rows on these pages."""
    if session["app_role"] != "club_authority":
        return rows
    if ent in ("events", "club_members"):
        return [r for r in rows if r["club"] == session["club_name"]]
    if ent in ("registrations", "expenses"):
        titles = my_event_titles()
        return [r for r in rows if r["event"] in titles]
    return rows


def owner_of(query, row_id):
    try:
        rows = fetch_safe(query, {"id": int(row_id)})
    except (TypeError, ValueError):
        return None
    return rows[0]["club_id" if query != "registration_owner" else "student_id"] if rows else None


def guard(ent, row_id=None, data=None):
    """Stop a club authority from touching another club's rows, and a student from touching
    another student's registration."""
    role = session["app_role"]
    if role == "club_authority":
        cid = session["club_id"]
        if row_id is not None:
            query = {"events": "event_club", "club_members": "member_club",
                     "expenses": "expense_club"}.get(ent)
            if query and owner_of(query, row_id) != cid:
                abort(403)
        if ent == "expenses" and data and owner_of("event_club", data.get("event_id")) != cid:
            abort(403)
    elif role == "student" and ent == "registrations" and row_id is not None:
        if owner_of("registration_owner", row_id) != session["student_id"]:
            abort(403)


def forced_values(ent):
    """Values the website sets itself, so the user cannot choose them."""
    role = session["app_role"]
    if role == "club_authority" and ent in ("events", "club_members"):
        return {"club_id": session["club_id"]}
    if role == "student" and ent == "registrations":
        return {"student_id": session["student_id"]}
    return {}


@app.context_processor
def inject_globals():
    role = session.get("app_role")
    nav = [(key, e["title"]) for key, e in ENT.items() if can(key, "list")]
    return {"nav": nav, "current_role": ROLES.get(session.get("role")),
            "show_reports": role in ("admin", "club_authority"), "can": can}


@app.before_request
def need_role():
    if request.endpoint in ("login", "signup", "static"):
        return None
    if session.get("role") not in ROLES or not session.get("app_role"):
        return redirect(url_for("login"))
    ent = (request.view_args or {}).get("ent")
    action = ACTION.get(request.endpoint)
    if ent and action and not can(ent, action):
        abort(403)
    if request.endpoint == "reports" and session["app_role"] == "student":
        abort(403)
    return None


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        rows, _ = admin_run("auth_login", {"username": request.form.get("username", "").strip(),
                                           "password": request.form.get("password", "")})
        if rows:
            u = rows[0]
            session.clear()
            session.update(role=APP_ROLE[u["role"]], app_role=u["role"], user_id=u["user_id"],
                           username=u["username"], student_id=u["student_id"], club_id=u["club_id"],
                           club_name=u["club_name"], student_name=u["student_name"])
            return redirect(url_for("index"))
        flash("Wrong username or password.", "error")
    else:
        session.clear()
    return render_template("login.html")


@app.route("/signup", methods=["GET", "POST"])
def signup():
    if request.method == "POST":
        f = {k: request.form.get(k, "").strip() or None
             for k in ("student_roll", "name", "email", "phone", "department", "year")}
        f["password"] = request.form.get("password", "")
        if not all(f[k] for k in ("student_roll", "name", "email", "department", "year")) \
                or len(f["password"]) < 6:
            flash("Fill all required fields. The password needs at least 6 characters.", "error")
        else:
            try:
                _, count = admin_run("signup_student", f)
                if count:
                    flash("Account created. Please log in with your student roll.", "ok")
                    return redirect(url_for("login"))
                flash("This student roll already exists with a different email.", "error")
            except psycopg.Error as err:
                flash(error_text(err), "error")
    return render_template("signup.html")


def entity(ent):
    if ent not in ENT:
        abort(404)
    return ENT[ent]


def fields_for(e, editing):
    return [f for f in e["fields"] if f["on"] in ("both", "edit" if editing else "new")]


def options_for(fields):
    out = {}
    for f in fields:
        if f["type"] == "select":
            if isinstance(f["opt"], str):
                out[f["name"]] = [(r["id"], r["label"]) for r in fetch_safe(f["opt"])]
            else:
                out[f["name"]] = [(x, x) for x in f["opt"]]
    return out


@app.get("/")
def index():
    stats = (fetch_safe("home_stats") or [{}])[0]
    return render_template("index.html", stats=stats, sql=Q["home_stats"])


@app.get("/reports")
def reports():
    club = session["app_role"] == "club_authority"
    data = []
    for name, title in REPORTS:
        if club and name not in CLUB_REPORTS:
            continue
        try:
            rows, error = fetch(name), None
            if club:
                mine = my_event_titles() | {session["club_name"]}
                rows = [r for r in rows if any(v in mine for v in r.values() if isinstance(v, str))]
        except psycopg.Error as err:
            db().rollback()
            rows, error = [], error_text(err)
        data.append((title, rows, Q[name], error))
    return render_template("reports.html", data=data)


@app.get("/<ent>")
def listing(ent):
    e = entity(ent)
    q = request.args.get("q", "")
    if session["app_role"] == "student" and ent == "registrations":
        rows = fetch_safe("registrations_mine", {"q": f"%{q}%", "student_id": session["student_id"]})
        sql = Q["registrations_mine"]
    else:
        rows = scope_rows(ent, fetch_safe(f"{ent}_list", {"q": f"%{q}%"}))
        sql = Q[f"{ent}_list"]
    return render_template("list.html", ent=ent, e=e, rows=rows, q=q, sql=sql)


def handle_form(ent, row_id=None):
    e = entity(ent)
    editing = row_id is not None
    guard(ent, row_id)
    forced = forced_values(ent)
    fields = [f for f in fields_for(e, editing) if f["name"] not in forced]
    values = {}
    if editing:
        found = fetch_safe(f"{ent}_get", {"id": row_id})
        if not found:
            abort(404)
        values = found[0]
    if request.method == "POST":
        data = {f["name"]: request.form.get(f["name"], "").strip() or None for f in fields}
        data.update(forced)
        guard(ent, row_id, data)
        values = data
        try:
            query = f"{ent}_update" if editing else f"{ent}_insert"
            if execute(query, {**data, "id": row_id}):
                flash("Saved.", "ok")
                return redirect(url_for("listing", ent=ent))
            flash(e.get("reject", "Nothing was saved."), "error")
        except psycopg.Error as err:
            flash(error_text(err), "error")
    return render_template("form.html", ent=ent, e=e, fields=fields, values=values,
                           editing=editing, options=options_for(fields))


@app.route("/<ent>/new", methods=["GET", "POST"])
def new_form(ent):
    return handle_form(ent)


@app.route("/<ent>/<int:row_id>/edit", methods=["GET", "POST"])
def edit_form(ent, row_id):
    return handle_form(ent, row_id)


@app.post("/<ent>/<int:row_id>/delete")
def delete(ent, row_id):
    entity(ent)
    guard(ent, row_id)
    try:
        execute(f"{ent}_delete", {"id": row_id})
        flash("Deleted.", "ok")
    except psycopg.Error as err:
        flash(error_text(err), "error")
    return redirect(url_for("listing", ent=ent))


if __name__ == "__main__":
    app.run(debug=True)