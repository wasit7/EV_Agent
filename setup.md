# ⚡ EV Rental Agent MVP

A minimal, agentic EV rental application powered by **Django** (Backend) and **DSPy** (AI Logic).

## 🚀 1. Initial Setup

Follow these steps to get the project running from scratch.

### Prerequisites

  * Docker & Docker Compose
  * A Google Gemini API Key

### Installation

1.  **Run the Master Installer:**
    This script creates the folder structure and populates all necessary code files.

    ```bash
    chmod +x install.sh
    ./install.sh
    ```

2.  **Configure Environment:**
    Navigate to the project folder and edit the `.env` file to add your API key.

    ```bash
    cd ev_rental_project
    nano .env
    ```

    *Add your key:* `GEMINI_API_KEY=AIzaSy...`

3.  **Build & Run:**

    ```bash
    docker-compose up --build
    ```

    *Wait for the logs to show "Starting server..."*

      * Access the app at: **http://localhost:8000**

## 🛠️ 2. Database Migrations

If you modify `ev_app/models.py` (e.g., adding a new field), you must update the database schema.

**While the container is running:**

1.  **Create Migration File:**
    ```bash
    docker-compose exec web python manage.py makemigrations ev_app
    ```
2.  **Apply Migration:**
    ```bash
    docker-compose exec web python manage.py migrate
    ```

## 🔄 3. Fresh Start (Wipe Data)

If you want to completely reset the database (delete all users, transactions, and history) and start over:

1.  **Stop Containers:**
    ```bash
    docker-compose down
    ```
2.  **Remove Database Volume:**
    ```bash
    docker volume rm ev_rental_project_pg_data
    ```
3.  **Restart:**
    ```bash
    docker-compose up --build
    ```
    *The `entrypoint.sh` script will automatically re-run migrations and reload the initial CSV data.*

## 🔑 4. Setup Admin User

To access the Django Admin panel to view/manage data manually:

1.  **Create Superuser:**

    ```bash
    docker-compose exec web python manage.py createsuperuser
    ```

    *Follow the prompts (Username, Email, Password).*

2.  **Access Admin Panel:**

      * Go to: **http://localhost:8000/admin**
      * Login with the credentials you just created.

## 📊 5. Add/Modify Inventory Data

The car inventory is loaded from a CSV file. To change the available cars:

1.  **Edit the CSV:**
    Open `ev_rental_project/data/cars.csv` on your host machine.

    ```csv
    model_name,range_km,price_per_day,status
    Tesla Model 3,450,2500,AVAILABLE
    ...
    ```

2.  **Reload Data:**
    You don't need to restart Docker. Just run the management command:

    ```bash
    docker-compose exec web python manage.py load_inventory
    ```

    *This command performs an "update or create" operation.*

## 🧪 6. Testing

We have a defined set of manual test cases to verify the Agent's behavior.

**Reference:** Please read [TEST_CASES.md](TEST_CASES.md "Test Scenarios")   for detailed scenarios.

### Quick Test Walkthrough

1.  **Onboarding:**
      * *User:* "Onboard me. Name: John Doe, Nick: JD, License: 12345"
      * *Check:* Agent confirms.
2.  **Booking:**
      * *User:* "Book a Tesla Model 3"
      * *Check:* Widget appears. Click "Confirm".
3.  **Verification:**
      * Check the Admin panel (`/admin`) under **Transactions** to see the confirmed booking.