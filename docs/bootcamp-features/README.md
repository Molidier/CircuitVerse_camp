# Bootcamp Features — Additions to CircuitVerse

This document describes **new features** implemented on top of the original [CircuitVerse](https://circuitverse.org) codebase for the bootcamp/education fork. They extend the groups, assignments, and grading experience for teachers and students.

---

## 1. Progress & Analytics

### Time spent and activity
- **Per project:** Each assignment project tracks **time spent** (e.g. `time_spent_seconds` on `projects`) and **activity timestamps** (e.g. for submission status and last activity).
- **Dashboard / assignment views:** Teachers and students can see time-spent and activity data where project/assignment analytics are shown.

### Student dashboard
- **Student dashboard:** Students have a dedicated **dashboard** (e.g. “My Dashboard”) where they see their groups and, for each assignment, progress status (not started / in progress / submitted / graded), overdue indicator, and actions (Start, Start from template/blank, My Circuit, View submission).
- **Route:** e.g. user dashboard path; accessible from profile/navigation.

### Teacher progress dashboard
- **Assignment show page:** Teachers see a **progress dashboard** on each assignment: chart of student counts by status (not started, in progress, submitted, graded), list of students with projects, late-submission flags, and links to grade or view work.

### Charts and late submission
- **Charts:** Assignment and group dashboards include **progress charts** (e.g. not started / in progress / submitted / graded).
- **Late submission flag:** Submissions after the deadline can be flagged so teachers see which work was late.

### Manual submit
- Students **manually submit** their work when ready (Submit button on the project/simulator); submission is required for teachers to grade. No automatic submission at deadline.

### Where to look
- `Project` model: `time_spent_seconds`, activity timestamps, submission status.
- Assignment show: teacher progress dashboard, charts, student table, grading panel.
- User dashboard: `users/circuitverse/dashboard` (student assignment progress).

---

## 2. Teacher Features

### Duplicate assignment
- Teachers can **duplicate an existing assignment** (including closed ones) to create a copy with a new deadline.
- **UI:** “Duplicate” link on the group page and on the assignment show page (for mentors).
- **Route:** `GET /groups/:group_id/assignments/:id/duplicate` → creates “Copy of &lt;name&gt;” and redirects to edit.

### Starter circuit (template)
- When creating or editing an assignment, teachers can choose a **template (starter circuit)** from their own circuits.
- Students who choose “Start from template” receive a **fork of that circuit** instead of a blank project.
- **Model:** `assignments.template_project_id` (optional `Project`).
- **UI:** “Starter circuit (template)” dropdown in the assignment form (only when the mentor has circuits to pick from).

### Per-assignment comments
- Teachers can add **comments on an assignment** (e.g. instructions, clarifications) visible to everyone who can see the assignment.
- **Model:** `AssignmentComment` (assignment_id, user_id, body).
- **UI:** Comments section on the assignment show page; mentors can create comments.

### Grading rubrics
- Teachers can add a **grading rubric** to an assignment: optional criteria, each with a name and max points.
- When grading, teachers can score each criterion (stored as `rubric_scores` on the grade); the rubric appears on the assignment show page in the grading panel.
- **Model:** `assignments.rubric` (JSON array of `{ "name", "max_points" }`); `grades.rubric_scores` for per-submission scores.
- **UI:** “Grading rubric (optional)” in the assignment form: add/remove criteria, set max points; grading view shows rubric score inputs per criterion.

### Allow resubmit
- Per assignment, teachers can enable **Allow resubmit before deadline**: students can then **unsubmit** their work and edit again until the deadline.
- **Model:** `assignments.allow_resubmit` (boolean).
- **UI:** Checkbox in the assignment form; students see unsubmit option when the assignment allows it and the deadline has not passed.

### Grade export and bulk import
- **Export:** Teachers can export grades for an assignment to CSV (e.g. from assignment show or grades).
- **Import:** Teachers can import grades from a CSV file (e.g. email and grade columns) to bulk-update or create grades for an assignment.
- **UI:** Export and Import actions on the assignment show page (for mentors/TAs).

---

## 3. Student Choice: Start from Template or Blank

When an assignment has a **template** set:
- **Group page and student dashboard** show two options:
  - **Start from template** — same as before: fork the template circuit.
  - **Start from blank** — create a new blank project (no template).
- When the assignment has **no template**, a single **“Start” / “Start Working”** button is shown as in the original behavior.
- **Backend:** `assignments#start` uses `params[:start_from]` (`"template"` or `"blank"`) to decide whether to fork the template or create a blank project.

---

## 4. Multiple Groups for One Assignment

Previously, each assignment belonged to a single group. Now an assignment can be **assigned to multiple groups**.

### Behavior
- **Creation:** Creating an assignment from a group page adds it to that group. After save, the assignment is linked via the join table.
- **Editing:** On the assignment edit form, if the teacher has access to more than one group, an **“Also assign to groups”** section appears with checkboxes. Selecting groups adds or keeps the assignment in those groups; the current group is always included.
- **Visibility:** The assignment appears on each selected group’s page; students in any of those groups can work on the same assignment (same deadline, description, template, etc.).
- **Notifications / mailers:** New-assignment and update emails consider all groups the assignment is in (e.g. list of group names, primary mentors).

### Technical
- **Join table:** `assignment_groups` (assignment_id, group_id) with a unique index.
- **Models:** `Assignment` has `has_many :assignment_groups` and `has_many :groups, through: :assignment_groups`. `Group` has `has_many :assignments, through: :assignment_groups`.
- **Policies and controllers:** Access and listing use `assignment.groups` (and current group context where relevant). Removing an assignment from all groups removes the assignment (orphan cleanup).

---

## 5. TA / Co-Teacher Role

A new role **TA (teaching assistant / co-teacher)** sits between **member** and **mentor**.

### Permissions
- **TAs** can do the same as mentors for **assignments and grading**: create/edit assignments, grade, view submissions, add assignment comments, duplicate assignments, use “Also assign to groups,” etc.
- **TAs** do **not** have **admin** rights: they cannot delete the group, change the primary mentor, or perform other group-level admin actions (those remain primary-mentor/admin only).

### UI
- **Mentors & TAs section:** The group page lists both mentors and TAs in one section, with a **Mentor** or **TA** badge per person.
- **Add TAs:** “+ Add TAs” button and a modal (similar to “Add Mentors”) to invite users as TAs (emails, then create `GroupMember` with `mentor: false`, `ta: true`).
- **Role changes (primary mentor only):**
  - **Members:** “Make TA” and “Make mentor.”
  - **Mentors:** “Make TA” and “Make member.”
  - **TAs:** “Make mentor” and “Make member.”
- **Modals:** Promote to Mentor, Promote to TA, and Demote to Member, each updating `mentor` and `ta` on the `GroupMember`.

### Technical
- **Model:** `group_members.ta` (boolean, default false). Scopes: `mentor`, `ta`, `member` (non-mentor, non-TA), `teacher` (mentor or TA).
- **Policies:** `GroupPolicy#mentor_access?`, `AssignmentPolicy#mentor_access?`, `GradePolicy#mentor?`, and project view access treat TAs like mentors for assignment/grading actions; only primary mentor (and admin) retain full group admin.

---

## Summary Table

| Feature | Summary |
|--------|----------|
| **Progress & analytics** | Time spent and activity timestamps per project; progress charts; late submission flag. |
| **Student dashboard** | Dedicated dashboard: groups, assignment status (not started / in progress / submitted / graded), Start or My Circuit. |
| **Teacher progress dashboard** | On assignment show: chart by status, student list, late flags, grade links. |
| **Manual submit** | Students submit work via Submit button; required for grading. |
| **Duplicate assignment** | One-click copy of an assignment (including closed) with new deadline. |
| **Starter circuit (template)** | Optional template project; students can start from a fork of it. |
| **Per-assignment comments** | Teachers post comments on an assignment for all viewers. |
| **Grading rubrics** | Optional rubric (criteria + max points) on assignment; teachers score each criterion when grading. |
| **Allow resubmit** | Per-assignment option so students can unsubmit and resubmit before the deadline. |
| **Grade export / bulk import** | Export grades to CSV; import grades from CSV for an assignment. |
| **Start from template or blank** | When a template exists, students choose “Start from template” or “Start from blank.” |
| **Multiple groups per assignment** | One assignment can be assigned to many groups; “Also assign to groups” on edit. |
| **TA / co-teacher role** | TA role with mentor-like assignment/grading rights; Add TAs and role badges in UI. |

---

*These features extend the open-source [CircuitVerse](https://circuitverse.org) platform for bootcamp and classroom use.*
