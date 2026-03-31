--1
select student_id,first_name,last_name,
coalesce(nationality, 'unknown') as nationality
from students;

insert into students (first_name, last_name, email, gender, nationality, dept_id) 
values ('test', 'student', 'test.student999@student.edu', 'Male', null, 3);

--2
select first_name || ' ' || last_name as student_name, gpa as real_gpa, 
nullif(gpa, 0.0) as cleaned_gpa from students;

--3
select first_name || ' ' || last_name as student_name, 
coalesce(nullif(gpa, 0.0)::text, 'not evaluated') as gpa_status from students;

insert into students (first_name, last_name, email, gender, nationality, dept_id, gpa) values 
('zero', 'gpa', 'zero.gpa@student.edu', 'Male', 'Egyptian', 3, 0.0);

--4
create temporary table temp_course_stats as
select c.course_code, c.course_name, count(e.enrollment_id) as enrolled_count, avg(e.grade) as avg_grade
from courses c
left join enrollments e on c.course_id = e.course_id
group by c.course_id, c.course_code, c.course_name;

--5
create index idx_students_dept_id on students using btree (dept_id);

--6
create unique index idx_students_email on students (email);

insert into students (first_name, last_name, email, gender, nationality, dept_id, gpa) 
values ('duplicate', 'email', 'ahmed.hassan@student.edu', 'Male', 'Egyptian', 3, 3.00);

-- ERROR:  duplicate key value violates unique constraint "students_email_key"
-- Key (email)=(ahmed.hassan@student.edu) already exists.

--7
create index idx_professors_active_salary on professors (salary) where is_active = true;

--8
create view v_student_details as select s.student_id, s.first_name || ' ' || s.last_name as full_name, 
s.email, s.gpa, s.dept_id, d.dept_name, f.faculty_name from students s 
join departments d on s.dept_id = d.dept_id join faculties f on d.faculty_id = f.faculty_id;

select student_id, full_name, email, gpa, dept_name, faculty_name from v_student_details where dept_id = 3;

--9
create table enrollment_audit (audit_id serial primary key, 
enrollment_id integer, student_id integer, old_grade numeric(4,2), 
new_grade numeric(4,2), changed_at timestamptz default now(), 
changed_by text default current_user);

create or replace function log_enrollment_grade_change() 
returns trigger as 
$$ begin 
if new.grade is distinct from old.grade then 
insert into enrollment_audit (enrollment_id, student_id, old_grade, new_grade, changed_at, changed_by) 
values (old.enrollment_id, old.student_id, old.grade, new.grade, now(), current_user); 
end if; return new; end; 
$$ language plpgsql;

create trigger trg_enrollment_grade_audit
before update on enrollments
for each row
execute function log_enrollment_grade_change();

--10 
update enrollments set grade = 93 where enrollment_id = 1;

select audit_id, enrollment_id, student_id, old_grade, new_grade, changed_at, changed_by 
from enrollment_audit where enrollment_id = 1 order by audit_id desc;

update enrollments set grade = 93 where enrollment_id = 1;

select audit_id, enrollment_id, student_id, old_grade, new_grade, changed_at, changed_by 
from enrollment_audit where enrollment_id = 1 order by audit_id desc;

--11
create or replace function set_min_salary() returns trigger as $$
begin
    if new.salary is null or new.salary < 5000 then
        new.salary := 5000;
    end if;
    return new;
end;
$$ language plpgsql;

create trigger trg_set_min_salary
before insert on professors
for each row
execute function set_min_salary();

insert into professors (first_name, last_name, email, title, dept_id, salary) values 
('test', 'low', 'low.salary@uni.edu', 'Lecturer', 3, 2000);

select prof_id, first_name, last_name, salary 
from professors where email = 'low.salary@uni.edu';


--12
-- rollback;

create table if not exists salary_log (log_id serial primary key, 
prof_id integer, old_salary numeric, new_salary numeric, 
changed_by text default current_user, 
changed_at timestamptz default now());

begin;

insert into salary_log (prof_id, old_salary, new_salary)
select prof_id, salary, salary * 1.10
from professors
where dept_id = 1;

update professors
set salary = salary * 1.10
where dept_id = 1;

select prof_id, first_name, last_name, dept_id, salary 
from professors where dept_id = 1;

select log_id, prof_id, old_salary, new_salary, changed_by, changed_at 
from salary_log order by log_id desc;


commit;

--13
select * from enrollments where student_id = 1;

begin;
delete from enrollments where student_id = 1;
select * from enrollments where student_id = 1;
rollback;

select * from enrollments where student_id = 1;
--14
begin;

update faculties
set budget = budget + 500000
where faculty_id = 1;

savepoint after_faculty_1;

update faculties
set budget = budget + 500000
where faculty_id = 2;

rollback to savepoint after_faculty_1;

select faculty_id, faculty_name, budget from faculties where faculty_id in (1, 2);

commit;

--15
create role uni_readonly;

create role registrar_user;

grant select on students to uni_readonly;

grant uni_readonly to registrar_user;

set role registrar_user;

set role uni_readonly;

select student_id, first_name, last_name from students limit 5;

insert into students (first_name, last_name, email, gender, dept_id) 
values ('role', 'test', 'role.test@student.edu', 'Male', 3);

--ERROR:  permission denied for table students 

--16
create role uni_readwrite;
create role student_portal;

revoke delete on students from uni_readwrite;

select grantee, table_name, privilege_type from information_schema.role_table_grants 
where table_name = 'students' and grantee = 'uni_readwrite';

revoke all privileges on students from uni_readwrite;

select grantee, table_name, privilege_type from information_schema.role_table_grants 
where table_name = 'students' and grantee = 'uni_readwrite';

revoke uni_readonly from student_portal;

--17
-- pg_dump -U postgres -d university_db -F p -f university_db_full.sql
-- pg_dump -U postgres -d university_db --schema-only -F p -f university_db_schema.sql
-- pg_dump -U postgres -d university_db --data-only -F p -f university_db_data.sql

