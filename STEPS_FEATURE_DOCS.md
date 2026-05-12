# OmniConnect Fitness - Feature: Step Counter (Contador de Passos)

## Table of Contents
1. [Feature Overview](#feature-overview)
2. [Business Rules](#business-rules)
3. [Architecture](#architecture)
4. [API Endpoints](#api-endpoints)
5. [Frontend Components](#frontend-components)
6. [Testing Guide](#testing-guide)
7. [Edge Cases & Troubleshooting](#edge-cases--troubleshooting)

---

## Feature Overview

The Step Counter feature provides comprehensive daily step tracking with advanced gamification elements including:

### Correction 1: All-Time Record (Single Trophy)
- Replaces weekly record tracking with a persistent all-time best
- Single trophy indicator (🏆) shown only on the best single day ever recorded
- Displays best day's step count as "Melhor dia" (Best day)
- Can have multiple trophies only if tied (rare)

### Correction 2: Configurable Daily Goal
- Default daily goal: **1,000 steps** (changed from hardcoded 10,000)
- Configurable per user by student or trainer
- Persisted in backend (`users.daily_step_goal`)
- Personalized progress tracking in UI

### Correction 3: Streak Tracking
- Displays consecutive days meeting the (effective) daily goal
- Shows: "🔥 3 dias seguidos" (3 consecutive days)
- Resets if a day is missed (gap in history)
- Today counts toward streak if goal is already met

### Correction 4: Handicap/Protection System ("Não estou bem hoje")
- 3 protection levels reducing effective daily goal without breaking streak
- **Level 1 (Cansado)**: Goal reduced to 75% (e.g., 750 of 1000)
- **Level 2 (Mal-estar)**: Goal reduced to 50% (e.g., 500 of 1000)
- **Level 3 (Muito mal)**: Goal reduced to 25% (e.g., 250 of 1000)
- Persisted daily per user (`step_logs.handicap_level`)
- Visually distinguished with amber/orange color in charts
- Affects streak calculation but not all-time record

### Correction 5: Calories Burned
- Calculated using MET-based formula: `steps × 0.04 × (weight_kg/70)`
- Fallback weight: 70 kg if not specified
- Displayed on:
  - Student home card: "342 kcal queimadas"
  - Daily step summary: totals for current day
  - Historical list: per-day breakdown
  - Weekly summary: total calories for selected period
  - Trainer view: student's daily and weekly calories

### Enhancement: Filtering System
- **7 dias**: Last 7 days
- **Mês atual**: Current calendar month
- **Último mês**: Previous calendar month
- **Recorde**: All history (filtered to show record day prominently)
- Applied to chart and historical list display

### Enhancement: Trainer Student Handicap Indicators
- Trainer's student list shows active protection level on card
- Badge shows: "😓 N{level} · {label}" (e.g., "😓 N2 · Mal-estar")
- Card border turns amber when handicap is active
- Loaded in parallel during screen initialization

---

## Business Rules

### Streak Calculation Rules
```
Precondição: logs = [histórico de passos do usuário]

streak = 0
today_log = buscar log de hoje

if today_log existe e today_log.steps >= effective_goal(today_log.handicap_level):
  streak = 1  // hoje conta se já bateu a meta
  start = hoje - 1 dia
else:
  start = hoje - 1 dia

// iterar para trás
while (log = buscar(start)):
  if log.steps >= effective_goal(log.handicap_level):
    streak += 1
    start = start - 1 dia
  else:
    break

return streak
```

### Effective Goal Formula
```python
def effective_goal(daily_goal: int, handicap_level: Optional[int]) -> int:
    fractions = {1: 0.75, 2: 0.50, 3: 0.25}
    multiplier = fractions.get(handicap_level, 1.0)
    return int(daily_goal * multiplier)
```

### Calories Burned Formula
```
calorias = steps × 0.04 × (weight_kg / 70)

Exemplo:
  8.000 passos, 75 kg = 8000 × 0.04 × (75/70) ≈ 343 kcal
  
Se peso não definido:
  fallback = 70 kg
  8.000 passos = 8000 × 0.04 ≈ 320 kcal
```

### All-Time Record Rules
- Trophy granted to day(s) with highest step count ever
- Handicap does NOT affect record eligibility—trophy based on raw steps
- Once set, only changes if new day exceeds previous record
- Persisted in `step_logs.is_all_time_record` boolean

### Handicap Persistence Rules
- Selected daily per user with timezone awareness
- Stored in `step_logs.handicap_level` when syncing steps
- Persisted on frontend in SharedPreferences: `steps_handicap_{userId}_{date}`
- Modal shows: "A alteração de meta ficará ativa apenas hoje..." (active today only)
- Resets to "Normal" at midnight local time

---

## Architecture

### Backend Stack
```
Framework: FastAPI + SQLAlchemy (async)
Pattern: Repository → Service → Route → Controller

Layers:
├── routes/steps.py          [HTTP endpoints]
├── controllers/step_controller.py [request validation, response formatting]
├── services/step_service.py [business logic: streak, calories, effective goal]
├── repositories/step_repository.py [database queries]
└── models/step_*.py         [SQLAlchemy ORM models]
```

### Frontend Stack
```
Framework: Flutter + Provider
State Management: Provider (StepProvider)
Persistence: SharedPreferences (local cache), API (backend sync)

Architecture:
├── models/step_models.dart [DTOs: StepLog, StepHistory]
├── services/step_service.dart [API client, parsing]
├── providers/step_provider.dart [state + logic]
└── screens/
    ├── student/steps_screen.dart [student detailed view with filters]
    ├── student/widgets/step_summary_card.dart [home card]
    └── trainer/trainer_student_detail.dart [trainer view]
```

### Data Flow

#### Student Adds Steps (Pedometer Integration)
```
Pedometer Sensor (OS)
    ↓
step_provider.dart (listens to sensor)
    ↓
SharedPreferences (cache: current day baseline & increments)
    ↓
[User optionally sets handicap level]
    ↓
syncToBackend() called
    ↓
POST /api/v1/steps/sync (body: steps, date, handicap_level)
    ↓
Backend: _upsert_day() stores in step_logs
    ↓
GET /api/v1/steps/history returns updated history with:
    - all_time_record, is_all_time_record
    - current_streak, daily_goal
    - calories_burned per log, total_calories_today
    ↓
UI refreshes with new streak, trophy, calories
```

#### Trainer Views Student Steps
```
trainer_students_screen.dart loads
    ↓
Parallel load: getStudents() + getStudentHistory() per student
    ↓
_loadTodayHandicaps() checks step_logs for today + handicap_level
    ↓
_buildStudentCard() renders with amber badge if active handicap
    ↓
On tap: navigate to trainer_student_detail
    ↓
Chart displays: bars colored amber for handicap days
    ↓
Summary cells show: week total, best day (all-time), streak, weekly kcal
```

---

## API Endpoints

### Fetch Step History
```
GET /api/v1/steps/history

Query Parameters:
  - start_date: ISO 8601 date (inclusive)
  - end_date: ISO 8601 date (inclusive, optional = start_date)
  - limit: int (optional, default = 30)
  
Authentication: Bearer token (current user)

Response (200 OK):
{
  "logs": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "date": "2026-05-10",
      "steps": 8543,
      "distance_meters": 6427.25,
      "calories_burned": 342.8,
      "is_all_time_record": true,
      "handicap_level": null,
      "created_at": "2026-05-10T14:32:00Z",
      "updated_at": "2026-05-10T14:32:00Z"
    }
  ],
  "all_time_record": 8543,
  "current_week_total": 52341,
  "current_streak": 3,
  "daily_goal": 1000,
  "total_calories_today": 342.8
}
```

### Sync Steps (Student)
```
POST /api/v1/steps/sync

Request Body:
{
  "steps": 8543,
  "distance_meters": 6427.25,
  "date": "2026-05-10",
  "handicap_level": 2
}

Response (201 Created):
{
  "id": "uuid",
  "user_id": "uuid",
  "date": "2026-05-10",
  "steps": 8543,
  "distance_meters": 6427.25,
  "calories_burned": 342.8,
  "is_all_time_record": false,
  "handicap_level": 2,
  "created_at": "2026-05-10T14:32:00Z",
  "updated_at": "2026-05-10T14:32:00Z"
}
```

### Update Goal (Student)
```
PATCH /api/v1/steps/goal

Request Body:
{
  "daily_step_goal": 2000
}

Response (200 OK):
{
  "daily_step_goal": 2000
}
```

### Update Student Goal (Trainer)
```
PATCH /api/v1/steps/student/{user_id}/goal

Path Parameters:
  - user_id: UUID of student

Request Body:
{
  "daily_step_goal": 1500
}

Validation:
  - current_user.id must be student's trainer
  - daily_step_goal must be 100-100,000

Response (200 OK):
{
  "daily_step_goal": 1500
}

Error Cases:
  401: Not authenticated
  403: User is not student's trainer
  404: Student not found
  422: Invalid daily_step_goal value
```

### Get Student History (Trainer)
```
GET /api/v1/steps/student/{user_id}/history

Same parameters and response as regular history endpoint,
but requires trainer relationship validation.
```

---

## Frontend Components

### StepProvider (`lib/providers/step_provider.dart`)

**State:**
```dart
// Internal
StepHistory? _history
int? _selectedHandicapLevel  // null = Normal, 1-3 = protection level
int _stepsToday              // current day counter
double _distanceTodayKm      // current day distance

// Persisted in SharedPreferences
_userWeight                  // fallback if User.weight is null
```

**Key Methods:**
```dart
// Load history from backend
Future<void> loadHistory({DateTime? startDate, DateTime? endDate})

// Set handicap level for today (persists to SP + syncs to backend)
Future<void> setHandicapLevel(int? level)

// Update daily goal (calls API + updates state)
Future<void> setGoal(int goal)

// Sync current day steps to backend
Future<void> syncToBackend()

// Getters
int get stepsToday
double get distanceTodayKm
double get caloriesToday
int? get selectedHandicapLevel
int get dailyGoal
int get currentStreak
int get allTimeRecord
```

### Student Steps Screen (`lib/screens/student/steps/steps_screen.dart`)

**Features:**
- Stateful widget managing filter selection
- Tab-based filtering: 7 days, current month, last month, record
- Interactive bar chart color-coded (amber = handicap, blue = normal)
- Trophy (🏆) on record day when viewing record filter
- Modal-based handicap selector showing 4 levels with effective goals
- Editable goal with text input dialog
- Streak indicator card: "🔥 3 dias seguidos"
- Historical list with:
  - Steps + calories per day
  - Handicap badges on applicable days
  - Trophy on record day

**Key Methods:**
```dart
_buildFilterHeader()        // 4 chip buttons for filters
_buildChart()               // animated bar chart, filtered by selection
_buildRecordHighlight()     // trophy + record day emphasis
_buildStreakCard()          // "🔥 X dias" card
_showHandicapModal()        // 4-level selector with info banner
_buildHistoryList()         // filtered daily breakdown
_applyFilter()              // logic for date range calculation
```

### Step Summary Card (`lib/screens/student/widgets/step_summary_card.dart`)

**Display:**
- Step count prominent (e.g., "8.543")
- Distance + calories (e.g., "6.43 km · 343 kcal")
- Daily goal with progress bar
- Tappable to navigate to steps_screen

**Responsive:**
- Updates when StepProvider notifies
- Uses Consumer<StepProvider> for state binding

### Trainer Student Detail (`lib/screens/trainer/trainer_student_detail.dart`)

**Steps Tab Summary Section (4 cells):**
1. **Semana**: Total steps this week + % of goal
2. **Melhor dia**: All-time record single day
3. **Sequência**: Current streak
4. **Kcal**: Total calories this week

**Chart:**
- Line chart or bar chart showing history
- Color dots: amber = handicap day, orange = record day
- Scrollable for multi-week view

**History List:**
- Each row: date, steps, handicap indicator (border color change), calories
- Trainer can click "Edit Meta" button
  - Dialog opens with current goal
  - Trainer enters new value
  - API call to `PATCH /steps/student/{id}/goal`
  - Success toast, list refreshes

**TabBar Fix:**
```dart
TabBar(
  controller: _tabController,
  isScrollable: true,
  tabAlignment: TabAlignment.start,  // ← prevents left padding
  tabs: [
    Tab(text: 'Info'),
    Tab(text: 'Steps'),
    Tab(text: 'Treinos'),
    Tab(text: 'Avaliações'),
    Tab(text: 'Histórico'),
  ],
)
```

### Trainer Students List (`lib/screens/trainer/trainer_students_screen.dart`)

**Student Card Enhancements:**
- Loads today's handicap status in parallel using `Future.wait()`
- Shows protection badge only if active: "😓 N{level} · {label}"
- Card border turns amber if handicap active
- Fetched via `StepService.getStudentHistory()` for today only

**Load Logic:**
```dart
Future<void> _loadTodayHandicaps(List<UserResponse> students) async {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  
  final futures = students.map((s) async {
    final history = await stepService.getStudentHistory(
      s.id,
      startDate: start,
      endDate: start,
    );
    final todayLog = history.logs.isNotEmpty ? history.logs.first : null;
    return MapEntry(s.id, todayLog?.handicapLevel);
  });
  
  final results = await Future.wait(futures);
  setState(() {
    for (final entry in results) {
      _studentHandicaps[entry.key] = entry.value;
    }
  });
}
```

---

## Testing Guide

### Unit Tests (Backend)

#### Test: All-Time Record Calculation
```python
# File: tests/services/test_step_service.py

def test_all_time_record_single_day():
    """One day with highest steps gets trophy."""
    logs = [
      StepLog(date=2026-05-10, steps=8000, handicap_level=None),
      StepLog(date=2026-05-09, steps=7000, handicap_level=None),
    ]
    
    result = step_service.get_all_time_record(user_id)
    assert result == 8000
    assert all(log.is_all_time_record == (log.steps == 8000) for log in logs)

def test_all_time_record_tie():
    """Multiple days with same max steps all get trophy."""
    logs = [
      StepLog(date=2026-05-10, steps=8000, handicap_level=None),
      StepLog(date=2026-05-08, steps=8000, handicap_level=None),
      StepLog(date=2026-05-06, steps=7000, handicap_level=None),
    ]
    
    result = step_service.get_all_time_record(user_id)
    assert result == 8000
    assert (logs[0].is_all_time_record and logs[1].is_all_time_record 
            and not logs[2].is_all_time_record)
```

#### Test: Streak Calculation
```python
def test_streak_consecutive_days_meeting_goal():
    """Streak increments for each consecutive day meeting effective goal."""
    daily_goal = 1000
    logs = [
      StepLog(date=today, steps=1200, handicap_level=None),       # today: 1200 >= 1000 ✓
      StepLog(date=yesterday, steps=900, handicap_level=None),    # -1: 900 < 1000 ✗
    ]
    
    streak = step_service._calculate_streak(logs, daily_goal)
    assert streak == 1  # only today counts

def test_streak_with_handicap():
    """Streak counts days meeting effective goal after handicap."""
    daily_goal = 1000
    logs = [
      StepLog(date=yesterday, steps=600, handicap_level=2),  # eff_goal = 500, 600 >= 500 ✓
      StepLog(date=2_days_ago, steps=400, handicap_level=None),  # 400 < 1000 ✗
    ]
    
    streak = step_service._calculate_streak(logs, daily_goal)
    assert streak == 1  # yesterday's handicap day counts

def test_streak_reset_on_gap():
    """Missing day breaks streak."""
    daily_goal = 1000
    logs = [
      StepLog(date=today, steps=1200, handicap_level=None),
      # MISSING: yesterday
      StepLog(date=2_days_ago, steps=1100, handicap_level=None),
    ]
    
    streak = step_service._calculate_streak(logs, daily_goal)
    assert streak == 1  # only today, gap yesterday breaks streak
```

#### Test: Handicap Effective Goal
```python
def test_effective_goal_normal():
    goal = step_service._effective_goal(1000, None)
    assert goal == 1000

def test_effective_goal_level_1():
    goal = step_service._effective_goal(1000, 1)
    assert goal == 750

def test_effective_goal_level_2():
    goal = step_service._effective_goal(1000, 2)
    assert goal == 500

def test_effective_goal_level_3():
    goal = step_service._effective_goal(1000, 3)
    assert goal == 250
```

#### Test: Calorie Calculation
```python
def test_calories_with_weight():
    """Calories calculated with user weight: steps * 0.04 * (weight/70)"""
    calories = step_service._calc_calories(8000, 75)
    expected = 8000 * 0.04 * (75/70)  # ~342.85
    assert abs(calories - expected) < 0.1

def test_calories_fallback_weight():
    """Uses 70 kg fallback if weight not provided."""
    calories = step_service._calc_calories(8000, None)
    expected = 8000 * 0.04  # 320
    assert calories == expected
```

### Integration Tests (Backend)

#### Test: Sync Steps Flow
```python
@pytest.mark.asyncio
async def test_sync_steps_creates_log_and_updates_streak():
    """Complete sync flow: steps → database → history response."""
    user = await create_test_user(weight=70)
    
    # Day 1
    response = await client.post(
        "/api/v1/steps/sync",
        json={"steps": 1200, "distance_meters": 900, "date": "2026-05-08"},
        headers={"Authorization": f"Bearer {user.token}"}
    )
    assert response.status_code == 201
    data = response.json()
    assert data["is_all_time_record"] is True
    
    # Day 2
    response = await client.post(
        "/api/v1/steps/sync",
        json={"steps": 1100, "distance_meters": 825, "date": "2026-05-09"},
        headers={"Authorization": f"Bearer {user.token}"}
    )
    assert response.status_code == 201
    assert data["is_all_time_record"] is False  # 1100 < 1200
    
    # Fetch history
    response = await client.get(
        "/api/v1/steps/history",
        headers={"Authorization": f"Bearer {user.token}"}
    )
    history = response.json()
    assert history["all_time_record"] == 1200
    assert history["current_streak"] == 2
    assert len(history["logs"]) == 2

@pytest.mark.asyncio
async def test_handicap_level_persists_and_affects_streak():
    """Handicap level saved and streak respects effective goal."""
    user = await create_test_user()
    user.daily_step_goal = 1000
    
    # Day 1: Normal, beat goal
    await client.post(
        "/api/v1/steps/sync",
        json={"steps": 1200, "date": "2026-05-08", "handicap_level": None},
        headers={"Authorization": f"Bearer {user.token}"}
    )
    
    # Day 2: Level 2 (50% goal = 500), 600 steps beats it
    response = await client.post(
        "/api/v1/steps/sync",
        json={"steps": 600, "date": "2026-05-09", "handicap_level": 2},
        headers={"Authorization": f"Bearer {user.token}"}
    )
    data = response.json()
    assert data["handicap_level"] == 2
    
    history = await client.get(
        "/api/v1/steps/history",
        headers={"Authorization": f"Bearer {user.token}"}
    ).json()
    assert history["current_streak"] == 2  # both days count
```

#### Test: Trainer Updates Student Goal
```python
@pytest.mark.asyncio
async def test_trainer_updates_student_goal():
    """Trainer can update student's daily step goal."""
    trainer = await create_test_user(role="trainer")
    student = await create_test_user(trainer_id=trainer.id)
    
    response = await client.patch(
        f"/api/v1/steps/student/{student.id}/goal",
        json={"daily_step_goal": 2000},
        headers={"Authorization": f"Bearer {trainer.token}"}
    )
    assert response.status_code == 200
    assert response.json()["daily_step_goal"] == 2000
    
    # Verify in history
    history = await client.get(
        f"/api/v1/steps/student/{student.id}/history",
        headers={"Authorization": f"Bearer {trainer.token}"}
    ).json()
    assert history["daily_goal"] == 2000

@pytest.mark.asyncio
async def test_non_trainer_cannot_update_student_goal():
    """Only assigned trainer can update student goal."""
    user1 = await create_test_user(role="trainer")
    user2 = await create_test_user(role="trainer")
    student = await create_test_user(trainer_id=user1.id)
    
    response = await client.patch(
        f"/api/v1/steps/student/{student.id}/goal",
        json={"daily_step_goal": 2000},
        headers={"Authorization": f"Bearer {user2.token}"}
    )
    assert response.status_code == 403
```

### Manual Testing (QA)

#### Scenario 1: Student Sets Handicap and Maintains Streak

**Steps:**
1. Student opens Steps screen
2. Current streak shows "🔥 2 dias seguidos" (has 2 days of successful steps)
3. Today's date shows current day counter progressing
4. Student feels unwell, taps "Não estou bem hoje" at ~400 steps (goal = 1000)
5. Modal opens showing:
   - "Cansado" (Normal: 1000 steps)
   - "Cansado" (N1: 750 steps)
   - "Mal-estar" (N2: 500 steps) ← highlighted
   - "Muito mal" (N3: 250 steps)
6. Student selects N2 (goal now 500)
7. Modal closes, bar color turns amber, progress bar recalculates to 80% (400/500)
8. After sync (manual or auto), refresh history
9. **Verify:** Streak still shows "🔥 3 dias seguidos", handicap badge appears on today's row

**Expected Result:**
- Streak not broken despite low step count
- Amber handicap indicator visible in chart and list
- Goal persisted to backend

#### Scenario 2: Trainer Views Student Handicap Status on List

**Prerequisites:** Trainer has 5 students, 2 with active handicap today

**Steps:**
1. Trainer opens "Meus Alunos"
2. Card A shows: "👤 João Silva 👥" (no badge)
3. Card B shows: "👤 Ana Santos 😓 N1 · Cansado" with amber border
4. Card C shows: "👤 Pedro Oliveira (no badge)
5. Card D shows: "👤 Maria Costa 😓 N3 · Muito mal" with amber border
6. Card E shows: "👤 Carlos Mendes (no badge)

**Expected Result:**
- Handicap badges load within 2 seconds (parallel API calls)
- Badges show correct level + label
- Amber borders on handicapped cards only
- No handicap badge on normal days

#### Scenario 3: All-Time Record vs Weekly Best

**Setup:** Create 5 test days
- Day 1: 7000 steps 🏆
- Day 2: 6500 steps
- Day 3 (new week): 8000 steps 🏆 (NEW all-time)
- Day 4: 5000 steps
- Day 5: 7500 steps

**Steps (Student):**
1. Open Steps screen
2. View "Mês atual" filter (shows all days)
3. **Verify:** 🏆 only on Day 3 (8000)
4. Scroll to "Recorde" card → shows "Melhor dia: 8.000 passos"

**Steps (Trainer):**
1. Open student detail → Steps tab
2. "Melhor dia" cell shows "8.000 passos"
3. Chart shows 🏆 on Day 3 only
4. **Verify:** No trophy/highlight on Day 1 (old record)

**Expected Result:**
- Only single "Melhor dia" record shown
- Trophy 🏆 appears only on highest day
- All-time record displayed as max single day, not weekly total

#### Scenario 4: Calories Calculation Accuracy

**Setup:** User A (75 kg), User B (unknown weight)

**Steps (User A):**
1. Sync 8000 steps
2. Open card → shows "~343 kcal" (8000 × 0.04 × 75/70 = 342.86)
3. Add to history list per-day breakdown

**Steps (User B):**
1. Weight not set in profile
2. Sync 8000 steps
3. Card shows "~320 kcal" (8000 × 0.04 × 70/70 = 320) ← fallback

**Expected Result:**
- Calorie values match formula within rounding
- Fallback 70kg used when needed
- Displayed consistently across all screens

#### Scenario 5: Filter System Accuracy

**Setup:** 30-day dataset with mixed step counts

**Test Filter: "Mês atual"**
1. Today is May 11, 2026
2. Select "Mês atual" chip
3. Chart displays May 1-11 data only
4. List shows only May dates
5. Stats calculated for visible range

**Test Filter: "Último mês"**
1. Select "Último mês" chip
2. Chart displays April 1-30 data
3. Verify dates are April only

**Test Filter: "7 dias"**
1. Select "7 dias" chip
2. Chart shows today back 6 days (7 total)
3. Dates = May 5-11

**Test Filter: "Recorde"**
1. Select "Recorde" chip
2. Chart highlights trophy day prominently
3. List shows all history but visually distinct
4. "Melhor dia" card displayed

**Expected Result:**
- Each filter shows correct date range
- Stats update per filter
- Chart animates smoothly between filters

#### Scenario 6: Edge Cases

**Case 1: No Data**
1. New user, never synced steps
2. Open Steps screen
3. **Verify:**
   - "Sem dados" or empty state shown
   - Streak shows "🔥 Comece hoje..."
   - Goal progress bar at 0%

**Case 2: Handicap Persists Intra-Day**
1. Set handicap N2 at 2:00 PM
2. Close app, reopen 30 mins later
3. **Verify:** Handicap still active (not reset mid-day)
4. Next day (midnight): Handicap resets to Normal

**Case 3: Sync While Offline**
1. Disable network
2. Steps accumulated locally via pedometer
3. Re-enable network
4. Tap "Sincronizar" or auto-sync triggers
5. **Verify:** Steps synced, offline data merged correctly

**Case 4: Trainer Goal Edit**
1. Trainer opens student detail
2. Edit goal: 1000 → 1500
3. **Verify:**
   - API succeeds (toast "Meta atualizada")
   - Chart bars recalculate (progress % changes if today shown)
   - Student sees new goal on refresh

---

## Edge Cases & Troubleshooting

### Common Issues

#### Issue: Streak Not Incrementing
**Cause:** Student below effective goal OR day recorded without sync
**Check:**
1. Backend: `SELECT * FROM step_logs WHERE user_id=? ORDER BY date DESC LIMIT 5;`
   - Verify consecutive dates exist
   - Verify steps >= effective_goal for each
2. Frontend: `provider.currentStreak` should match backend
3. **Fix:** Ensure stepping on day N-1 persisted to backend before adding day N

#### Issue: Trophy Shows On Multiple Days
**Cause:** Tie in all-time record OR previous weekly record logic not replaced
**Check:**
1. Query: `SELECT MAX(steps) FROM step_logs WHERE user_id=?;`
2. Verify only that max value(s) have `is_all_time_record=true`
3. **Fix:** Run data migration to recalculate all records

#### Issue: Calories Not Displaying
**Cause:** User weight null AND frontend not applying fallback
**Check:**
1. Backend: `SELECT weight FROM users WHERE id=?;`
2. Frontend: `StepLog.caloriesBurned` should be populated
3. **Fix:** Ensure `_calc_calories()` fallback to 70 kg in backend, parsing in frontend

#### Issue: Handicap Not Persisting After App Restart
**Cause:** SharedPreferences key mismatch OR date-based eviction
**Check:**
1. SharedPreferences key: `steps_handicap_{userId}_{dateISO8601}`
2. Verify date format matches: `2026-05-11` (local date, not UTC)
3. **Fix:** Check system clock on device, ensure midnight reset logic

#### Issue: Trainer Cannot Edit Student Goal
**Cause:** Trainer-student relationship not validated OR user permissions
**Check:**
1. Backend: `SELECT trainer_id FROM users WHERE id=?;`
2. Verify `current_user.id == student.trainer_id`
3. **Fix:** Ensure trainer is assigned to student before API call

### Performance Optimization

#### Slow Step History Load
- **Root:** Too many logs fetched; N+1 queries
- **Solution:** Limit query to last 90 days by default, paginate if needed
- **Code:**
  ```sql
  SELECT * FROM step_logs
  WHERE user_id = ? AND date >= NOW() - INTERVAL 90 DAY
  ORDER BY date DESC;
  ```

#### Handicap Loading Blocks UI
- **Root:** Sequential API calls for each student
- **Solution:** Use `Future.wait()` for parallel loading (already implemented)
- **Monitor:** Measure time for 10 students: should be ~1 API call duration, not 10x

#### Chart Rendering Stalls
- **Root:** Too many bars rendered; re-layout thrashing
- **Solution:** Limit visible range to 30 days; virtualize if > 30 days
- **Code:**
  ```dart
  final visibleLogs = _applyFilter().take(30).toList();
  ```

### Debugging Tips

#### Enable Verbose Logging
```dart
// lib/providers/step_provider.dart
print('[StepProvider] setHandicapLevel: $level');
print('[StepProvider] syncToBackend() start, current steps: $_stepsToday');
print('[StepProvider] API response: $response');
```

#### Backend Logging
```python
# app/services/step_service.py
logger.info(f"Calculating streak for user {user_id}, goal {daily_goal}")
logger.debug(f"Effective goal with level {level}: {eff_goal}")
logger.warning(f"Sync request missing handicap_level, using None")
```

#### Verify Data Integrity
```sql
-- Check all-time records
SELECT id, user_id, DATE(date), steps, is_all_time_record
FROM step_logs
WHERE user_id = '...'
ORDER BY date DESC;

-- Verify streak logic manually
SELECT date, steps, handicap_level,
  CASE 
    WHEN handicap_level = 1 THEN steps >= (daily_goal * 0.75)
    WHEN handicap_level = 2 THEN steps >= (daily_goal * 0.50)
    WHEN handicap_level = 3 THEN steps >= (daily_goal * 0.25)
    ELSE steps >= daily_goal
  END AS meets_goal
FROM step_logs
WHERE user_id = '...'
ORDER BY date DESC
LIMIT 7;
```

---

## Summary

This comprehensive step counter feature combines gamification (streak, trophy), accessibility (handicap system), and personalization (configurable goals) into a cohesive daily activity tracking system. The backend handles business logic with strong validation, while the frontend provides intuitive UX across student and trainer contexts.

**Key Strengths:**
- Flexible handicap system doesn't break streaks
- Single, persistent all-time record trophy
- Calories as motivational metric
- Trainer oversight with goal management
- Parallel data loading prevents UI blocking

**Testing Approach:**
- Unit tests for core formulas (streak, calories, effective goal)
- Integration tests for API flows
- Manual QA for edge cases and UI responsiveness
- Performance monitoring for parallel loads

For questions or issues, check edit history in backend service or frontend provider files; most logic is centralized in `step_service.py` and `step_provider.dart`.
