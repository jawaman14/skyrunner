# Phone Operations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax.

**Goal:** Make the phone usable during flight and expose the existing market, buyers' orders and heat information.
**Architecture:** Extend PhoneMenu's existing Work and Empire lists. PilotApp owns a temporary autopilot hold through existing Session.command calls; an already engaged route continues untouched.
**Tech Stack:** Godot 4.7.2, GDScript, UIStyle, GameMenu, DataTable; no new dependencies.
**Spec:** docs/DECISIONS.md D-27, D-49, D-59/D-60, D-62; docs/ROADMAP.md Heat and money-loop sections.

## Global Constraints
- Preserve the nine home apps and their number keys.
- Read Orders.view and Investigation.view; never call random lookout-warning rolls from UI.
- Price factors are percentages of the usual price, not dollar quotes.
- The phone must not expose an unwarned raid countdown.
- Ground services remain restricted while airborne.
- Keep simulation, save format, RNG and flight control law unchanged.
- Full business/staff desk work waits for L-1/F-5 as EMPIRE_PIVOT specifies.

## Review Focus
- AP off: phone hold is temporary and restores manual flight.
- AP routed: phone does not reset progress or resurrect a completed route.
- Disabled systems and no orders: show useful empty states.
- Deadline expiry: show zero remaining rather than negative time.
- Repeated refresh: preserve row identity and do not mutate simulation state.

## Task 1: Phone operations
**Files:** scripts/ui/phone_menu.gd, scripts/game/pilot_app.gd, tests/test_walker.gd, docs/GUIDE.md, HANDOFF.md.
**Consumes:** Orders.view(), Investigation.view(stash_net, now, warned), Session.command(PILOT, "autopilot", {on: bool}).
**Produces:** Work subpages market/orders, Empire subpage heat, PilotApp._sync_phone_hold().
- [x] Extend test_the_phone_apps with page contents, countdown privacy, read-only refresh, airborne lifetime and AP ownership checks.
- [x] Verify the existing build fails these new expectations.
- [x] Implement pages and stable selection in the existing handset layout.
- [x] Permit the phone in flight; engage hold only on entry when AP was off, release only the hold this UI started.
- [x] Document the paths and record decision progress.
- [ ] Verify final CI, visual captures and fresh review, then integrate under D-52.

## Execution notes
- Native worktree creation failed because task cwd is not a Git repository; manual linked-worktree writes were denied. Use a separate remote branch and CI, preserving the dirty canonical checkout.
- Initial checkpoint contains tests only so CI can demonstrate the unmet behavior before implementation.

- RED evidence: CI job 117954655516 on 4d573571, Work layout and job waypoint assertions fail (452 passed, 1 failed); old row index then produces a null waypoint cast. Implementation checkpoint follows; final CI remains required.
