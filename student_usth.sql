CREATE TABLE "STUDENT" (
	"id" INTEGER NOT NULL UNIQUE GENERATED BY DEFAULT AS IDENTITY,
	"student_id" VARCHAR(255) NOT NULL,
	"student_name" VARCHAR(255) NOT NULL,
	"date_of_birth" DATE NOT NULL,
	"class_id" INTEGER NOT NULL,
	PRIMARY KEY("id")
);


CREATE TABLE "CLASS" (
	"id" INTEGER NOT NULL UNIQUE GENERATED BY DEFAULT AS IDENTITY,
	"class_name" VARCHAR(255) NOT NULL,
	PRIMARY KEY("id")
);


CREATE TABLE "SUBJECT" (
	"id" INTEGER NOT NULL UNIQUE GENERATED BY DEFAULT AS IDENTITY,
	"subject_name" VARCHAR(255) NOT NULL,
	PRIMARY KEY("id")
);


CREATE TABLE "FACE" (
	"id" INTEGER NOT NULL UNIQUE GENERATED BY DEFAULT AS IDENTITY,
	"student_id" INTEGER NOT NULL,
	"url" TEXT NOT NULL,
	PRIMARY KEY("id")
);


CREATE TABLE "ATTENDANCE_RECORD" (
	"id" INTEGER NOT NULL UNIQUE GENERATED BY DEFAULT AS IDENTITY,
	"student_id" INTEGER NOT NULL,
	"class_id" INTEGER NOT NULL,
	"subject_id" INTEGER NOT NULL,
	"date" DATE NOT NULL,
	"status" VARCHAR(255) NOT NULL,
	PRIMARY KEY("id")
);


CREATE TABLE "ATTENDANCE_SUMMARY" (
	"id" INTEGER NOT NULL UNIQUE GENERATED BY DEFAULT AS IDENTITY,
	"class_id" INTEGER NOT NULL,
	"subject_id" INTEGER NOT NULL,
	"student_id" INTEGER NOT NULL,
	"total_absent" VARCHAR(255) NOT NULL,
	"total_present" VARCHAR(255) NOT NULL,
	PRIMARY KEY("id")
);


CREATE TABLE "SUBJECT_CLASS" (
	"class_id, subject_id" INTEGER NOT NULL UNIQUE GENERATED BY DEFAULT AS IDENTITY,
	"class_id" INTEGER NOT NULL,
	"subject_id" INTEGER NOT NULL,
	PRIMARY KEY("class_id, subject_id")
);


ALTER TABLE "ATTENDANCE_RECORD"
ADD FOREIGN KEY("student_id") REFERENCES "STUDENT"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;
ALTER TABLE "ATTENDANCE_RECORD"
ADD FOREIGN KEY("class_id") REFERENCES "CLASS"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;
ALTER TABLE "ATTENDANCE_RECORD"
ADD FOREIGN KEY("subject_id") REFERENCES "SUBJECT"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;
ALTER TABLE "FACE"
ADD FOREIGN KEY("student_id") REFERENCES "STUDENT"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;
ALTER TABLE "ATTENDANCE_SUMMARY"
ADD FOREIGN KEY("class_id") REFERENCES "CLASS"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;
ALTER TABLE "ATTENDANCE_SUMMARY"
ADD FOREIGN KEY("subject_id") REFERENCES "SUBJECT"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;
ALTER TABLE "ATTENDANCE_SUMMARY"
ADD FOREIGN KEY("student_id") REFERENCES "STUDENT"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;
ALTER TABLE "SUBJECT_CLASS"
ADD FOREIGN KEY("class_id") REFERENCES "CLASS"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;
ALTER TABLE "SUBJECT_CLASS"
ADD FOREIGN KEY("subject_id") REFERENCES "SUBJECT"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;
ALTER TABLE "STUDENT"
ADD FOREIGN KEY("class_id") REFERENCES "CLASS"("id")
ON UPDATE NO ACTION ON DELETE NO ACTION;

INSERT INTO "CLASS" ("class_name") VALUES
('ICT Class 1'),
('ICT Class 2');

INSERT INTO "STUDENT" ("student_id", "student_name", "date_of_birth", "class_id") VALUES
('BA12-068', 'Nguyen Dinh Hai', '2003-05-26', '1'),
('BA12-003', 'Tran Ngoc Viet Anh', '2003-03-14', '1'),
('BA12-006', 'Ngo Huyen Anh', '2003-12-24', '1'),
('BA12-007', 'Tang Van Anh', '2003-09-01', '2'),
('BA12-093', 'Luyen Pham Ngoc Khanh', '2003-04-04', '2'),
('BA12-095', 'Pham Duc Khiem', '2003-02-09', '2');

INSERT INTO "SUBJECT" ("subject_name") VALUES
('Advance Databases'),
('Introduction to Cryptography');


INSERT INTO "SUBJECT_CLASS" ("class_id", "subject_id") VALUES
('1', '1'),
('1', '2'),
('2', '1'),
('2', '2');

CREATE OR REPLACE FUNCTION create_attendance_summary_for_new_student()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert initial attendance summary records for the new student
    INSERT INTO "ATTENDANCE_SUMMARY" ("class_id", "subject_id", "student_id", "total_present", "total_absent")
    SELECT DISTINCT
        NEW.class_id,
        "SUBJECT_CLASS"."subject_id",
        NEW.id,
        0, -- Total present is 0 for a new student
        0  -- Total absent is 0 for a new student
    FROM "SUBJECT_CLASS"
    WHERE "SUBJECT_CLASS"."class_id" = NEW.class_id;

    -- Insert empty attendance records for all existing attendance sessions
    INSERT INTO "ATTENDANCE_RECORD" ("class_id", "subject_id", "student_id", "date", "status")
    SELECT DISTINCT
        "ATTENDANCE_RECORD"."class_id",
        "ATTENDANCE_RECORD"."subject_id",
        NEW.id,
        "ATTENDANCE_RECORD"."date",
        '' -- Status is an empty string for a new student
    FROM "ATTENDANCE_RECORD"
    WHERE "ATTENDANCE_RECORD"."class_id" = NEW.class_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to invoke the function after a new student is added
CREATE TRIGGER trigger_create_attendance_summary_for_new_student
AFTER INSERT ON "STUDENT"
FOR EACH ROW
EXECUTE FUNCTION create_attendance_summary_for_new_student();

CREATE OR REPLACE FUNCTION update_attendance_summary()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the attendance summary
    -- Check if the summary already exists for the given student, subject, and class
    IF EXISTS (
        SELECT 1
        FROM "ATTENDANCE_SUMMARY"
        WHERE "class_id" = NEW.class_id
        AND "subject_id" = NEW.subject_id
        AND "student_id" = NEW.student_id
    ) THEN
        -- If the summary exists, update it
        UPDATE "ATTENDANCE_SUMMARY"
        SET 
            "total_present" = (SELECT COUNT(*) FROM "ATTENDANCE_RECORD" 
                               WHERE "class_id" = NEW.class_id
                               AND "subject_id" = NEW.subject_id 
                               AND "student_id" = NEW.student_id 
                               AND "status" = 'Present'),
            "total_absent" = (SELECT COUNT(*) FROM "ATTENDANCE_RECORD" 
                              WHERE "class_id" = NEW.class_id
                              AND "subject_id" = NEW.subject_id 
                              AND "student_id" = NEW.student_id 
                              AND "status" = 'Absent')
        WHERE "class_id" = NEW.class_id
        AND "subject_id" = NEW.subject_id
        AND "student_id" = NEW.student_id;
    ELSE
        -- If the summary does not exist, insert a new row
        INSERT INTO "ATTENDANCE_SUMMARY" 
        ("class_id", "subject_id", "student_id", "total_present", "total_absent")
        VALUES 
        (NEW.class_id, NEW.subject_id, NEW.student_id, 
         CASE WHEN NEW.status = 'Present' THEN 1 ELSE 0 END, 
         CASE WHEN NEW.status = 'Absent' THEN 1 ELSE 0 END);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trigger_update_attendance_summary
AFTER INSERT ON "ATTENDANCE_RECORD"
FOR EACH ROW
EXECUTE FUNCTION update_attendance_summary();


INSERT INTO "ATTENDANCE_RECORD" (
    class_id,
    subject_id,
    student_id,
    date,
    status
)
VALUES
     ('1', '1', '1', '2024-11-25', 'Present'),
	('1', '1', '1', '2024-11-26', 'Present'),
    ('1', '2', '1', '2024-11-25', 'Absent'),
    ('1', '2', '1', '2024-11-26', 'Absent'),

	('1', '1', '2', '2024-11-25', 'Present'),
	('1', '1', '2', '2024-11-26', 'Present'),
    ('1', '2', '2', '2024-11-25', 'Absent'),
    ('1', '2', '2', '2024-11-26', 'Absent'),

	('1', '1', '3', '2024-11-25', 'Present'),
	('1', '1', '3', '2024-11-26', 'Present'),
    ('1', '2', '3', '2024-11-25', 'Absent'),
    ('1', '2', '3', '2024-11-26', 'Absent'),

	('2', '1', '4', '2024-11-25', 'Present'),
	('2', '1', '4', '2024-11-26', 'Present'),
    ('2', '2', '4', '2024-11-25', 'Absent'),
    ('2', '2', '4', '2024-11-26', 'Absent'),

	('2', '1', '5', '2024-11-25', 'Present'),
	('2', '1', '5', '2024-11-26', 'Present'),
    ('2', '2', '5', '2024-11-25', 'Absent'),
    ('2', '2', '5', '2024-11-26', 'Absent'),

	('2', '1', '6', '2024-11-25', 'Present'),
	('2', '1', '6', '2024-11-26', 'Present'),
    ('2', '2', '6', '2024-11-25', 'Absent'),
    ('2', '2', '6', '2024-11-26', 'Absent');
