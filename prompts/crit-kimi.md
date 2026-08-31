# Kimi K3 — GM-GAME (Godot 4.3) critical live fails. Terse, line-level.
Context: Distributor (Stage 2) and Claim Jumper (Stage 3) bosses STILL don't
chase live despite many headless "fixes" (lock hysteresis on the Distributor's
climb-lock; a ledge-backoff on the Claim Jumper). E-to-advance dialogue ALSO
cancels on the same press (advance == close bug).
Q1: For a hover boss that reads as "not chasing" live even with lock hysteresis:
the most likely remaining cause is it rides ~250px ABOVE the player and never
descends. Give a concrete "commit a DROP toward the player on lock-release"
design (numbers: drop speed, duration, re-hover trigger) that makes it read as
hunting, without a spawn sweep-kill. + a browser-capture metric proving chase.
Q2: E advances AND cancels: classic Godot cause is one handler calling
is_action_just_pressed("interact") while another (or ui_accept aliasing) also
fires on the same press, or advance and close both bound to the same key with no
"consumed this frame" guard. Give the minimal robust fix (event-driven
_unhandled_input + set_input_as_handled, single owner) as a pattern.
