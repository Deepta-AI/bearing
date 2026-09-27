# Backlog

## Epic E-6: Schedules

Shipped. See the changelog.

## Epic E-7: Team invites

Goal: a workspace grows by inviting people instead of sharing one login.

### US-210 Invite a teammate by email
As a workspace admin, I want to invite a teammate by email so that they
can see and pick up shifts.
- AC-210.1: A sent invite appears in a pending list with the email and the
  date it was sent.
- AC-210.2: Inviting someone who is already a member, or who already has a
  pending invite, tells the admin so instead of sending a second email.

### US-211 Members can invite too
As a member, I want to invite a teammate myself so that I do not have to
wait for an admin.
- AC-211.1: Any member of the workspace can send an invite.

### US-212 Accept an invite
As an invitee, I want to accept from the email link and land in the
workspace that invited me.
- AC-212.1: An invitee with no Crewbook account creates one from the link
  and joins the inviting workspace (not a new workspace of their own).
- AC-212.2: Invite links are valid for 7 days. An expired link says so and
  tells the invitee how to get a new one.

### US-213 Manage pending invites
As a workspace admin, I want to resend or revoke a pending invite so that
typos and stale invites do not linger.
- AC-213.1: Resend sends the same invite again and resets its expiry.
- AC-213.2: Revoke asks for confirmation; a revoked link no longer works.

### US-214 See the cost before adding a seat
As an admin on the Pro plan, I want to see what an invite will cost before
I send it so that billing is never a surprise.
- AC-214.1: The admin sees the per-seat monthly price before the invite is
  sent.
