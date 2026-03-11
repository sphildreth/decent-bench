-- Sample SQL dump for Decent Bench import testing
CREATE TABLE departments (department_id INTEGER PRIMARY KEY, name TEXT NOT NULL, budget REAL);
CREATE TABLE staff (staff_id INTEGER PRIMARY KEY, department_id INTEGER NOT NULL, first_name TEXT NOT NULL, last_name TEXT NOT NULL, start_date TEXT, salary REAL, FOREIGN KEY (department_id) REFERENCES departments(department_id));
INSERT INTO departments (department_id, name, budget) VALUES
 (10, 'Engineering', 750000.00),
 (20, 'Sales', 420000.00),
 (30, 'Operations', 310000.00);
INSERT INTO staff (staff_id, department_id, first_name, last_name, start_date, salary) VALUES
 (1, 10, 'Alice', 'Carter', '2021-04-01', 112000.00),
 (2, 20, 'Bob', 'Smith', '2019-09-15', 85000.00),
 (3, 10, 'Carla', 'Gomez', '2022-01-10', 118500.00),
 (4, 30, 'Dinesh', 'Patel', '2020-06-20', 61500.00);
