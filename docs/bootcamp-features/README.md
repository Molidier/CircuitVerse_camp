# Bootcamp Features — Additions to CircuitVerse

This document describes **new features** implemented on top of the original [CircuitVerse](https://circuitverse.org) codebase for the bootcamp/education fork. They extend the groups, assignments, and grading experience for teachers and students.

---

## 1. Progress & Analytics

### Time spent
- **Per project:** Each assignment project tracks **time spent** (e.g. `time_spent_seconds` on `projects`).
- **Dashboard / assignment views:** Teachers and students can see time-spent data where project/assignment analytics are shown.

### Charts and late submission
- **Charts:** Assignment and group dashboards include **progress charts** (e.g. not started / in progress / submitted / graded).
- **Late submission flag:** Submissions after the deadline can be flagged so teachers see which work was late.

### Where to look
- `Project` model: `time_spent_seconds` (and any related activity timestamps).
- Assignment show / dashboard views: charts and tables for student progress and late submissions.

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
| **Progress & analytics** | Time spent per project; progress charts; late submission flag. |
| **Duplicate assignment** | One-click copy of an assignment (including closed) with new deadline. |
| **Starter circuit (template)** | Optional template project; students can start from a fork of it. |
| **Per-assignment comments** | Teachers post comments on an assignment for all viewers. |
| **Start from template or blank** | When a template exists, students choose “Start from template” or “Start from blank.” |
| **Multiple groups per assignment** | One assignment can be assigned to many groups; “Also assign to groups” on edit. |
| **TA / co-teacher role** | TA role with mentor-like assignment/grading rights; Add TAs and role badges in UI. |

---

*These features extend the open-source [CircuitVerse](https://circuitverse.org) platform for bootcamp and classroom use.*
