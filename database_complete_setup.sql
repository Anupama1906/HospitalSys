-- ============================================================
-- HOSPITAL MANAGEMENT SYSTEM - COMPLETE DATABASE SETUP
-- Clinic Appointment and Treatment Management System (CATMS)
-- MedSync Multi-Specialty Clinic
-- 
-- This script provides a complete database setup with:
-- - Schema enhancements (treatment categories, consultation notes)
-- - Performance indexes for efficient querying
-- - Critical triggers for data integrity
-- - Stored procedures for ACID-compliant operations
-- - Reporting views for all required reports
-- - Comprehensive dummy data for testing
-- ============================================================

USE hospital1;

SET FOREIGN_KEY_CHECKS=0;
SET SQL_MODE='NO_AUTO_VALUE_ON_ZERO';

-- ============================================================
-- SECTION 1: SCHEMA ENHANCEMENTS
-- ============================================================

-- 1.1 Add category column to treatment_catalogue (for Report 4)
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'hospital1'
  AND TABLE_NAME = 'Treatment_Catalogue'
  AND COLUMN_NAME = 'category';

SET @query = IF(@col_exists = 0,
    'ALTER TABLE Treatment_Catalogue ADD COLUMN category VARCHAR(50) AFTER description',
    'SELECT "Category column already exists" AS message');
PREPARE stmt FROM @query;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 1.2 Add consultation_notes to appointment table
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'hospital1'
  AND TABLE_NAME = 'Appointment'
  AND COLUMN_NAME = 'consultation_notes';

SET @query = IF(@col_exists = 0,
    'ALTER TABLE Appointment ADD COLUMN consultation_notes TEXT AFTER status',
    'SELECT "Consultation notes column already exists" AS message');
PREPARE stmt FROM @query;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 1.3 Add coverage_percentage to insurance_provider for dynamic coverage
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'hospital1'
  AND TABLE_NAME = 'Insurance_Provider'
  AND COLUMN_NAME = 'coverage_percentage';

SET @query = IF(@col_exists = 0,
    'ALTER TABLE Insurance_Provider ADD COLUMN coverage_percentage DECIMAL(5,2) DEFAULT 70.00 AFTER name',
    'SELECT "Coverage percentage column already exists" AS message');
PREPARE stmt FROM @query;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 1.4 Update existing treatment categories
UPDATE Treatment_Catalogue
SET category = CASE
  WHEN service_code LIKE 'CON%' THEN 'Consultation'
  WHEN service_code LIKE 'LAB%' THEN 'Laboratory'
  WHEN service_code LIKE 'XRAY%' THEN 'Imaging'
  WHEN service_code LIKE 'ECG%' THEN 'Cardiology'
  WHEN service_code LIKE 'DERM%' THEN 'Dermatology'
  WHEN service_code LIKE 'INJ%' THEN 'Treatment'
  ELSE 'General'
END
WHERE category IS NULL OR category = '';

-- 1.5 Add more treatments with categories for testing
INSERT INTO Treatment_Catalogue (service_code, name, description, price, category) VALUES
('CON-002', 'Specialist Consultation', 'Consultation with specialist doctor', 150.00, 'Consultation'),
('CON-003', 'Follow-up Consultation', 'Follow-up visit within 30 days', 60.00, 'Consultation'),
('LAB-002', 'Complete Blood Count', 'Full blood cell analysis', 180.00, 'Laboratory'),
('LAB-003', 'Urine Analysis', 'Complete urinalysis test', 100.00, 'Laboratory'),
('LAB-004', 'Lipid Profile', 'Cholesterol and triglycerides test', 220.00, 'Laboratory'),
('XRAY-002', 'Abdominal X-Ray', 'Abdominal region imaging', 150.00, 'Imaging'),
('XRAY-003', 'Chest X-Ray', 'Thoracic imaging', 120.00, 'Imaging'),
('ECG-001', 'Electrocardiogram', 'Heart rhythm and electrical activity test', 200.00, 'Cardiology'),
('ECG-002', 'Stress ECG', 'Exercise stress test with ECG monitoring', 350.00, 'Cardiology'),
('INJ-001', 'IV Injection', 'Intravenous medication administration', 50.00, 'Treatment'),
('INJ-002', 'IM Injection', 'Intramuscular medication administration', 40.00, 'Treatment'),
('DERM-002', 'Skin Biopsy', 'Tissue sample collection and analysis', 350.00, 'Dermatology'),
('DERM-003', 'Allergy Testing', 'Comprehensive allergy skin test', 280.00, 'Dermatology')
ON DUPLICATE KEY UPDATE 
    category = VALUES(category),
    price = VALUES(price);

-- ============================================================
-- SECTION 2: PERFORMANCE INDEXES
-- ============================================================

-- 2.1 Appointment indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_appointment_date ON Appointment(schedule_date);
CREATE INDEX IF NOT EXISTS idx_appointment_doctor_date ON Appointment(doctor_id, schedule_date);
CREATE INDEX IF NOT EXISTS idx_appointment_branch_date ON Appointment(branch_id, schedule_date);
CREATE INDEX IF NOT EXISTS idx_appointment_status ON Appointment(status);
CREATE INDEX IF NOT EXISTS idx_appointment_patient ON Appointment(patient_id);

-- 2.2 Invoice and payment indexes
CREATE INDEX IF NOT EXISTS idx_invoice_status ON Invoice(status);
CREATE INDEX IF NOT EXISTS idx_invoice_date ON Invoice(issued_date);
CREATE INDEX IF NOT EXISTS idx_invoice_appointment ON Invoice(appointment_id);
CREATE INDEX IF NOT EXISTS idx_payment_date ON Payment(payment_date);
CREATE INDEX IF NOT EXISTS idx_payment_invoice ON Payment(invoice_id);

-- 2.3 Staff and doctor indexes
CREATE INDEX IF NOT EXISTS idx_staff_branch ON Staff(branch_id);
CREATE INDEX IF NOT EXISTS idx_staff_user ON Staff(user_id);
CREATE INDEX IF NOT EXISTS idx_doctor_staff ON Doctor(staff_id);

-- 2.4 Treatment indexes
CREATE INDEX IF NOT EXISTS idx_treatment_category ON Treatment_Catalogue(category);
CREATE INDEX IF NOT EXISTS idx_appointment_treatment_appt ON Appointment_Treatment(appointment_id);

-- 2.5 Patient indexes
CREATE INDEX IF NOT EXISTS idx_patient_insurance ON Patient(insurance_provider_id);

-- ============================================================
-- SECTION 3: CRITICAL TRIGGERS FOR DATA INTEGRITY
-- ============================================================

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS PreventOverlappingAppointments;
DROP TRIGGER IF EXISTS PreventOverlappingAppointmentsUpdate;
DROP TRIGGER IF EXISTS UpdateInvoiceDueAmount;
DROP TRIGGER IF EXISTS ValidateAppointmentCompletion;
DROP TRIGGER IF EXISTS EnforceCompletedAppointmentForTreatment;

DELIMITER $$

-- Trigger 1: Prevent overlapping appointments for same doctor (INSERT)
CREATE TRIGGER PreventOverlappingAppointments
BEFORE INSERT ON Appointment
FOR EACH ROW
BEGIN
  DECLARE overlap_count INT;
  
  -- Check for overlapping appointments (exact datetime match)
  -- Note: Assumes appointments are booked in fixed time slots
  SELECT COUNT(*) INTO overlap_count
  FROM Appointment
  WHERE doctor_id = NEW.doctor_id
    AND status IN ('Scheduled', 'Rescheduled')
    AND schedule_date = NEW.schedule_date;
  
  IF overlap_count > 0 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Doctor already has an appointment at this time slot. Please choose another time.';
  END IF;
END$$

-- Trigger 2: Prevent overlapping appointments on update
CREATE TRIGGER PreventOverlappingAppointmentsUpdate
BEFORE UPDATE ON Appointment
FOR EACH ROW
BEGIN
  DECLARE overlap_count INT;
  
  -- Only check if schedule_date or doctor_id is being changed
  IF NEW.schedule_date != OLD.schedule_date OR NEW.doctor_id != OLD.doctor_id THEN
    SELECT COUNT(*) INTO overlap_count
    FROM Appointment
    WHERE doctor_id = NEW.doctor_id
      AND appointment_id != NEW.appointment_id
      AND status IN ('Scheduled', 'Rescheduled')
      AND schedule_date = NEW.schedule_date;
    
    IF overlap_count > 0 THEN
      SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Doctor already has an appointment at this time slot. Please choose another time.';
    END IF;
  END IF;
END$$

-- Trigger 3: Auto-update invoice due_amount when payment is made
CREATE TRIGGER UpdateInvoiceDueAmount
AFTER INSERT ON Payment
FOR EACH ROW
BEGIN
  DECLARE v_current_due DECIMAL(10,2);
  DECLARE v_new_status VARCHAR(20);
  
  -- Get current due amount
  SELECT due_amount INTO v_current_due
  FROM Invoice
  WHERE invoice_id = NEW.invoice_id;
  
  -- Calculate new due amount
  SET v_current_due = v_current_due - NEW.paid_amount;
  
  -- Determine new status
  IF v_current_due <= 0 THEN
    SET v_new_status = 'Paid';
  ELSEIF v_current_due < (SELECT out_of_pocket_amount FROM Invoice WHERE invoice_id = NEW.invoice_id) THEN
    SET v_new_status = 'Partially Paid';
  ELSE
    SET v_new_status = 'Pending';
  END IF;
  
  -- Update invoice
  UPDATE Invoice
  SET due_amount = v_current_due,
      status = v_new_status
  WHERE invoice_id = NEW.invoice_id;
END$$

-- Trigger 4: Validate appointment completion
CREATE TRIGGER ValidateAppointmentCompletion
BEFORE UPDATE ON Appointment
FOR EACH ROW
BEGIN
  -- Ensure appointment date is not in the future when marking as completed
  IF NEW.status = 'Completed' AND OLD.status != 'Completed' THEN
    IF NEW.schedule_date > NOW() THEN
      SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Cannot complete future appointments. Please wait until the appointment time.';
    END IF;
  END IF;
END$$

-- Trigger 5: Ensure treatments are only added to completed appointments
CREATE TRIGGER EnforceCompletedAppointmentForTreatment
BEFORE INSERT ON Appointment_Treatment
FOR EACH ROW
BEGIN
  DECLARE appt_status VARCHAR(20);
  
  SELECT status INTO appt_status
  FROM Appointment
  WHERE appointment_id = NEW.appointment_id;
  
  IF appt_status != 'Completed' THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Treatments can only be added to completed appointments.';
  END IF;
END$$

DELIMITER ;

-- ============================================================
-- SECTION 4: STORED PROCEDURES FOR ACID-COMPLIANT OPERATIONS
-- ============================================================

-- Drop existing procedures and functions
DROP PROCEDURE IF EXISTS CreateAppointmentWithInvoice;
DROP PROCEDURE IF EXISTS ProcessPayment;
DROP PROCEDURE IF EXISTS RescheduleAppointment;
DROP PROCEDURE IF EXISTS CompleteAppointment;
DROP PROCEDURE IF EXISTS CreateEmergencyAppointment;
DROP FUNCTION IF EXISTS GetPatientOutstandingBalance;
DROP FUNCTION IF EXISTS GetDoctorRevenue;

DELIMITER $$

-- Procedure 1: Create appointment with automatic invoice generation (atomic transaction)
CREATE PROCEDURE CreateAppointmentWithInvoice(
  IN p_patient_id INT,
  IN p_doctor_id INT,
  IN p_branch_id INT,
  IN p_schedule_date DATETIME,
  IN p_is_emergency TINYINT,
  OUT p_appointment_id INT,
  OUT p_invoice_id INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Failed to create appointment. Transaction rolled back.';
  END;
  
  START TRANSACTION;
  
  -- Insert appointment
  INSERT INTO Appointment (patient_id, doctor_id, branch_id, schedule_date, status, is_emergency)
  VALUES (p_patient_id, p_doctor_id, p_branch_id, p_schedule_date, 'Scheduled', p_is_emergency);
  
  SET p_appointment_id = LAST_INSERT_ID();
  
  -- Create placeholder invoice (will be updated when appointment is completed)
  INSERT INTO Invoice (appointment_id, total_amount, insurance_coverage, out_of_pocket_amount,
                      due_amount, status, issued_date, due_date)
  VALUES (p_appointment_id, 0.00, 0.00, 0.00, 0.00, 'Pending', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY));
  
  SET p_invoice_id = LAST_INSERT_ID();
  
  COMMIT;
END$$

-- Procedure 2: Create emergency walk-in appointment (bypasses normal validation)
CREATE PROCEDURE CreateEmergencyAppointment(
  IN p_patient_id INT,
  IN p_doctor_id INT,
  IN p_branch_id INT,
  OUT p_appointment_id INT
)
BEGIN
  DECLARE v_schedule_time DATETIME;
  
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Failed to create emergency appointment.';
  END;
  
  START TRANSACTION;
  
  -- Set schedule time to current time
  SET v_schedule_time = NOW();
  
  -- Insert emergency appointment
  INSERT INTO Appointment (patient_id, doctor_id, branch_id, schedule_date, status, is_emergency)
  VALUES (p_patient_id, p_doctor_id, p_branch_id, v_schedule_time, 'Scheduled', 1);
  
  SET p_appointment_id = LAST_INSERT_ID();
  
  -- Create placeholder invoice
  INSERT INTO Invoice (appointment_id, total_amount, insurance_coverage, out_of_pocket_amount,
                      due_amount, status, issued_date, due_date)
  VALUES (p_appointment_id, 0.00, 0.00, 0.00, 0.00, 'Pending', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 7 DAY));
  
  COMMIT;
END$$

-- Procedure 3: Process payment with proper locking and validation
CREATE PROCEDURE ProcessPayment(
  IN p_invoice_id INT,
  IN p_paid_amount DECIMAL(10,2),
  IN p_payment_method VARCHAR(50)
)
BEGIN
  DECLARE v_due_amount DECIMAL(10,2);
  DECLARE v_invoice_status VARCHAR(20);
  
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment processing failed. Transaction rolled back.';
  END;
  
  START TRANSACTION;
  
  -- Lock the invoice row for update
  SELECT due_amount, status INTO v_due_amount, v_invoice_status
  FROM Invoice
  WHERE invoice_id = p_invoice_id
  FOR UPDATE;
  
  -- Validate payment amount
  IF p_paid_amount <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment amount must be positive.';
  END IF;
  
  IF p_paid_amount > v_due_amount THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment amount exceeds due amount.';
  END IF;
  
  -- Insert payment (trigger will update invoice automatically)
  INSERT INTO Payment (invoice_id, paid_amount, payment_date, method_of_payment, status)
  VALUES (p_invoice_id, p_paid_amount, NOW(), p_payment_method, 'Completed');
  
  COMMIT;
END$$

-- Procedure 4: Reschedule appointment with history tracking
CREATE PROCEDURE RescheduleAppointment(
  IN p_appointment_id INT,
  IN p_new_date DATETIME,
  IN p_staff_id INT,
  IN p_reason TEXT
)
BEGIN
  DECLARE v_old_date DATETIME;
  DECLARE v_reschedule_id INT;
  
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Rescheduling failed. Transaction rolled back.';
  END;
  
  START TRANSACTION;
  
  -- Get old date
  SELECT schedule_date INTO v_old_date
  FROM Appointment
  WHERE appointment_id = p_appointment_id
  FOR UPDATE;
  
  -- Record reschedule history
  INSERT INTO rescheduled_appointments (previous_appointment_id, previous_date, new_date,
                                        rescheduled_by_staff_id, reschedule_reason)
  VALUES (p_appointment_id, v_old_date, p_new_date, p_staff_id, p_reason);
  
  SET v_reschedule_id = LAST_INSERT_ID();
  
  -- Update appointment (trigger will check for overlaps)
  UPDATE Appointment
  SET schedule_date = p_new_date,
      status = 'Rescheduled',
      reschedule_id = v_reschedule_id
  WHERE appointment_id = p_appointment_id;
  
  COMMIT;
END$$

-- Procedure 5: Complete appointment and calculate invoice
CREATE PROCEDURE CompleteAppointment(
  IN p_appointment_id INT
)
BEGIN
  DECLARE v_total_amount DECIMAL(10,2) DEFAULT 0.00;
  DECLARE v_insurance_coverage DECIMAL(10,2) DEFAULT 0.00;
  DECLARE v_coverage_percentage DECIMAL(5,2);
  DECLARE v_patient_insurance_id INT;
  DECLARE v_invoice_id INT;
  
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Failed to complete appointment. Transaction rolled back.';
  END;
  
  START TRANSACTION;
  
  -- Mark appointment as completed (trigger will validate)
  UPDATE Appointment
  SET status = 'Completed'
  WHERE appointment_id = p_appointment_id;
  
  -- Calculate total from treatments
  SELECT COALESCE(SUM(COALESCE(at.actual_price, tc.price)), 0) INTO v_total_amount
  FROM Appointment_Treatment at
  JOIN Treatment_Catalogue tc ON at.service_code = tc.service_code
  WHERE at.appointment_id = p_appointment_id;
  
  -- Get patient insurance and coverage percentage
  SELECT p.insurance_provider_id, COALESCE(ip.coverage_percentage, 0)
  INTO v_patient_insurance_id, v_coverage_percentage
  FROM Appointment a
  JOIN Patient p ON a.patient_id = p.patient_id
  LEFT JOIN Insurance_Provider ip ON p.insurance_provider_id = ip.id
  WHERE a.appointment_id = p_appointment_id;
  
  -- Calculate insurance coverage based on provider's coverage percentage
  IF v_patient_insurance_id IS NOT NULL THEN
    SET v_insurance_coverage = v_total_amount * (v_coverage_percentage / 100);
  END IF;
  
  -- Update invoice
  SELECT invoice_id INTO v_invoice_id
  FROM Invoice
  WHERE appointment_id = p_appointment_id;
  
  UPDATE Invoice
  SET total_amount = v_total_amount,
      insurance_coverage = v_insurance_coverage,
      out_of_pocket_amount = v_total_amount - v_insurance_coverage,
      due_amount = v_total_amount - v_insurance_coverage,
      status = IF(v_total_amount - v_insurance_coverage > 0, 'Unpaid', 'Paid'),
      issued_date = CURDATE()
  WHERE invoice_id = v_invoice_id;
  
  COMMIT;
END$$

-- Function 1: Get patient outstanding balance across all invoices
CREATE FUNCTION GetPatientOutstandingBalance(p_patient_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE v_balance DECIMAL(10,2);
  
  SELECT COALESCE(SUM(i.due_amount), 0) INTO v_balance
  FROM Invoice i
  JOIN Appointment a ON i.appointment_id = a.appointment_id
  WHERE a.patient_id = p_patient_id
    AND i.status IN ('Pending', 'Partially Paid', 'Unpaid')
    AND i.due_amount > 0;
  
  RETURN v_balance;
END$$

-- Function 2: Get doctor revenue for a date range
CREATE FUNCTION GetDoctorRevenue(
  p_doctor_id INT,
  p_start_date DATE,
  p_end_date DATE
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE v_revenue DECIMAL(10,2);
  
  SELECT COALESCE(SUM(i.total_amount), 0) INTO v_revenue
  FROM Invoice i
  JOIN Appointment a ON i.appointment_id = a.appointment_id
  WHERE a.doctor_id = p_doctor_id
    AND a.status = 'Completed'
    AND DATE(a.schedule_date) BETWEEN p_start_date AND p_end_date;
  
  RETURN v_revenue;
END$$

DELIMITER ;

-- ============================================================
-- SECTION 5: REPORTING VIEWS (All 5 Required Reports)
-- ============================================================

-- Drop existing views
DROP VIEW IF EXISTS vw_branch_appointment_summary;
DROP VIEW IF EXISTS vw_doctor_revenue;
DROP VIEW IF EXISTS vw_outstanding_patients;
DROP VIEW IF EXISTS vw_treatment_category_summary;
DROP VIEW IF EXISTS vw_insurance_vs_outofpocket;

-- View 1: Branch-wise appointment summary per day
CREATE VIEW vw_branch_appointment_summary AS
SELECT
  b.branch_id,
  b.name AS branch_name,
  DATE(a.schedule_date) AS appointment_date,
  COUNT(*) AS total_appointments,
  SUM(CASE WHEN a.status = 'Scheduled' THEN 1 ELSE 0 END) AS scheduled_count,
  SUM(CASE WHEN a.status = 'Completed' THEN 1 ELSE 0 END) AS completed_count,
  SUM(CASE WHEN a.status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_count,
  SUM(CASE WHEN a.status = 'Rescheduled' THEN 1 ELSE 0 END) AS rescheduled_count,
  SUM(CASE WHEN a.is_emergency = 1 THEN 1 ELSE 0 END) AS emergency_count
FROM Branch b
LEFT JOIN Appointment a ON b.branch_id = a.branch_id
WHERE a.appointment_id IS NOT NULL
GROUP BY b.branch_id, b.name, DATE(a.schedule_date);

-- View 2: Doctor-wise revenue report
CREATE VIEW vw_doctor_revenue AS
SELECT
  d.doctor_id,
  s.name AS doctor_name,
  b.name AS branch_name,
  sp.name AS specialty_name,
  COUNT(DISTINCT a.appointment_id) AS total_appointments,
  COUNT(DISTINCT CASE WHEN a.status = 'Completed' THEN a.appointment_id END) AS completed_appointments,
  COALESCE(SUM(CASE WHEN a.status = 'Completed' THEN i.total_amount END), 0) AS total_revenue,
  COALESCE(AVG(CASE WHEN a.status = 'Completed' THEN i.total_amount END), 0) AS avg_revenue_per_appointment
FROM Doctor d
JOIN Staff s ON d.staff_id = s.staff_id
LEFT JOIN Branch b ON s.branch_id = b.branch_id
LEFT JOIN doctor_specialties ds ON d.doctor_id = ds.doctor_id
LEFT JOIN Specialties sp ON ds.specialty_id = sp.specialty_id
LEFT JOIN Appointment a ON d.doctor_id = a.doctor_id
LEFT JOIN Invoice i ON a.appointment_id = i.appointment_id
GROUP BY d.doctor_id, s.name, b.name, sp.name;

-- View 3: Patients with outstanding balances
CREATE VIEW vw_outstanding_patients AS
SELECT
  p.patient_id,
  p.name AS patient_name,
  p.contact_info,
  COUNT(DISTINCT i.invoice_id) AS unpaid_invoices,
  SUM(i.due_amount) AS total_outstanding,
  MIN(i.due_date) AS earliest_due_date,
  MAX(i.due_date) AS latest_due_date,
  CASE
    WHEN MIN(i.due_date) < CURDATE() THEN 'Overdue'
    ELSE 'Due'
  END AS payment_status
FROM Patient p
JOIN Appointment a ON p.patient_id = a.patient_id
JOIN Invoice i ON a.appointment_id = i.appointment_id
WHERE i.status IN ('Pending', 'Partially Paid', 'Unpaid') 
  AND i.due_amount > 0
GROUP BY p.patient_id, p.name, p.contact_info;

-- View 4: Treatment category summary (treatments per category)
CREATE VIEW vw_treatment_category_summary AS
SELECT
  tc.category,
  COUNT(DISTINCT at.appointment_id) AS treatment_count,
  COUNT(*) AS total_treatments,
  SUM(COALESCE(at.actual_price, tc.price)) AS total_revenue,
  AVG(COALESCE(at.actual_price, tc.price)) AS avg_price,
  MIN(COALESCE(at.actual_price, tc.price)) AS min_price,
  MAX(COALESCE(at.actual_price, tc.price)) AS max_price
FROM Treatment_Catalogue tc
LEFT JOIN Appointment_Treatment at ON tc.service_code = at.service_code
WHERE tc.category IS NOT NULL
GROUP BY tc.category;

-- View 5: Insurance coverage vs out-of-pocket payments
CREATE VIEW vw_insurance_vs_outofpocket AS
SELECT
  ip.name AS insurance_provider,
  ip.coverage_percentage,
  COUNT(DISTINCT p.patient_id) AS total_patients,
  COUNT(DISTINCT i.invoice_id) AS total_invoices,
  SUM(i.total_amount) AS total_billing,
  SUM(i.insurance_coverage) AS total_insurance_coverage,
  SUM(i.out_of_pocket_amount) AS total_out_of_pocket,
  ROUND(AVG(CASE WHEN i.total_amount > 0 THEN (i.insurance_coverage / i.total_amount * 100) ELSE 0 END), 2) AS avg_coverage_percentage
FROM Insurance_Provider ip
LEFT JOIN Patient p ON ip.id = p.insurance_provider_id
LEFT JOIN Appointment a ON p.patient_id = a.patient_id
LEFT JOIN Invoice i ON a.appointment_id = i.appointment_id
WHERE i.invoice_id IS NOT NULL
GROUP BY ip.id, ip.name, ip.coverage_percentage

UNION ALL

SELECT
  'No Insurance' AS insurance_provider,
  0.00 AS coverage_percentage,
  COUNT(DISTINCT p.patient_id) AS total_patients,
  COUNT(DISTINCT i.invoice_id) AS total_invoices,
  SUM(i.total_amount) AS total_billing,
  0.00 AS total_insurance_coverage,
  SUM(i.out_of_pocket_amount) AS total_out_of_pocket,
  0.00 AS avg_coverage_percentage
FROM Patient p
LEFT JOIN Appointment a ON p.patient_id = a.patient_id
LEFT JOIN Invoice i ON a.appointment_id = i.appointment_id
WHERE p.insurance_provider_id IS NULL 
  AND i.invoice_id IS NOT NULL;

-- ============================================================
-- SECTION 6: POPULATE DUMMY DATA FOR TESTING
-- ============================================================

-- 6.1 Update insurance providers with coverage percentages
UPDATE Insurance_Provider
SET coverage_percentage = CASE
  WHEN name LIKE '%Medicare%' THEN 70.00
  WHEN name LIKE '%Private%' THEN 80.00
  WHEN name LIKE '%Government%' THEN 65.00
  ELSE 70.00
END
WHERE coverage_percentage IS NULL;

-- 6.2 Add more diverse patients
INSERT INTO Patient (name, gender, date_of_birth, contact_info, emergency_contact, insurance_provider_id, policy_number) VALUES
('Saman Silva', 'Male', '1985-05-20', '0771234567', '0777654321', 1, 'ML-2024-001'),
('Nimal Perera', 'Male', '1990-08-15', '0762345678', '0768765432', 2, 'PA-2024-002'),
('Kamala Fernando', 'Female', '1978-03-10', '0753456789', '0759876543', 3, 'GE-2024-003'),
('Ruwan Jayasinghe', 'Male', '1995-11-25', '0744567890', '0740987654', NULL, NULL),
('Sanduni Rajapaksha', 'Female', '2000-07-08', '0735678901', '0731098765', 1, 'ML-2024-004'),
('Malini Wickramasinghe', 'Female', '1982-12-30', '0726789012', '0722109876', NULL, NULL),
('Kasun Dissanayake', 'Male', '1988-09-14', '0717890123', '0713210987', 2, 'PA-2024-005')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- 6.3 Link doctor accounts to doctor table (if not already linked)
INSERT INTO Doctor (staff_id)
SELECT staff_id 
FROM Staff s
JOIN Account_Info ai ON s.user_id = ai.user_id
JOIN Role r ON ai.role_id = r.role_id
WHERE r.name = 'Doctor'
  AND s.staff_id NOT IN (SELECT staff_id FROM Doctor)
LIMIT 5
ON DUPLICATE KEY UPDATE staff_id = VALUES(staff_id);

-- 6.4 Assign specialties to doctors (if not already assigned)
INSERT INTO doctor_specialties (doctor_id, specialty_id)
SELECT d.doctor_id, 
       CASE 
         WHEN d.doctor_id % 3 = 0 THEN 1
         WHEN d.doctor_id % 3 = 1 THEN 2
         ELSE 3
       END
FROM Doctor d
WHERE NOT EXISTS (
  SELECT 1 FROM doctor_specialties ds WHERE ds.doctor_id = d.doctor_id
)
LIMIT 10
ON DUPLICATE KEY UPDATE specialty_id = VALUES(specialty_id);

-- 6.5 Create test appointments (past completed, current scheduled, future)
INSERT INTO Appointment (patient_id, doctor_id, branch_id, schedule_date, status, is_emergency, consultation_notes) VALUES
(1, 1, (SELECT branch_id FROM Branch LIMIT 1), DATE_SUB(NOW(), INTERVAL 10 DAY), 'Completed', 0, 'Patient complained of chest pain. ECG performed. Results normal.'),
(2, 1, (SELECT branch_id FROM Branch LIMIT 1), DATE_SUB(NOW(), INTERVAL 8 DAY), 'Completed', 0, 'Routine checkup. Blood work ordered. Patient advised to return for follow-up.'),
(3, 2, (SELECT branch_id FROM Branch LIMIT 1), DATE_SUB(NOW(), INTERVAL 5 DAY), 'Completed', 0, 'Skin allergy consultation. Prescribed antihistamines.'),
(4, 2, (SELECT branch_id FROM Branch LIMIT 1), DATE_ADD(NOW(), INTERVAL 2 DAY), 'Scheduled', 0, NULL),
(5, 3, (SELECT branch_id FROM Branch LIMIT 1), DATE_ADD(NOW(), INTERVAL 3 DAY), 'Scheduled', 0, NULL),
(6, 1, (SELECT branch_id FROM Branch LIMIT 1), DATE_ADD(NOW(), INTERVAL 5 DAY), 'Scheduled', 1, NULL),
(1, 2, (SELECT branch_id FROM Branch LIMIT 1), DATE_SUB(NOW(), INTERVAL 15 DAY), 'Completed', 0, 'Follow-up from previous visit. Condition improved.'),
(7, 3, (SELECT branch_id FROM Branch LIMIT 1), DATE_SUB(NOW(), INTERVAL 3 DAY), 'Completed', 0, 'Pediatric consultation. Child has fever and cough.'),
(3, 1, (SELECT branch_id FROM Branch LIMIT 1), DATE_SUB(NOW(), INTERVAL 20 DAY), 'Cancelled', 0, NULL)
ON DUPLICATE KEY UPDATE status = VALUES(status);

-- 6.6 Add treatments to completed appointments
INSERT INTO Appointment_Treatment (appointment_id, service_code, notes, actual_price)
SELECT a.appointment_id, 'CON-001', 'General consultation', 80.00
FROM Appointment a
WHERE a.status = 'Completed' AND a.appointment_id NOT IN (SELECT appointment_id FROM Appointment_Treatment)
LIMIT 1
ON DUPLICATE KEY UPDATE actual_price = VALUES(actual_price);

INSERT INTO Appointment_Treatment (appointment_id, service_code, notes, actual_price)
SELECT a.appointment_id, 'ECG-001', 'Heart rhythm check performed', 200.00
FROM Appointment a
WHERE a.status = 'Completed' 
  AND a.consultation_notes LIKE '%ECG%'
  AND NOT EXISTS (SELECT 1 FROM Appointment_Treatment at WHERE at.appointment_id = a.appointment_id AND at.service_code = 'ECG-001')
LIMIT 1
ON DUPLICATE KEY UPDATE actual_price = VALUES(actual_price);

INSERT INTO Appointment_Treatment (appointment_id, service_code, notes, actual_price)
SELECT a.appointment_id, 'LAB-001', 'Blood work ordered', 150.50
FROM Appointment a
WHERE a.status = 'Completed' 
  AND a.consultation_notes LIKE '%Blood work%'
  AND NOT EXISTS (SELECT 1 FROM Appointment_Treatment at WHERE at.appointment_id = a.appointment_id AND at.service_code = 'LAB-001')
LIMIT 1
ON DUPLICATE KEY UPDATE actual_price = VALUES(actual_price);

-- 6.7 Update invoices for completed appointments using the CompleteAppointment procedure
-- Note: This will be handled by the CompleteAppointment stored procedure in real usage
-- For dummy data, we'll manually update some invoices

UPDATE Invoice i
JOIN Appointment a ON i.appointment_id = a.appointment_id
JOIN (
  SELECT
    at.appointment_id,
    SUM(COALESCE(at.actual_price, tc.price)) AS total
  FROM Appointment_Treatment at
  JOIN Treatment_Catalogue tc ON at.service_code = tc.service_code
  GROUP BY at.appointment_id
) treatment_totals ON a.appointment_id = treatment_totals.appointment_id
LEFT JOIN Patient p ON a.patient_id = p.patient_id
LEFT JOIN Insurance_Provider ip ON p.insurance_provider_id = ip.id
SET
  i.total_amount = treatment_totals.total,
  i.insurance_coverage = CASE
    WHEN p.insurance_provider_id IS NOT NULL 
    THEN treatment_totals.total * (COALESCE(ip.coverage_percentage, 70) / 100)
    ELSE 0.00
  END,
  i.out_of_pocket_amount = CASE
    WHEN p.insurance_provider_id IS NOT NULL 
    THEN treatment_totals.total * (1 - COALESCE(ip.coverage_percentage, 70) / 100)
    ELSE treatment_totals.total
  END,
  i.due_amount = CASE
    WHEN p.insurance_provider_id IS NOT NULL 
    THEN treatment_totals.total * (1 - COALESCE(ip.coverage_percentage, 70) / 100)
    ELSE treatment_totals.total
  END,
  i.status = 'Unpaid'
WHERE a.status = 'Completed'
  AND i.total_amount = 0;

-- 6.8 Add some payments to demonstrate partial payment tracking
INSERT INTO Payment (invoice_id, paid_amount, payment_date, method_of_payment, status)
SELECT i.invoice_id, i.out_of_pocket_amount, DATE_ADD(i.issued_date, INTERVAL 1 DAY), 'Cash', 'Completed'
FROM Invoice i
JOIN Appointment a ON i.appointment_id = a.appointment_id
WHERE i.status = 'Unpaid'
  AND a.patient_id IN (1, 2)
  AND NOT EXISTS (SELECT 1 FROM Payment p WHERE p.invoice_id = i.invoice_id)
LIMIT 2
ON DUPLICATE KEY UPDATE status = VALUES(status);

-- 6.9 Add insurance claims for patients with insurance
INSERT INTO Insurance_Claim (invoice_id, insurance_provider_id, claimed_amount, claim_status)
SELECT i.invoice_id, p.insurance_provider_id, i.insurance_coverage, 'Approved'
FROM Invoice i
JOIN Appointment a ON i.appointment_id = a.appointment_id
JOIN Patient p ON a.patient_id = p.patient_id
WHERE p.insurance_provider_id IS NOT NULL
  AND i.insurance_coverage > 0
  AND NOT EXISTS (SELECT 1 FROM Insurance_Claim ic WHERE ic.invoice_id = i.invoice_id)
LIMIT 3
ON DUPLICATE KEY UPDATE claim_status = VALUES(claim_status);

SET FOREIGN_KEY_CHECKS=1;

-- ============================================================
-- SECTION 7: SAMPLE REPORTING QUERIES
-- ============================================================

-- Query 1: Branch-wise appointment summary (Report 1)
SELECT 
  'Report 1: Branch-wise Appointment Summary' AS report_name,
  branch_name,
  appointment_date,
  total_appointments,
  scheduled_count,
  completed_count,
  cancelled_count,
  emergency_count
FROM vw_branch_appointment_summary
WHERE appointment_date >= CURDATE() - INTERVAL 30 DAY
ORDER BY appointment_date DESC, branch_name;

-- Query 2: Doctor-wise revenue (Report 2)
SELECT 
  'Report 2: Doctor-wise Revenue' AS report_name,
  doctor_name,
  branch_name,
  specialty_name,
  total_appointments,
  completed_appointments,
  CONCAT('$', FORMAT(total_revenue, 2)) AS total_revenue,
  CONCAT('$', FORMAT(avg_revenue_per_appointment, 2)) AS avg_revenue_per_appointment
FROM vw_doctor_revenue
WHERE total_appointments > 0
ORDER BY total_revenue DESC;

-- Query 3: Outstanding patients (Report 3)
SELECT 
  'Report 3: Patients with Outstanding Balances' AS report_name,
  patient_name,
  contact_info,
  unpaid_invoices,
  CONCAT('$', FORMAT(total_outstanding, 2)) AS total_outstanding,
  earliest_due_date,
  payment_status
FROM vw_outstanding_patients
ORDER BY total_outstanding DESC;

-- Query 4: Treatment category summary (Report 4)
SELECT 
  'Report 4: Treatments per Category' AS report_name,
  category,
  treatment_count AS appointments_with_treatment,
  total_treatments,
  CONCAT('$', FORMAT(total_revenue, 2)) AS total_revenue,
  CONCAT('$', FORMAT(avg_price, 2)) AS avg_price
FROM vw_treatment_category_summary
WHERE treatment_count > 0
ORDER BY treatment_count DESC;

-- Query 5: Insurance vs out-of-pocket (Report 5)
SELECT 
  'Report 5: Insurance Coverage vs Out-of-Pocket' AS report_name,
  insurance_provider,
  coverage_percentage,
  total_patients,
  total_invoices,
  CONCAT('$', FORMAT(total_billing, 2)) AS total_billing,
  CONCAT('$', FORMAT(total_insurance_coverage, 2)) AS total_insurance_coverage,
  CONCAT('$', FORMAT(total_out_of_pocket, 2)) AS total_out_of_pocket,
  CONCAT(FORMAT(avg_coverage_percentage, 2), '%') AS avg_coverage_percentage
FROM vw_insurance_vs_outofpocket
ORDER BY total_billing DESC;

-- ============================================================
-- COMPLETION MESSAGE
-- ============================================================

SELECT '✅ Database setup completed successfully!' AS Status,
       'All tables enhanced, triggers created, procedures defined, views ready, and dummy data populated.' AS Message;

SELECT 'Next Steps:' AS Info, 
       '1. Test the reporting views above' AS Step1,
       '2. Use stored procedures for appointment creation and payments' AS Step2,
       '3. Verify triggers are preventing overlapping appointments' AS Step3,
       '4. Run sample queries to generate reports' AS Step4;
