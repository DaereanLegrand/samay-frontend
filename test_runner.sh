#!/usr/bin/env bash
set -uo pipefail

DB_URL="postgresql://postgres:postgres@127.0.0.1:54382/postgres"
RESULTS_FILE="test_results_$(date +%Y%m%d_%H%M%S).md"
TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

gum style \
  --border double \
  --padding "1 2" \
  --margin "1" \
  "Samay — End-User Test Runner (Phase 00-04)"

# ── Wipe user data ──────────────────────────────────────────
if gum confirm "Delete ALL user data from local Supabase DB?"; then
  psql "$DB_URL" <<'EOSQL'
  BEGIN;
  DELETE FROM group_rank_snapshots;
  DELETE FROM event_photo_likes;
  DELETE FROM event_photos;
  DELETE FROM event_attendances;
  DELETE FROM event_invites;
  DELETE FROM event_hosts;
  DELETE FROM minigame_sessions;
  DELETE FROM feature_requests;
  DELETE FROM reports;
  DELETE FROM subscription_overrides;
  DELETE FROM notifications;
  DELETE FROM preshard_ledger;
  DELETE FROM shard_ledger;
  DELETE FROM user_cosmetics;
  DELETE FROM messages;
  DELETE FROM chat_participants;
  DELETE FROM group_shard_contributions;
  DELETE FROM group_members;
  DELETE FROM friendships;
  DELETE FROM chats;
  DELETE FROM events;
  DELETE FROM groups;
  DELETE FROM users;
  DELETE FROM auth.users;
  COMMIT;
EOSQL
  echo ""
  gum style --foreground 10 "✔ User data wiped."
else
  echo ""
  gum style --foreground 11 "⚠ Skipping wipe. Existing data preserved."
fi

# ── Test plan ───────────────────────────────────────────────
tests=(
  "1.1|Auth: Fresh install → Welcome screen|\"VIVE\" headline + \"Crear cuenta\" / \"Iniciar sesión\""
  "1.2|Auth: Tap \"Crear cuenta\" → enter email|Navigates to OTP screen"
  "1.3|Auth: Enter OTP → tap \"Verificar\"|Navigates to age gate"
  "1.4|Auth: Enter DOB under 18|Block message \"Debes tener 18+\""
  "1.5|Auth: Enter DOB 18+|Navigates to Privacy & Terms"
  "1.6|Auth: Accept both checkboxes → \"Continuar\"|Navigates to profile setup"
  "1.7|Auth: Enter username + display name → \"Guardar\"|Account created. Navigates to Feed"
  "1.8|Auth: Kill app and reopen|Stays logged in (no re-login)"
  "1.9|Auth: Sign out → sign in again with same email|Login succeeds, back to Feed"
  "1.10|Auth: Login with wrong password|Error message shown"
  "1.11|Auth: Login screen → \"Crear cuenta\"|Navigates to signup flow"

  "2.1|Profile: Main tab \"Perfil\"|Shows email, display name, username"
  "2.2|Profile: Tap \"Editar\"|Edit profile screen with fields"
  "2.3|Profile: Edit display name → \"Guardar\"|Returns to profile"
  "2.4|Profile: Settings → \"Eliminar cuenta\"|Info text + email input"
  "2.5|Profile: Enter email → \"Eliminar\" → confirm|Account soft-deleted, signed out"
  "2.6|Profile: Re-login into deleted account|Login blocked"

  "3.1|Friends: Search → type username|Debounced results appear"
  "3.2|Friends: Found user → tap \"Agregar\"|Button changes to \"Solicitado\""
  "3.3|Friends: Other device → Requests → \"Recibidas\" tab|Pending request appears"
  "3.4|Friends: Tap \"Aceptar\"|Request accepted. Both become friends"
  "3.5|Friends: Both devices open Friend List|Each sees the other"
  "3.6|Friends: Search within friend list|Filters by typed text"
  "3.7|Friends: Tap friend → public profile|Navigates to their profile"
  "3.8|Friends: From public profile → tap back|Returns to friend list"
  "3.9|Friends: Tap \"Declinar\" on received request|Request disappears"
  "3.10|Friends: \"Enviadas\" tab → \"Cancelar\"|Request cancelled"
  "3.11|Friends: Block user → Settings → Usuarios bloqueados|User in blocked list"
  "3.12|Friends: Blocked user searches for blocker|Blocked user NOT in results"
  "3.13|Friends: Settings → Usuarios bloqueados → \"Desbloquear\"|User removed from list"

  "4.1|Groups: Tap \"Crear grupo\"|Create group screen with name/description"
  "4.2|Groups: Enter name → \"Crear\"|Group created. Navigate to detail"
  "4.3|Groups: Detail shows cover, name, description|All rendered"
  "4.4|Groups: See size tier badge (MICRO/SMALL/etc)|Badge displayed"
  "4.5|Groups: See rank bracket badge|Badge displayed (e.g. EN LA BÚSQUEDA)"
  "4.6|Groups: See group shard balance|Number displayed"
  "4.7|Groups: Member count|Shows \"1 / 14\" or similar"
  "4.8|Groups: Tap \"Miembros\" tab|Member list with yourself"
  "4.9|Groups: Tap \"Chat\" tab|Group chat (empty initially)"
  "4.10|Groups: Tap \"Eventos\" tab|Events tab (empty — Phase 05)"
  "4.11|Groups: Tap \"Abandonar grupo\"|Confirmation dialog → leaves group"
  "4.12|Groups: Host kicks a member|Member removed from group"

  "5.1|Limits: Frozen group banner on detail|No banner for normal groups"
  "5.2|Limits: Free user → 5th host group|Blocked or upgrade prompt"

  "6.1|Donations: Group detail → \"Donar shards\"|Donation screen with amount input"
  "6.2|Donations: Enter amount → boost info text|\"durante 14 días\" shown"
  "6.3|Donations: Confirm donation|Shards deducted, balance updated"
  "6.4|Donations: Miembros tab → \"Mi contribución\"|Your donation shown"
  "6.5|Donations: Top contribuidores section|Top 5 (or just you if alone)"

  "7.1|Ranks: Navigate to Leaderboard|Screen with tier chips"
  "7.2|Ranks: Tap MICRO chip|Only micro-tier groups shown"
  "7.3|Ranks: Tap SMALL chip|Only small-tier groups"
  "7.4|Ranks: Group in list|Shows position, name, badge, shards, members"
  "7.5|Ranks: Pull-to-refresh|Leaderboard refreshes"
  "7.6|Ranks: Detail badge matches leaderboard|Consistent data"

  "8.1|Plugged: Feed shows GAMES row under the hero|5 game cards + Party Finder card (flag-gated)"
  "8.2|Plugged: Tap a game card with no groups|Snackbar \"No groups yet\" hint"
  "8.3|Plugged: Tap a game card with exactly 1 group|Navigates straight to that group's minigames hub"
  "8.4|Plugged: Tap a game card with several groups|Bottom sheet \"Choose a group\" → picker → hub"
  "8.5|Plugged: Tap Party Finder card on feed|Navigates to /party-finder"
  "8.6|Plugged: Group detail → \"Minijuegos\" button|Navigates to that group's minigames hub"
  "8.7|Plugged: Event detail (live event) → QR attendance button|Navigates to attendee QR screen"
  "8.8|Plugged: Event detail (live event, host) → scanner button|Navigates to QR scanner screen"
  "8.9|Plugged: Event detail (live event) → photo gallery button|Navigates to the event photo gallery"
  "8.10|Plugged: Event detail (ended/cancelled event)|Live-actions row hidden"
  "8.11|Plugged: Photo gallery → collage wall button|Navigates to the auto-collage wall"
  "8.12|Plugged: Public profile of a friend → \"Enviar mensaje\"|Creates/opens the E2EE direct chat"
  "8.13|Plugged: Public profile of a blocked user|No \"Enviar mensaje\" button"
)

# ── Results file header ─────────────────────────────────────
cat > "$RESULTS_FILE" <<'EOF'
# Samay Test Results

| # | Test | Result | Notes |
|---|------|--------|-------|
EOF

# ── Run tests ───────────────────────────────────────────────
i=0
while [ "$i" -lt "${#tests[@]}" ]; do
  TOTAL=$((TOTAL + 1))
  IFS='|' read -r id desc expected <<< "${tests[$i]}"

  clear
  gum style \
    --border normal \
    --padding "1 2" \
    --margin "0 0 1 0" \
    "Test $id  ($((i+1))/${#tests[@]})" \
    "" \
    "$desc" \
    "" \
    "Expected: $(gum style --foreground 8 "$expected")"

  result=$(gum choose --header "Result:" "GOOD" "BAD" "PASS" "BACK" "QUIT")
  echo ""

  case "$result" in
    GOOD)
      PASSED=$((PASSED + 1))
      echo "| $id | $desc | GOOD | |" >> "$RESULTS_FILE"
      i=$((i + 1))
      ;;
    BAD)
      FAILED=$((FAILED + 1))
      note=$(gum input \
        --placeholder "Paste (Ctrl+V) the bug details, error, or what happened..."
      )
      note_escaped="${note//|/\\|}"
      echo "| $id | $desc | BAD | $note_escaped |" >> "$RESULTS_FILE"
      i=$((i + 1))
      ;;
    PASS)
      SKIPPED=$((SKIPPED + 1))
      TOTAL=$((TOTAL - 1))
      echo "| $id | $desc | PASS | |" >> "$RESULTS_FILE"
      i=$((i + 1))
      ;;
    BACK)
      TOTAL=$((TOTAL - 1))
      if [ "$i" -gt 0 ]; then
        i=$((i - 1))
        sed -i '$d' "$RESULTS_FILE"
        # Re-count from results file for accurate counters
        PASSED=$(grep -c "| GOOD |" "$RESULTS_FILE" 2>/dev/null || echo 0)
        FAILED=$(grep -c "| BAD |" "$RESULTS_FILE" 2>/dev/null || echo 0)
        SKIPPED=$(grep -c "| PASS |" "$RESULTS_FILE" 2>/dev/null || echo 0)
      fi
      ;;
    QUIT)
      TOTAL=$((TOTAL - 1))
      break
      ;;
  esac
done

clear

# ── Summary ──────────────────────────────────────────────────
gum style \
  --border double \
  --padding "1 2" \
  --margin "1" \
  "Done!" \
  "" \
  "Total:  $TOTAL" \
  "Passed: $(gum style --foreground 10 "$PASSED")" \
  "Failed: $(gum style --foreground 9 "$FAILED")" \
  "Skipped: $(gum style --foreground 11 "$SKIPPED")"

echo ""
gum style --foreground 12 "Results saved to: $RESULTS_FILE"
echo ""
echo "  File: $RESULTS_FILE"
echo "  Path: $(pwd)/$RESULTS_FILE"
