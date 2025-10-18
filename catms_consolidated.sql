-- ============================================================
-- CATMS - Clinic Appointment & Treatment Management System
-- Consolidated schema, constraints, triggers, procedures, views, and seed data
-- MySQL 8.0.43 compatible
-- ============================================================

SET SQL_MODE='STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';
SET FOREIGN_KEY_CHECKS=0;

CREATE DATABASE IF NOT EXISTS hospital1;
USE hospital1;

-- ============================================================
-- SECTION 1: CORE ENTITIES
-- ============================================================

CREATE TABLE IF NOT EXISTS branch (
  branch_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  address VARCHAR(255) NULL,
  phone VARCHAR(25) NULL,
  manager_staff_id INT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS specialty (
  specialty_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS insurance_provider (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS staff (
  staff_id INT AUTO_INCREMENT PRIMARY KEY,
  branch_id INT NOT NULL,
  name VARCHAR(120) NOT NULL,
  role ENUM('Doctor','Nurse','Receptionist','Manager','Admin') NOT NULL,
  contact_info VARCHAR(255) NULL,
  user_ref VARCHAR(120) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_staff_branch FOREIGN KEY (branch_id) REFERENCES branch(branch_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Add manager reference after staff exists to avoid circular creation
ALTER TABLE branch
  ADD CONSTRAINT IF NOT EXISTS fk_branch_manager
  FOREIGN KEY (manager_staff_id) REFERENCES staff(staff_id)
  ON UPDATE CASCADE ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS doctor (
  doctor_id INT AUTO_INCREMENT PRIMARY KEY,
  staff_id INT NOT NULL UNIQUE,
  license_number VARCHAR(60) NULL,
  CONSTRAINT fk_doctor_staff FOREIGN KEY (staff_id) REFERENCES staff(staff_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS doctor_specialties (
  doctor_id INT NOT NULL,
  specialty_id INT NOT NULL,
  PRIMARY KEY (doctor_id, specialty_id),
  CONSTRAINT fk_ds_doctor FOREIGN KEY (doctor_id) REFERENCES doctor(doctor_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_ds_specialty FOREIGN KEY (specialty_id) REFERENCES specialty(specialty_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS patient (
  patient_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  gender ENUM('Male','Female','Other') NOT NULL,
  date_of_birth DATE NOT NULL,
  contact_info VARCHAR(255) NULL,
  emergency_contact VARCHAR(255) NULL,
  insurance_provider_id INT NULL,
  policy_number VARCHAR(80) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_patient_ins_provider FOREIGN KEY (insurance_provider_id) REFERENCES insurance_provider(id)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- Appointments use explicit start/end to enforce overlap constraints precisely
CREATE TABLE IF NOT EXISTS appointment (
  appointment_id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  doctor_id INT NOT NULL,
  branch_id INT NOT NULL,
  schedule_start DATETIME NOT NULL,
  schedule_end DATETIME NOT NULL,
  status ENUM('Scheduled','Completed','Cancelled','Rescheduled') NOT NULL DEFAULT 'Scheduled',
  is_emergency TINYINT(1) NOT NULL DEFAULT 0,
  consultation_notes TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_appt_patient FOREIGN KEY (patient_id) REFERENCES patient(patient_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_appt_doctor FOREIGN KEY (doctor_id) REFERENCES doctor(doctor_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_appt_branch FOREIGN KEY (branch_id) REFERENCES branch(branch_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS rescheduled_appointments (
  reschedule_id INT AUTO_INCREMENT PRIMARY KEY,
  previous_appointment_id INT NOT NULL,
  previous_start DATETIME NOT NULL,
  previous_end DATETIME NOT NULL,
  new_start DATETIME NOT NULL,
  new_end DATETIME NOT NULL,
  rescheduled_by_staff_id INT NOT NULL,
  reschedule_reason TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_resch_appt FOREIGN KEY (previous_appointment_id) REFERENCES appointment(appointment_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_resch_staff FOREIGN KEY (rescheduled_by_staff_id) REFERENCES staff(staff_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS treatment_catalogue (
  service_code VARCHAR(20) PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  description VARCHAR(255) NULL,
  price DECIMAL(10,2) NOT NULL,
  category VARCHAR(50) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS appointment_treatment (
  appointment_treatment_id INT AUTO_INCREMENT PRIMARY KEY,
  appointment_id INT NOT NULL,
  service_code VARCHAR(20) NOT NULL,
  notes TEXT NULL,
  actual_price DECIMAL(10,2) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_at_appt FOREIGN KEY (appointment_id) REFERENCES appointment(appointment_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_at_service FOREIGN KEY (service_code) REFERENCES treatment_catalogue(service_code)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS invoice (
  invoice_id INT AUTO_INCREMENT PRIMARY KEY,
  appointment_id INT NOT NULL UNIQUE,
  total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  insurance_coverage DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  out_of_pocket_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  due_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  status ENUM('Pending','Unpaid','Partially Paid','Paid','Cancelled') NOT NULL DEFAULT 'Pending',
  issued_date DATE NOT NULL DEFAULT (CURRENT_DATE),
  due_date DATE NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_invoice_appt FOREIGN KEY (appointment_id) REFERENCES appointment(appointment_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payment (
  payment_id INT AUTO_INCREMENT PRIMARY KEY,
  invoice_id INT NOT NULL,
  paid_amount DECIMAL(10,2) NOT NULL,
  payment_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  method_of_payment ENUM('Cash','Credit Card','Debit Card','Transfer','Insurance') NOT NULL,
  status ENUM('Pending','Completed','Failed') NOT NULL DEFAULT 'Completed',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_payment_invoice FOREIGN KEY (invoice_id) REFERENCES invoice(invoice_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS insurance_claim (
  claim_id INT AUTO_INCREMENT PRIMARY KEY,
  invoice_id INT NOT NULL,
  insurance_provider_id INT NOT NULL,
  claimed_amount DECIMAL(10,2) NOT NULL,
  claim_status ENUM('Pending','Approved','Rejected','Paid') NOT NULL DEFAULT 'Pending',
  submitted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  paid_at DATETIME NULL,
  CONSTRAINT fk_claim_invoice FOREIGN KEY (invoice_id) REFERENCES invoice(invoice_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_claim_ins_provider FOREIGN KEY (insurance_provider_id) REFERENCES insurance_provider(id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS=1;

-- ============================================================
-- SECTION 2: PERFORMANCE INDEXES (safe creation via prepared statements)
-- ============================================================

-- Helper: create index if missing using INFORMATION_SCHEMA and dynamic SQL
-- appointment indexes
SET @exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='appointment' AND INDEX_NAME='idx_appointment_start');
SET @sql := IF(@exists=0, 'CREATE INDEX idx_appointment_start ON appointment(schedule_start)', 'SELECT 1'); PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='appointment' AND INDEX_NAME='idx_appointment_doctor_start');
SET @sql := IF(@exists=0, 'CREATE INDEX idx_appointment_doctor_start ON appointment(doctor_id, schedule_start)', 'SELECT 1'); PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='appointment' AND INDEX_NAME='idx_appointment_branch_start');
SET @sql := IF(@exists=0, 'CREATE INDEX idx_appointment_branch_start ON appointment(branch_id, schedule_start)', 'SELECT 1'); PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='appointment' AND INDEX_NAME='idx_appointment_status');
SET @sql := IF(@exists=0, 'CREATE INDEX idx_appointment_status ON appointment(status)', 'SELECT 1'); PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='appointment' AND INDEX_NAME='idx_appointment_patient');
SET @sql := IF(@exists=0, 'CREATE INDEX idx_appointment_patient ON appointment(patient_id)', 'SELECT 1'); PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- invoice and payment
SET @exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invoice' AND INDEX_NAME='idx_invoice_status');
SET @sql := IF(@exists=0, 'CREATE INDEX idx_invoice_status ON invoice(status)', 'SELECT 1'); PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invoice' AND INDEX_NAME='idx_invoice_issued');
SET @sql := IF(@exists=0, 'CREATE INDEX idx_invoice_issued ON invoice(issued_date)', 'SELECT 1'); PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='payment' AND INDEX_NAME='idx_payment_date');
SET @sql := IF(@exists=0, 'CREATE INDEX idx_payment_date ON payment(payment_date)', 'SELECT 1'); PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='payment' AND INDEX_NAME='idx_payment_invoice');
SET @sql := IF(@exists=0, 'CREATE INDEX idx_payment_invoice ON payment(invoice_id)', 'SELECT 1'); PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- staff/doctor/treatment
SET @exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='staff' AND INDEX_NAME='idx_staff_branch');
SET @sql := IF(@exists=0, 'CREATE INDEX idx_staff_branch ON staff(branch_id)', 'SELECT 1'); PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='doctor' AND INDEX_NAME='idx_doctor_staff');
SET @sql := IF(@exists=0, 'CREATE INDEX idx_doctor_staff ON doctor(staff_id)', 'SELECT 1'); PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='treatment_catalogue' AND INDEX_NAME='idx_treatment_category');
SET @sql := IF(@exists=0, 'CREATE INDEX idx_treatment_category ON treatment_catalogue(category)', 'SELECT 1'); PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ============================================================
-- SECTION 3: TRIGGERS (business rules)
-- ============================================================

DELIMITER $$

-- Prevent overlapping appointments for same doctor (INSERT)
DROP TRIGGER IF EXISTS trg_prevent_overlap_insert $$
CREATE TRIGGER trg_prevent_overlap_insert
BEFORE INSERT ON appointment
FOR EACH ROW
BEGIN
  DECLARE overlap_count INT DEFAULT 0;
  IF NEW.schedule_end <= NEW.schedule_start THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'schedule_end must be after schedule_start';
  END IF;
  SELECT COUNT(*) INTO overlap_count
  FROM appointment a
  WHERE a.doctor_id = NEW.doctor_id
    AND a.status IN ('Scheduled','Rescheduled')
    AND NEW.schedule_start < a.schedule_end
    AND NEW.schedule_end   > a.schedule_start;
  IF overlap_count > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor already has an overlapping appointment in that time window';
  END IF;
END $$

-- Prevent overlapping appointments for same doctor (UPDATE)
DROP TRIGGER IF EXISTS trg_prevent_overlap_update $$
CREATE TRIGGER trg_prevent_overlap_update
BEFORE UPDATE ON appointment
FOR EACH ROW
BEGIN
  DECLARE overlap_count INT DEFAULT 0;
  IF NEW.schedule_end <= NEW.schedule_start THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'schedule_end must be after schedule_start';
  END IF;
  IF NEW.schedule_start <> OLD.schedule_start OR NEW.schedule_end <> OLD.schedule_end OR NEW.doctor_id <> OLD.doctor_id THEN
    SELECT COUNT(*) INTO overlap_count
    FROM appointment a
    WHERE a.doctor_id = NEW.doctor_id
      AND a.appointment_id <> NEW.appointment_id
      AND a.status IN ('Scheduled','Rescheduled')
      AND NEW.schedule_start < a.schedule_end
      AND NEW.schedule_end   > a.schedule_start;
    IF overlap_count > 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor already has an overlapping appointment in that time window';
    END IF;
  END IF;
END $$

-- Update invoice due/status when a payment is recorded
DROP TRIGGER IF EXISTS trg_update_invoice_after_payment $$
CREATE TRIGGER trg_update_invoice_after_payment
AFTER INSERT ON payment
FOR EACH ROW
BEGIN
  DECLARE v_due DECIMAL(10,2);
  DECLARE v_total DECIMAL(10,2);
  DECLARE v_ins DECIMAL(10,2);
  DECLARE v_new_due DECIMAL(10,2);
  DECLARE v_new_status VARCHAR(20);

  SELECT due_amount, total_amount, insurance_coverage
  INTO v_due, v_total, v_ins
  FROM invoice
  WHERE invoice_id = NEW.invoice_id
  FOR UPDATE;

  SET v_new_due = GREATEST(0, v_due - NEW.paid_amount);
  SET v_new_status = CASE
    WHEN v_new_due = 0 THEN 'Paid'
    WHEN v_new_due < (v_total - v_ins) THEN 'Partially Paid'
    ELSE 'Unpaid'
  END;

  UPDATE invoice
  SET due_amount = v_new_due,
      status = v_new_status
  WHERE invoice_id = NEW.invoice_id;
END $$

-- Validate that only non-future appointments can be completed
DROP TRIGGER IF EXISTS trg_validate_completion $$
CREATE TRIGGER trg_validate_completion
BEFORE UPDATE ON appointment
FOR EACH ROW
BEGIN
  IF NEW.status = 'Completed' AND OLD.status <> 'Completed' THEN
    IF NEW.schedule_start > NOW() THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot complete an appointment scheduled in the future';
    END IF;
  END IF;
END $$

-- Ensure treatments can be recorded only for completed appointments
DROP TRIGGER IF EXISTS trg_enforce_treatment_after_completion $$
CREATE TRIGGER trg_enforce_treatment_after_completion
BEFORE INSERT ON appointment_treatment
FOR EACH ROW
BEGIN
  DECLARE v_status VARCHAR(20);
  SELECT status INTO v_status FROM appointment WHERE appointment_id = NEW.appointment_id;
  IF v_status <> 'Completed' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Treatments can be added only to Completed appointments';
  END IF;
END $$

DELIMITER ;

-- ============================================================
-- SECTION 4: PROCEDURES & FUNCTIONS (ACID-safe flows)
-- ============================================================

DROP PROCEDURE IF EXISTS CreateAppointmentWithInvoice;
DROP PROCEDURE IF EXISTS ProcessPayment;
DROP PROCEDURE IF EXISTS RescheduleAppointment;
DROP PROCEDURE IF EXISTS CompleteAppointment;
DROP FUNCTION IF EXISTS GetPatientOutstandingBalance;
DROP FUNCTION IF EXISTS GetDoctorRevenue;

DELIMITER $$

CREATE PROCEDURE CreateAppointmentWithInvoice(
  IN p_patient_id INT,
  IN p_doctor_id INT,
  IN p_branch_id INT,
  IN p_start DATETIME,
  IN p_end DATETIME,
  IN p_is_emergency TINYINT,
  OUT p_appointment_id INT,
  OUT p_invoice_id INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Failed to create appointment with invoice';
  END;

  START TRANSACTION;

  INSERT INTO appointment (patient_id, doctor_id, branch_id, schedule_start, schedule_end, status, is_emergency)
  VALUES (p_patient_id, p_doctor_id, p_branch_id, p_start, p_end, 'Scheduled', p_is_emergency);

  SET p_appointment_id = LAST_INSERT_ID();

  INSERT INTO invoice (appointment_id, total_amount, insurance_coverage, out_of_pocket_amount, due_amount, status, issued_date, due_date)
  VALUES (p_appointment_id, 0.00, 0.00, 0.00, 0.00, 'Pending', CURRENT_DATE, DATE_ADD(CURRENT_DATE, INTERVAL 30 DAY));

  SET p_invoice_id = LAST_INSERT_ID();

  COMMIT;
END $$

CREATE PROCEDURE ProcessPayment(
  IN p_invoice_id INT,
  IN p_paid_amount DECIMAL(10,2),
  IN p_method VARCHAR(50)
)
BEGIN
  DECLARE v_due DECIMAL(10,2);
  DECLARE v_status VARCHAR(20);

  IF p_paid_amount <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment amount must be positive';
  END IF;

  START TRANSACTION;
  SELECT due_amount, status INTO v_due, v_status FROM invoice WHERE invoice_id = p_invoice_id FOR UPDATE;
  IF v_due IS NULL THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invoice not found';
  END IF;
  IF p_paid_amount > v_due THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment exceeds due amount';
  END IF;

  INSERT INTO payment (invoice_id, paid_amount, payment_date, method_of_payment, status)
  VALUES (p_invoice_id, p_paid_amount, NOW(), p_method, 'Completed');

  COMMIT;
END $$

CREATE PROCEDURE RescheduleAppointment(
  IN p_appointment_id INT,
  IN p_new_start DATETIME,
  IN p_new_end DATETIME,
  IN p_staff_id INT,
  IN p_reason TEXT
)
BEGIN
  DECLARE v_old_start DATETIME;
  DECLARE v_old_end DATETIME;

  START TRANSACTION;
  SELECT schedule_start, schedule_end INTO v_old_start, v_old_end FROM appointment WHERE appointment_id = p_appointment_id FOR UPDATE;

  UPDATE appointment
  SET schedule_start = p_new_start,
      schedule_end = p_new_end,
      status = 'Rescheduled'
  WHERE appointment_id = p_appointment_id;

  INSERT INTO rescheduled_appointments (previous_appointment_id, previous_start, previous_end, new_start, new_end, rescheduled_by_staff_id, reschedule_reason)
  VALUES (p_appointment_id, v_old_start, v_old_end, p_new_start, p_new_end, p_staff_id, p_reason);

  COMMIT;
END $$

CREATE PROCEDURE CompleteAppointment(
  IN p_appointment_id INT
)
BEGIN
  DECLARE v_total DECIMAL(10,2) DEFAULT 0.00;
  DECLARE v_invoice_id INT;
  DECLARE v_ins_provider_id INT;
  DECLARE v_ins_coverage DECIMAL(10,2) DEFAULT 0.00;

  START TRANSACTION;

  UPDATE appointment
  SET status = 'Completed'
  WHERE appointment_id = p_appointment_id;

  SELECT COALESCE(SUM(COALESCE(at.actual_price, tc.price)),0.00) INTO v_total
  FROM appointment_treatment at
  JOIN treatment_catalogue tc ON tc.service_code = at.service_code
  WHERE at.appointment_id = p_appointment_id;

  SELECT invoice_id INTO v_invoice_id FROM invoice WHERE appointment_id = p_appointment_id FOR UPDATE;

  SELECT p.insurance_provider_id INTO v_ins_provider_id
  FROM appointment a
  JOIN patient p ON p.patient_id = a.patient_id
  WHERE a.appointment_id = p_appointment_id;

  IF v_ins_provider_id IS NOT NULL THEN
    SET v_ins_coverage = ROUND(v_total * 0.70, 2);
  ELSE
    SET v_ins_coverage = 0.00;
  END IF;

  UPDATE invoice
  SET total_amount = v_total,
      insurance_coverage = v_ins_coverage,
      out_of_pocket_amount = (v_total - v_ins_coverage),
      due_amount = (v_total - v_ins_coverage),
      status = CASE WHEN v_total = 0 THEN 'Pending' ELSE 'Unpaid' END
  WHERE invoice_id = v_invoice_id;

  COMMIT;
END $$

CREATE FUNCTION GetPatientOutstandingBalance(p_patient_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE v_balance DECIMAL(10,2);
  SELECT COALESCE(SUM(i.due_amount),0.00) INTO v_balance
  FROM invoice i
  JOIN appointment a ON a.appointment_id = i.appointment_id
  WHERE a.patient_id = p_patient_id
    AND i.status IN ('Unpaid','Partially Paid');
  RETURN v_balance;
END $$

CREATE FUNCTION GetDoctorRevenue(p_doctor_id INT, p_start DATE, p_end DATE)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE v_rev DECIMAL(10,2);
  SELECT COALESCE(SUM(i.total_amount),0.00) INTO v_rev
  FROM invoice i
  JOIN appointment a ON a.appointment_id = i.appointment_id
  WHERE a.doctor_id = p_doctor_id
    AND a.status = 'Completed'
    AND DATE(a.schedule_start) BETWEEN p_start AND p_end;
  RETURN v_rev;
END $$

DELIMITER ;

-- ============================================================
-- SECTION 5: REPORTING VIEWS
-- ============================================================

DROP VIEW IF EXISTS vw_branch_appointment_summary;
DROP VIEW IF EXISTS vw_doctor_revenue;
DROP VIEW IF EXISTS vw_outstanding_patients;
DROP VIEW IF EXISTS vw_treatment_category_summary;
DROP VIEW IF EXISTS vw_insurance_vs_outofpocket;

CREATE VIEW vw_branch_appointment_summary AS
SELECT
  b.branch_id,
  b.name AS branch_name,
  DATE(a.schedule_start) AS appointment_date,
  COUNT(*) AS total_appointments,
  SUM(CASE WHEN a.status = 'Scheduled' THEN 1 ELSE 0 END) AS scheduled_count,
  SUM(CASE WHEN a.status = 'Completed' THEN 1 ELSE 0 END) AS completed_count,
  SUM(CASE WHEN a.status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_count,
  SUM(CASE WHEN a.status = 'Rescheduled' THEN 1 ELSE 0 END) AS rescheduled_count,
  SUM(CASE WHEN a.is_emergency = 1 THEN 1 ELSE 0 END) AS emergency_count
FROM branch b
JOIN appointment a ON a.branch_id = b.branch_id
GROUP BY b.branch_id, b.name, DATE(a.schedule_start);

CREATE VIEW vw_doctor_revenue AS
SELECT
  d.doctor_id,
  s.name AS doctor_name,
  b.name AS branch_name,
  COUNT(DISTINCT a.appointment_id) AS total_appointments,
  COUNT(DISTINCT CASE WHEN a.status = 'Completed' THEN a.appointment_id END) AS completed_appointments,
  COALESCE(SUM(CASE WHEN a.status = 'Completed' THEN i.total_amount END), 0) AS total_revenue,
  COALESCE(AVG(CASE WHEN a.status = 'Completed' THEN i.total_amount END), 0) AS avg_revenue_per_appointment
FROM doctor d
JOIN staff s ON s.staff_id = d.staff_id
JOIN branch b ON b.branch_id = s.branch_id
LEFT JOIN appointment a ON a.doctor_id = d.doctor_id
LEFT JOIN invoice i ON i.appointment_id = a.appointment_id
GROUP BY d.doctor_id, s.name, b.name;

CREATE VIEW vw_outstanding_patients AS
SELECT
  p.patient_id,
  p.name AS patient_name,
  p.contact_info,
  COUNT(DISTINCT i.invoice_id) AS unpaid_invoices,
  SUM(i.due_amount) AS total_outstanding,
  MIN(i.due_date) AS earliest_due_date,
  MAX(i.due_date) AS latest_due_date,
  CASE WHEN MIN(i.due_date) < CURDATE() THEN 'Overdue' ELSE 'Due' END AS payment_status
FROM patient p
JOIN appointment a ON a.patient_id = p.patient_id
JOIN invoice i ON i.appointment_id = a.appointment_id
WHERE i.status IN ('Unpaid','Partially Paid') AND i.due_amount > 0
GROUP BY p.patient_id, p.name, p.contact_info;

CREATE VIEW vw_treatment_category_summary AS
SELECT
  tc.category,
  COUNT(*) AS treatment_count,
  SUM(COALESCE(at.actual_price, tc.price)) AS total_revenue,
  AVG(COALESCE(at.actual_price, tc.price)) AS avg_price,
  MIN(COALESCE(at.actual_price, tc.price)) AS min_price,
  MAX(COALESCE(at.actual_price, tc.price)) AS max_price
FROM appointment_treatment at
JOIN treatment_catalogue tc ON tc.service_code = at.service_code
GROUP BY tc.category;

CREATE VIEW vw_insurance_vs_outofpocket AS
SELECT
  COALESCE(ip.name, 'No Insurance') AS insurance_provider,
  COUNT(DISTINCT p.patient_id) AS total_patients,
  COUNT(DISTINCT i.invoice_id) AS total_invoices,
  SUM(i.total_amount) AS total_billing,
  SUM(i.insurance_coverage) AS total_insurance_coverage,
  SUM(i.out_of_pocket_amount) AS total_out_of_pocket,
  ROUND(AVG(CASE WHEN i.total_amount > 0 THEN (i.insurance_coverage / i.total_amount) * 100 END), 2) AS avg_coverage_percentage
FROM patient p
LEFT JOIN insurance_provider ip ON ip.id = p.insurance_provider_id
LEFT JOIN appointment a ON a.patient_id = p.patient_id
LEFT JOIN invoice i ON i.appointment_id = a.appointment_id
GROUP BY COALESCE(ip.name, 'No Insurance');

-- ============================================================
-- SECTION 6: SEED DUMMY DATA
-- ============================================================

-- Branches
INSERT INTO branch (name, address, phone) VALUES
  ('Colombo', '123 Galle Road, Colombo', '+94-11-1234567'),
  ('Kandy', '45 Peradeniya Rd, Kandy', '+94-81-2345678'),
  ('Galle', '78 Fort St, Galle', '+94-91-3456789')
ON DUPLICATE KEY UPDATE address=VALUES(address), phone=VALUES(phone);

-- Specialties
INSERT INTO specialty (name) VALUES
  ('General Medicine'),
  ('ENT'),
  ('Paediatrics'),
  ('Dermatology'),
  ('Cardiology')
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Insurance Providers
INSERT INTO insurance_provider (name) VALUES
  ('MedLife'),
  ('PanAsia'),
  ('GeneralHealth')
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Staff (some doctors)
INSERT INTO staff (branch_id, name, role, contact_info, user_ref) VALUES
  (1, 'Dr. Alice Perera', 'Doctor', 'alice@example.com', 'alice'),
  (1, 'Dr. Bernard Silva', 'Doctor', 'bernard@example.com', 'bernard'),
  (2, 'Dr. Chathura Fernando', 'Doctor', 'chathura@example.com', 'chathura'),
  (3, 'Dr. Devika Jayawardena', 'Doctor', 'devika@example.com', 'devika'),
  (1, 'Dr. Eranda Gunasekara', 'Doctor', 'eranda@example.com', 'eranda'),
  (1, 'Maya Senanayake', 'Receptionist', 'maya@example.com', 'maya'),
  (2, 'Nuwan Dissanayake', 'Manager', 'nuwan@example.com', 'nuwan'),
  (3, 'Isha Abeywardena', 'Nurse', 'isha@example.com', 'isha')
ON DUPLICATE KEY UPDATE contact_info=VALUES(contact_info);

-- Link doctors (use first five doctor staff rows)
INSERT INTO doctor (staff_id, license_number)
SELECT s.staff_id, CONCAT('LIC-', s.staff_id)
FROM staff s
WHERE s.role='Doctor' AND NOT EXISTS (
  SELECT 1 FROM doctor d WHERE d.staff_id = s.staff_id
);

-- Assign manager to branches (best-effort)
UPDATE branch b
JOIN staff s ON s.branch_id = b.branch_id AND s.role='Manager'
SET b.manager_staff_id = s.staff_id;

-- Doctor specialties (assign at least one per doctor)
INSERT IGNORE INTO doctor_specialties (doctor_id, specialty_id)
SELECT d.doctor_id, 1 FROM doctor d WHERE d.doctor_id IS NOT NULL;
INSERT IGNORE INTO doctor_specialties (doctor_id, specialty_id)
SELECT d.doctor_id, 5 FROM doctor d WHERE d.doctor_id <= 2;

-- Treatment Catalogue with categories
INSERT INTO treatment_catalogue (service_code, name, description, price, category) VALUES
  ('CON-001', 'General Consultation', 'Standard medical consultation', 80.00, 'Consultation'),
  ('CON-002', 'Specialist Consultation', 'Consultation with specialist', 150.00, 'Consultation'),
  ('LAB-001', 'Basic Blood Panel', 'Basic lab blood work', 150.50, 'Laboratory'),
  ('LAB-002', 'Complete Blood Count', 'CBC test', 180.00, 'Laboratory'),
  ('XRAY-001', 'Chest X-Ray', 'Chest imaging', 120.00, 'Imaging'),
  ('XRAY-002', 'Abdominal X-Ray', 'Abdominal imaging', 150.00, 'Imaging'),
  ('ECG-001', 'Electrocardiogram', 'Heart rhythm test', 200.00, 'Cardiology'),
  ('INJ-001', 'IV Injection', 'Intravenous injection', 50.00, 'Treatment'),
  ('DERM-001', 'Skin Allergy Test', 'Dermatology test', 250.00, 'Dermatology'),
  ('DERM-002', 'Skin Biopsy', 'Dermatology procedure', 350.00, 'Dermatology')
ON DUPLICATE KEY UPDATE name=VALUES(name), description=VALUES(description), price=VALUES(price), category=VALUES(category);

-- Patients
INSERT INTO patient (name, gender, date_of_birth, contact_info, emergency_contact, insurance_provider_id, policy_number) VALUES
  ('Saman Silva', 'Male', '1985-05-20', '0771234567', '0777654321', 1, 'ML-2024-001'),
  ('Nimal Perera', 'Male', '1990-08-15', '0762345678', '0768765432', 2, 'PA-2024-002'),
  ('Kamala Fernando', 'Female', '1978-03-10', '0753456789', '0759876543', 3, 'GE-2024-003'),
  ('Ruwan Jayasinghe', 'Male', '1995-11-25', '0744567890', '0740987654', NULL, NULL),
  ('Sanduni Rajapaksha', 'Female', '2000-07-08', '0735678901', '0731098765', 1, 'ML-2024-004'),
  ('Malini Wickramasinghe', 'Female', '1982-12-30', '0726789012', '0722109876', NULL, NULL)
ON DUPLICATE KEY UPDATE contact_info=VALUES(contact_info);

-- Appointments (create invoices after each)
-- Helper variables (not necessary in MySQL script; inserting directly)

-- For simplicity, 45-minute slots
INSERT INTO appointment (patient_id, doctor_id, branch_id, schedule_start, schedule_end, status, is_emergency) VALUES
  (1, 1, 1, '2025-10-20 09:00:00', '2025-10-20 09:45:00', 'Completed', 0),
  (2, 1, 1, '2025-10-20 10:00:00', '2025-10-20 10:45:00', 'Completed', 0),
  (3, 2, 1, '2025-10-20 11:00:00', '2025-10-20 11:30:00', 'Completed', 0),
  (4, 3, 2, '2025-10-21 09:00:00', '2025-10-21 09:45:00', 'Scheduled', 0),
  (5, 3, 2, '2025-10-21 10:00:00', '2025-10-21 10:30:00', 'Scheduled', 0),
  (6, 1, 1, '2025-10-21 14:00:00', '2025-10-21 14:20:00', 'Scheduled', 1),
  (1, 2, 1, '2025-10-15 09:00:00', '2025-10-15 09:45:00', 'Completed', 0),
  (2, 3, 2, '2025-10-16 14:00:00', '2025-10-16 14:45:00', 'Completed', 0),
  (3, 1, 1, '2025-10-17 11:00:00', '2025-10-17 11:30:00', 'Cancelled', 0)
ON DUPLICATE KEY UPDATE status=VALUES(status), schedule_start=VALUES(schedule_start), schedule_end=VALUES(schedule_end);

-- Create invoices for all appointments if missing
INSERT INTO invoice (appointment_id, total_amount, insurance_coverage, out_of_pocket_amount, due_amount, status, issued_date, due_date)
SELECT a.appointment_id, 0.00, 0.00, 0.00, 0.00,
       'Pending', DATE(a.schedule_start), DATE(a.schedule_start) + INTERVAL 30 DAY
FROM appointment a
LEFT JOIN invoice i ON i.appointment_id = a.appointment_id
WHERE i.invoice_id IS NULL;

-- Treatments for completed appointments
INSERT INTO appointment_treatment (appointment_id, service_code, notes, actual_price) VALUES
  (1, 'CON-001', 'Regular checkup', 80.00),
  (1, 'ECG-001', 'Heart rhythm check', 200.00),
  (2, 'CON-001', 'General consultation', 80.00),
  (2, 'LAB-001', 'Blood work ordered', 150.50),
  (3, 'DERM-001', 'Skin allergy testing', 250.00),
  (7, 'CON-001', 'Follow-up visit', 80.00),
  (7, 'XRAY-001', 'Chest X-ray', 120.00),
  (8, 'CON-002', 'Specialist consult', 150.00),
  (8, 'LAB-002', 'CBC test', 180.00)
ON DUPLICATE KEY UPDATE actual_price=VALUES(actual_price), notes=VALUES(notes);

-- Compute invoice totals for completed appointments
UPDATE invoice i
JOIN appointment a ON a.appointment_id = i.appointment_id
LEFT JOIN (
  SELECT at.appointment_id, SUM(COALESCE(at.actual_price, tc.price)) AS total
  FROM appointment_treatment at
  JOIN treatment_catalogue tc ON tc.service_code = at.service_code
  GROUP BY at.appointment_id
) t ON t.appointment_id = a.appointment_id
LEFT JOIN patient p ON p.patient_id = a.patient_id
SET i.total_amount = COALESCE(t.total,0.00),
    i.insurance_coverage = CASE WHEN p.insurance_provider_id IS NOT NULL THEN ROUND(COALESCE(t.total,0.00) * 0.70,2) ELSE 0.00 END,
    i.out_of_pocket_amount = CASE WHEN p.insurance_provider_id IS NOT NULL THEN ROUND(COALESCE(t.total,0.00) * 0.30,2) ELSE COALESCE(t.total,0.00) END,
    i.due_amount = CASE WHEN p.insurance_provider_id IS NOT NULL THEN ROUND(COALESCE(t.total,0.00) * 0.30,2) ELSE COALESCE(t.total,0.00) END,
    i.status = CASE WHEN a.status='Completed' THEN 'Unpaid' ELSE i.status END
WHERE a.status = 'Completed';

-- Payments
INSERT INTO payment (invoice_id, paid_amount, payment_date, method_of_payment, status) VALUES
  ((SELECT invoice_id FROM invoice WHERE appointment_id=1), 84.00, '2025-10-20 10:30:00', 'Cash', 'Completed'),
  ((SELECT invoice_id FROM invoice WHERE appointment_id=2), 230.50, '2025-10-20 11:30:00', 'Credit Card', 'Completed'),
  ((SELECT invoice_id FROM invoice WHERE appointment_id=7), 200.00, '2025-10-15 10:00:00', 'Cash', 'Completed'),
  ((SELECT invoice_id FROM invoice WHERE appointment_id=8), 120.00, '2025-10-16 15:00:00', 'Debit Card', 'Completed')
ON DUPLICATE KEY UPDATE status=VALUES(status), paid_amount=VALUES(paid_amount);

-- Insurance claims
INSERT INTO insurance_claim (invoice_id, insurance_provider_id, claimed_amount, claim_status) VALUES
  ((SELECT invoice_id FROM invoice WHERE appointment_id=1), 1, 196.00, 'Approved'),
  ((SELECT invoice_id FROM invoice WHERE appointment_id=2), 2, 161.35, 'Pending'),
  ((SELECT invoice_id FROM invoice WHERE appointment_id=7), 1, 140.00, 'Approved')
ON DUPLICATE KEY UPDATE claim_status=VALUES(claim_status), claimed_amount=VALUES(claimed_amount);

-- ============================================================
-- SECTION 7: SAMPLE REPORTING QUERIES (for manual testing)
-- ============================================================

-- Branch-wise appointment summary (last 7 days)
-- SELECT * FROM vw_branch_appointment_summary
-- WHERE appointment_date >= CURDATE() - INTERVAL 7 DAY
-- ORDER BY appointment_date DESC, branch_name;

-- Doctor-wise revenue
-- SELECT * FROM vw_doctor_revenue ORDER BY total_revenue DESC;

-- Outstanding patients
-- SELECT * FROM vw_outstanding_patients ORDER BY total_outstanding DESC;

-- Treatment categories summary
-- SELECT * FROM vw_treatment_category_summary ORDER BY treatment_count DESC;

-- Insurance vs out-of-pocket
-- SELECT * FROM vw_insurance_vs_outofpocket;

-- Final status
SELECT 'CATMS consolidated schema and data applied successfully' AS status;