# 🧪 EV Rental Agent - QA Test Cases

**Version:** 1.0  
**Target System:** EV Rental Agent MVP (Django + DSPy)

---

## 🏗️ Category 1: Onboarding & User Profile
*Objective: Verify the agent correctly collects and saves user data (Full Name, Nickname, License ID).*

### TC-01: Happy Path Onboarding (All Info Provided)
* **Input:** "Hi, I want to register. My name is Somchai Jai Dee, call me 'Chai', and my license ID is BKK-888."
* **Expected Behavior:**
    1. Agent calls `onboard_user` with `full_name="Somchai Jai Dee"`, `nickname="Chai"`, `license_id="BKK-888"`.
    2. Agent responds: "User Somchai Jai Dee (Nickname: Chai) onboarded successfully..."
    3. **Verification:** Check Django Admin -> User Profiles. `full_name`, `nickname`, and `license_id` should be populated.

### TC-02: Partial Onboarding (Missing Fields)
* **Input:** "I want to register. My license is A-123."
* **Expected Behavior:**
    1. Agent detects missing `Full Name` and `Nickname`.
    2. Agent **does NOT** call `onboard_user` yet.
    3. Agent responds: "I need your Full Name and Nickname to complete registration."
* **Follow-up Input:** "Name is Alice Smith, nickname Ali."
* **Expected Behavior:** Agent now calls `onboard_user` with all fields merged from context.

### TC-03: Update Existing Profile
* **Pre-condition:** User is already onboarded (from TC-01).
* **Input:** "Update my phone number to 081-234-5678."
* **Expected Behavior:** Agent calls `onboard_user` again, updating the phone field while keeping the name/license (or re-confirming them).

---

## 🔍 Category 2: Inventory Search
*Objective: Verify the Agent can read the CSV data loaded into the database.*

### TC-04: General Availability
* **Input:** "What cars do you have available?"
* **Expected Behavior:**
    1. Agent calls `search_cars`.
    2. Agent lists at least: Tesla Model 3, BYD Atto 3, ORA Good Cat, BMW iX (from `cars.csv`).
    3. Response includes Prices and Range.

### TC-05: Specific Model Search
* **Input:** "Do you have any Teslas?" or "I want a car with 600km range."
* **Expected Behavior:**
    1. Agent calls `search_cars(query_str="Tesla")` or filters based on reasoning.
    2. Agent responds specifically about the Tesla Model 3 (or BMW iX for the range query).

### TC-06: Negative Search
* **Input:** "Do you have a Ferrari?"
* **Expected Behavior:**
    1. Agent calls `search_cars`.
    2. Agent responds politely that no such car is found in the inventory.

---

## 📝 Category 3: Booking & Hybrid UI
*Objective: Verify the "Draft -> Confirm" workflow and the Widget visibility.*

### TC-07: Create Booking Draft
* **Pre-condition:** User is onboarded.
* **Input:** "I want to book the BYD Atto 3."
* **Expected Behavior:**
    1. Agent calls `create_transaction_draft`.
    2. **UI Verification:** A generic chat bubble appears *AND* the **"Confirm Request" Widget** appears below it.
    3. Widget shows: "Vehicle: BYD Atto 3", "Status: Draft".

### TC-08: Confirm Transaction
* **Pre-condition:** TC-07 is visible.
* **Action:** Click the blue **"Confirm"** button on the widget.
* **Expected Behavior:**
    1. Page reloads (POST to `/confirm/`).
    2. Chat history updates with a system message: "✅ Great! Transaction #... is CONFIRMED."
    3. **DB Verification:** In Admin Panel, `Transaction` status changes from `DRAFT` to `CONFIRMED`.

### TC-09: Contextual Booking (Memory)
* **Input 1:** "Tell me about the ORA Good Cat."
* **Input 2:** "Okay, book that one for me."
* **Expected Behavior:**
    1. Agent remembers "that one" refers to "ORA Good Cat" from chat history.
    2. Agent creates a draft for "ORA Good Cat".

---

## ❌ Category 4: Cancellation & System
*Objective: Verify transaction management.*

### TC-10: Cancel Booking
* **Pre-condition:** A confirmed transaction exists (e.g., ID #1).
* **Input:** "Cancel transaction ID 1."
* **Expected Behavior:**
    1. Agent calls `cancel_transaction(transaction_id=1)`.
    2. Agent responds confirming cancellation.
    3. **DB Verification:** Status updates to `CANCELLED`.

### TC-11: Persistence Check
* **Action:**
    1. Stop the docker container (`docker-compose down`).
    2. Start it again (`docker-compose up`).
    3. Login to Admin.
* **Expected Behavior:** All Users, Cars, and Transactions created in previous tests should still exist (Postgres volume persistence).