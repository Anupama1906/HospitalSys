# MedSync Clinic Appointment and Treatment Management System (CATMS)

A comprehensive full-stack clinic management system for multi-specialty clinics with multiple branches. This system digitizes appointment booking, treatment recording, and billing processes for MedSync clinics in Colombo, Kandy, and Galle.

## 🎯 Project Overview

MedSync CATMS is designed to replace paper records and Excel sheets with an integrated database-driven system that manages:
- **Multi-branch Operations**: Each branch has its own manager and staff
- **Patient Management**: Centralized patient records accessible across branches
- **Appointment Scheduling**: Intelligent booking with doctor availability checking
- **Treatment Recording**: Comprehensive treatment cataloging and patient history
- **Billing & Insurance**: Complete invoicing system with insurance claim support
- **Reporting**: Five comprehensive reports for management decision-making

## 🏗️ System Architecture

```
├── backend/                 # Node.js Express API Server
│   ├── server.js           # Main API with authentication & business logic
│   ├── package.json        # Dependencies
│   └── .env               # Environment configuration
├── frontend/               # Multi-portal user interfaces
│   ├── index.html         # Admin Dashboard
│   ├── reception.html     # Receptionist Portal
│   ├── doctor-portal.html # Doctor Interface
│   ├── branch.html        # Branch Manager Dashboard
│   └── *.js               # Frontend logic
└── database_complete_setup.sql  # Complete database with triggers, procedures & views
```

## ✨ Key Features

### Core Functionality
- ✅ **Multi-branch Management**: Separate branches with dedicated managers
- ✅ **Patient Registration**: Centralized patient records with insurance details
- ✅ **Appointment Scheduling**: Smart booking system with overlap prevention
- ✅ **Emergency Walk-ins**: Quick appointment creation for emergencies
- ✅ **Treatment Recording**: Link treatments to completed appointments
- ✅ **Billing System**: Generate invoices with insurance coverage calculations
- ✅ **Payment Tracking**: Full and partial payment support with status updates
- ✅ **Insurance Claims**: Create and track insurance reimbursement claims
- ✅ **Appointment Rescheduling**: Track history of rescheduled appointments

### Database Features
- ✅ **5 Critical Triggers**: Data integrity and business rule enforcement
- ✅ **6 Stored Procedures**: ACID-compliant operations
- ✅ **2 Functions**: Reusable calculations
- ✅ **5 Reporting Views**: Pre-built queries for all required reports
- ✅ **13 Strategic Indexes**: Optimized query performance

### User Roles & Portals
1. **Admin**: Full system access, user management, comprehensive reports
2. **Receptionist**: Appointment booking, patient registration, billing
3. **Doctor**: View appointments, patient history, treatment recording
4. **Branch Manager**: Branch-specific staff, appointments, and financial reports

## 📋 System Requirements

### Prerequisites
- **Node.js** v16 or higher
- **MySQL** 8.0 or higher
- **Modern web browser** (Chrome, Firefox, Safari, Edge)

### Required Node Packages
```json
{
  "express": "^5.1.0",
  "mysql2": "^3.15.0",
  "bcryptjs": "^3.0.2",
  "jsonwebtoken": "^9.0.2",
  "cors": "^2.8.5",
  "dotenv": "^17.2.3"
}
```

## 🚀 Installation Guide

### Step 1: Clone the Repository
```bash
git clone <repository-url>
cd workspace
```

### Step 2: Database Setup

1. **Create Database**:
```bash
mysql -u root -p
```
```sql
CREATE DATABASE hospital1;
exit;
```

2. **Run Setup Script**:
```bash
mysql -u root -p hospital1 < database_complete_setup.sql
```

3. **Verify Installation**:
```sql
USE hospital1;

-- Check tables
SHOW TABLES;

-- Check triggers
SHOW TRIGGERS;

-- Check stored procedures
SHOW PROCEDURE STATUS WHERE Db = 'hospital1';

-- Check views
SHOW FULL TABLES WHERE Table_type = 'VIEW';
```

### Step 3: Backend Configuration

1. **Navigate to backend directory**:
```bash
cd backend
```

2. **Install dependencies**:
```bash
npm install
```

3. **Configure environment**:
```bash
cp .env.example .env
```

4. **Edit .env file** with your database credentials:
```env
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=hospital1
PORT=3000
JWT_SECRET=your-super-secret-jwt-key-here
```

5. **Start the backend server**:
```bash
node server.js
```

You should see:
```
🚀 Server is running on http://localhost:3000
```

### Step 4: Frontend Setup

1. **Open a new terminal** and navigate to the frontend directory:
```bash
cd frontend
```

2. **Start a simple HTTP server** (choose one):

Using Python:
```bash
# Python 3
python -m http.server 8080

# Python 2
python -m SimpleHTTPServer 8080
```

Using Node.js (http-server):
```bash
npm install -g http-server
http-server -p 8080
```

Using PHP:
```bash
php -S localhost:8080
```

3. **Access the application**:
- Open browser and go to: `http://localhost:8080/login.html`

## 👥 Default Users & Login Credentials

The database setup creates default users for testing:

### Admin Account
- **Username**: `admin`
- **Password**: `admin123`
- **Access**: Full system access

### Receptionist Account
- **Username**: `receptionist`
- **Password**: `receptionist123`
- **Access**: Patient & appointment management

### Doctor Account
- **Username**: `doctor`
- **Password**: `doctor123`
- **Access**: Appointment viewing, patient history

### Branch Manager Account
- **Username**: `manager`
- **Password**: `manager123`
- **Access**: Branch-specific operations

> ⚠️ **Security Note**: Change these default passwords in production!

## 📊 Database Schema Overview

### Core Tables
| Table | Purpose |
|-------|---------|
| `Branch` | Clinic branches (Colombo, Kandy, Galle) |
| `Patient` | Patient records with insurance details |
| `Staff` | All staff members |
| `Doctor` | Doctor-specific information |
| `Specialties` | Medical specialties |
| `Appointment` | Scheduled appointments |
| `Treatment_Catalogue` | Available treatments with categories |
| `Appointment_Treatment` | Treatments performed |
| `Invoice` | Billing records |
| `Payment` | Payment transactions |
| `Insurance_Provider` | Insurance companies |
| `Insurance_Claim` | Claim submissions |

### Critical Triggers
1. **PreventOverlappingAppointments**: Prevents doctor double-booking
2. **PreventOverlappingAppointmentsUpdate**: Checks overlaps on reschedule
3. **UpdateInvoiceDueAmount**: Auto-updates invoice status on payment
4. **ValidateAppointmentCompletion**: Ensures only past appointments marked complete
5. **EnforceCompletedAppointmentForTreatment**: Only completed appointments get treatments

### Stored Procedures
1. **CreateAppointmentWithInvoice()**: Atomic appointment + invoice creation
2. **CreateEmergencyAppointment()**: Quick emergency walk-in registration
3. **ProcessPayment()**: Payment processing with proper locking
4. **RescheduleAppointment()**: Track reschedule history
5. **CompleteAppointment()**: Calculate invoice with insurance coverage
6. **GetPatientOutstandingBalance()**: Calculate total patient dues
7. **GetDoctorRevenue()**: Calculate doctor revenue for date range

## 📈 Five Required Reports

### Report 1: Branch-wise Appointment Summary
Shows daily appointment statistics per branch:
- Total appointments
- Scheduled, Completed, Cancelled counts
- Emergency appointments

**Access**: `GET /api/reports/branch-appointments`

### Report 2: Doctor-wise Revenue
Revenue generated by each doctor:
- Total and completed appointments
- Total revenue
- Average revenue per appointment

**Access**: `GET /api/reports/doctor-revenue`

### Report 3: Outstanding Patient Balances
Patients with unpaid invoices:
- Total outstanding amount
- Number of unpaid invoices
- Due dates and overdue status

**Access**: `GET /api/reports/outstanding-patients`

### Report 4: Treatment Category Summary
Treatments grouped by category:
- Number of treatments
- Total revenue per category
- Average price

**Access**: `GET /api/reports/treatment-categories`

### Report 5: Insurance Coverage Analysis
Insurance vs out-of-pocket comparison:
- Coverage percentages
- Total billing amounts
- Insurance coverage vs patient payment

**Access**: `GET /api/reports/insurance-coverage`

## 🔑 API Endpoints

### Authentication
```
POST /api/login                    # User login
```

### Patients
```
GET    /api/patients               # List all patients
POST   /api/patients               # Create patient
GET    /api/patients/:id           # Get patient details
PUT    /api/patients/:id           # Update patient
DELETE /api/patients/:id           # Delete patient
GET    /api/patients/:id/details   # Full patient profile with history
```

### Appointments
```
GET    /api/appointments           # List all appointments
POST   /api/appointments           # Create appointment
POST   /api/appointments/emergency # Create emergency walk-in
GET    /api/appointments/:id       # Get appointment
PUT    /api/appointments/:id       # Update/Reschedule appointment
DELETE /api/appointments/:id       # Cancel appointment
GET    /api/doctors/:id/availability # Check doctor availability
```

### Treatment Recording
```
GET    /api/treatment-catalogue                      # List all treatments
GET    /api/appointments/:id/treatments              # Get treatments for appointment
POST   /api/appointments/:id/treatments              # Add treatment to appointment
DELETE /api/appointments/:id/treatments/:serviceCode # Remove treatment
```

### Invoicing & Payments
```
GET    /api/invoices              # List all invoices
POST   /api/invoices              # Create invoice
GET    /api/invoices/:id          # Get invoice details
PUT    /api/invoices/:id          # Update invoice
POST   /api/payments              # Record payment
GET    /api/payments/by-invoice/:id # Get payments for invoice
```

### Insurance Claims
```
GET    /api/insurance-claims      # List all claims
POST   /api/insurance-claims      # Create claim
PUT    /api/insurance-claims/:id  # Update claim status
GET    /api/invoices/:id/claims   # Get claims for invoice
```

### Reports
```
GET    /api/reports/branch-appointments    # Report 1
GET    /api/reports/doctor-revenue         # Report 2
GET    /api/reports/outstanding-patients   # Report 3
GET    /api/reports/treatment-categories   # Report 4
GET    /api/reports/insurance-coverage     # Report 5
```

### Branch Management
```
GET    /api/branches              # List branches
POST   /api/branches              # Create branch with manager
GET    /api/branches/:id          # Get branch details
PUT    /api/branches/:id          # Update branch
DELETE /api/branches/:id          # Delete branch
```

### Staff Management
```
GET    /api/staff                 # List all staff
POST   /api/staff                 # Create staff member
GET    /api/doctors               # List all doctors
```

## 🧪 Testing the System

### 1. Test Patient Registration
```bash
curl -X POST http://localhost:3000/api/patients \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "gender": "Male",
    "date_of_birth": "1990-05-15",
    "contact_info": "0771234567",
    "emergency_contact": "0779876543"
  }'
```

### 2. Test Appointment Booking
```bash
curl -X POST http://localhost:3000/api/appointments \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "patient_id": 1,
    "doctor_id": 1,
    "branch_id": 1,
    "schedule_date": "2025-10-25 10:00:00",
    "status": "Scheduled",
    "is_emergency": 0
  }'
```

### 3. Test Reports
```bash
# Get branch appointment summary
curl http://localhost:3000/api/reports/branch-appointments \
  -H "Authorization: Bearer YOUR_TOKEN"

# Get doctor revenue report
curl http://localhost:3000/api/reports/doctor-revenue \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## 🎨 Frontend Features

### Admin Portal (`index.html`)
- Dashboard with statistics and charts
- Patient, doctor, and staff management
- Branch administration
- Complete invoicing and billing
- **Insurance claims management**
- **Comprehensive 5-report system**
- Treatment catalogue management

### Receptionist Portal (`reception.html`)
- Quick appointment booking
- Patient registration
- Invoice generation
- Payment recording
- Schedule viewing

### Doctor Portal (`doctor-portal.html`)
- Today's appointments
- Upcoming schedule
- Patient history
- Treatment recording
- Search functionality

### Branch Manager Portal (`branch.html`)
- Branch-specific statistics
- Staff management
- Appointment overview
- Financial reports
- Outstanding balance tracking

## 🔒 Security Features

- ✅ **JWT Authentication**: Secure token-based auth
- ✅ **Role-Based Access Control**: Four distinct user roles
- ✅ **Password Hashing**: bcrypt for secure storage
- ✅ **SQL Injection Prevention**: Parameterized queries
- ✅ **Authorization Middleware**: Endpoint-level protection
- ✅ **Transaction Safety**: ACID properties via stored procedures

## 🐛 Troubleshooting

### Database Connection Error
```
Error: ER_ACCESS_DENIED_ERROR
```
**Solution**: Check `.env` file credentials match MySQL user/password.

### Port Already in Use
```
Error: listen EADDRINUSE: address already in use :::3000
```
**Solution**: Change PORT in `.env` or kill process using port 3000:
```bash
# Find process
lsof -i :3000

# Kill process
kill -9 <PID>
```

### Login Failed
```
401: Invalid credentials
```
**Solution**: Verify database has default users. Re-run database setup script.

### Triggers Not Working
```
Error: Doctor already has an appointment at this time
```
**Solution**: This is correct! The trigger is preventing overlaps. Choose a different time slot.

## 📝 Project Requirements Checklist

### Database Design ✅
- [x] Multi-branch support with branch managers
- [x] Patient records accessible across branches
- [x] Appointment scheduling with overlap prevention
- [x] Treatment recording and cataloging
- [x] Billing with treatment-based pricing
- [x] Full and partial payment tracking
- [x] Insurance claim support
- [x] Emergency walk-in appointments
- [x] Appointment rescheduling with history

### Technical Implementation ✅
- [x] Primary and foreign keys properly set
- [x] 5 triggers for data integrity
- [x] 6 stored procedures for ACID operations
- [x] 2 functions for calculations
- [x] 13 indexes for performance
- [x] 5 reporting views

### Reports ✅
- [x] Report 1: Branch-wise appointment summary
- [x] Report 2: Doctor-wise revenue
- [x] Report 3: Outstanding patient balances
- [x] Report 4: Treatment categories
- [x] Report 5: Insurance coverage analysis

### User Interface ✅
- [x] Admin dashboard with full access
- [x] Receptionist portal for front-desk
- [x] Doctor portal for clinical staff
- [x] Branch manager portal for operations
- [x] Authentication and authorization
- [x] Responsive design

## 📚 Additional Resources

### Database Documentation
- See `DATABASE_SETUP_README.md` for detailed database guide
- See `IMPLEMENTATION_SUMMARY.md` for technical summary
- See `database_complete_setup.sql` for complete schema

### API Documentation
All endpoints require `Authorization: Bearer <token>` header except `/api/login`.

Response format:
```json
{
  "message": "Success message",
  "data": { ... }
}
```

Error format:
```json
{
  "message": "Error description"
}
```

## 🤝 Contributing

This is an academic project for COMP3222 Database Systems. Contributions should maintain:
- Database normalization principles
- ACID transaction properties
- RESTful API conventions
- Secure authentication practices

## 📄 License

This project is developed for educational purposes as part of COMP3222 coursework.

## 👨‍💻 Authors

Developed for MedSync Multi-Specialty Clinic as part of the Clinic Appointment and Treatment Management System (CATMS) project.

---

## 🎯 Quick Start Summary

```bash
# 1. Setup Database
mysql -u root -p hospital1 < database_complete_setup.sql

# 2. Configure Backend
cd backend
cp .env.example .env
# Edit .env with your credentials
npm install
node server.js

# 3. Start Frontend (new terminal)
cd frontend
python -m http.server 8080

# 4. Access Application
# Open browser: http://localhost:8080/login.html
# Login: admin / admin123
```

---

**System Status**: ✅ Fully Operational | **Version**: 1.0 | **Date**: October 2025
