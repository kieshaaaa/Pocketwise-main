# 💰 PocketWise – Personal Finance Tracker

A full-stack personal finance tracker built with **Node.js**, **MySQL**, and vanilla **HTML/CSS/JS**.

---

## 🗂️ Project Structure

```
pocketwise/
├── backend/        → Node.js + Express REST API
├── frontend/       → Plain HTML/CSS/JS (no framework)
└── database/       → SQL schema and seed data
```

---

## ⚙️ Prerequisites

Make sure you have these installed:

- [Node.js](https://nodejs.org/) (v18 or higher)
- [MySQL](https://dev.mysql.com/downloads/) (v8.0 or higher)
- A MySQL client (CLI or Workbench)

---

## 🚀 Setup Instructions

### Step 1 — Clone the repository

```bash
git clone <your-repo-url>
cd pocketwise
```

### Step 2 — Set up the database

Open MySQL CLI and run the schema files in order:

```bash
mysql -u root -p < database/schema.sql
```

Then run the advanced SQL (triggers, procedures, cursors, functions):

```bash
mysql -u root -p pocketwise < database/pocketwise_advanced.sql
```

Or using MySQL CLI SOURCE command:
```sql
USE pocketwise;
SOURCE /path/to/database/schema.sql;
SOURCE /path/to/database/pocketwise_advanced.sql;
```

### Step 3 — Configure the backend

Copy the example env file and fill in your values:

```bash
cd backend
cp .env.example .env
```

Edit `.env`:
```
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=pocketwise
JWT_SECRET=your_secret_key_here
JWT_EXPIRES_IN=30d
PORT=5000
```

### Step 4 — Install backend dependencies

```bash
cd backend
npm install
```

### Step 5 — Start the backend server

```bash
node server.js
```

You should see:
```
Server running on port 5000
Connected to MySQL
```

### Step 6 — Open the frontend

Open `frontend/index.html` directly in your browser, **or** use VS Code Live Server (right-click `index.html` → Open with Live Server).

The app will be available at:
```
http://127.0.0.1:5500/frontend/index.html
```

---

## 🗄️ Database Features

This project uses advanced MySQL/PL-SQL features:

| Type | Name | Description |
|------|------|-------------|
| Trigger | `trg_after_transaction_insert` | Auto-updates budget `spent` on new transaction |
| Trigger | `trg_after_transaction_delete` | Reverses budget `spent` when transaction deleted |
| Trigger | `trg_before_user_delete` | Logs deleted users to audit table |
| Procedure | `get_monthly_summary` | Returns income/expense/balance for a month |
| Procedure | `get_category_breakdown` | Category-wise spending with cursor loop |
| Cursor | Inside `get_category_breakdown` | Loops through each category to compute totals |
| Function | `get_user_balance` | Returns all-time balance for a user |
| Function | `get_category_total_spent` | Returns total spent in a category for a month |

---

## 🔌 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login |
| GET | `/api/transactions` | Get transactions (filterable) |
| POST | `/api/transactions` | Add transaction |
| GET | `/api/transactions/summary` | Monthly income/expense summary |
| GET | `/api/transactions/breakdown` | Category-wise breakdown |
| GET | `/api/budgets` | Get budgets |
| POST | `/api/budgets` | Set budget |
| GET | `/api/savings` | Get savings goals |

---

## 🧪 Verify Database Setup

After running the SQL files, verify in MySQL:

```sql
SHOW TRIGGERS IN pocketwise;
SHOW PROCEDURE STATUS WHERE Db = 'pocketwise';
SHOW FUNCTION STATUS WHERE Db = 'pocketwise';
```

---

## 📝 Notes

- The `.env` file is **not committed** to git — each developer must create their own from `.env.example`
- The `node_modules/` folder is also excluded — run `npm install` after cloning
- JWT tokens expire after **30 days** by default (configurable in `.env`)