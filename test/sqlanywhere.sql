CREATE TABLE accounts (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  firm_id int NULL,
  credit_limit int NULL
)

CREATE TABLE funny_jokes (
id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  name varchar(50) NULL
)

CREATE TABLE companies (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  type varchar(50) NULL,
  ruby_type varchar(50) NULL,
  firm_id int NULL,
  name varchar(50) NULL,
  client_of int NULL,
  rating int default 1
)


CREATE TABLE topics (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  title varchar(255) NULL,
  author_name varchar(255) NULL,
  author_email_address varchar(255) NULL,
  written_on datetime NULL,
  bonus_time time NULL,
  last_read date NULL,
  content varchar(255) NULL,
  approved tinyint default 1,
  replies_count int default 0,
  parent_id int NULL,
  type varchar(50) NULL
)

CREATE TABLE developers (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  name varchar(100) NULL,
  salary int default 70000,
  created_at datetime NULL,
  updated_at datetime NULL
)

CREATE TABLE projects (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  name varchar(100) NULL,
  type varchar(255) NULL
)

CREATE TABLE developers_projects (
  developer_id int NOT NULL,
  project_id int NOT NULL,
  joined_on datetime NULL,
  access_level smallint default 1
)

CREATE TABLE orders (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  name varchar(100) NULL,
  billing_customer_id int NULL,
  shipping_customer_id int NULL
)

CREATE TABLE customers (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  name varchar(100) NULL,
  balance int default 0,
  address_street varchar(100) NULL,
  address_city varchar(100) NULL,
  address_country varchar(100) NULL,
  gps_location varchar(100) NULL
)

CREATE TABLE movies (
  movieid integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  name varchar(100) NULL
)

CREATE TABLE subscribers (
  nick varchar(100) PRIMARY KEY,
  name varchar(100) NULL
)

CREATE TABLE booleantests (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  value int NULL
)

CREATE TABLE auto_id_tests (
  auto_id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  value int NULL
)

CREATE TABLE entrants (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  name varchar(255) NOT NULL,
  course_id int NOT NULL
)

CREATE TABLE colnametests (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  [references] int NOT NULL
)

CREATE TABLE mixins (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  parent_id int NULL,
  pos int NULL,
  created_at datetime NULL,
  updated_at datetime NULL,
  lft int NULL,
  rgt int NULL,
  root_id int NULL,
  type varchar(40) NULL
)

CREATE TABLE people (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  first_name varchar(40) NULL,
  lock_version int DEFAULT 0
)

CREATE TABLE readers (
    id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
    post_id int NOT NULL,
    person_id int NOT NULL
)

CREATE TABLE binaries (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  data long binary NULL
)

CREATE TABLE computers (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  developer int NOT NULL,
  extendedWarranty int NOT NULL
)

CREATE TABLE posts (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  author_id int NULL,
  title varchar(255) NOT NULL,
  body varchar(2048) NOT NULL,
  type varchar(255) DEFAULT NULL
)

CREATE TABLE comments (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  post_id int NOT NULL,
  body varchar(2048) NOT NULL,
  type varchar(255) NOT NULL
)

CREATE TABLE authors (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  name varchar(255) NOT NULL
)

CREATE TABLE tasks (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  starting datetime NULL,
  ending datetime NULL
)

CREATE TABLE categories (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  name varchar(255) NOT NULL,
  type varchar(255) NOT NULL
)

CREATE TABLE categories_posts (
  category_id int NOT NULL,
  post_id int NOT NULL
)

CREATE TABLE fk_test_has_pk (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY
)

CREATE TABLE fk_test_has_fk (
  id    integer PRIMARY KEY,
  fk_id integer NOT NULL,

  FOREIGN KEY (fk_id) REFERENCES fk_test_has_pk(id)
)


CREATE TABLE keyboards (
  key_number integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  name varchar(50) NULL
)

--This table has an altered lock_version column name.
CREATE TABLE legacy_things (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  tps_report_number int default NULL,
  version int default 0
)


CREATE TABLE numeric_data (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  bank_balance numeric(10,2),
  big_bank_balance numeric(15,2),
  world_population numeric(10),
  my_house_population numeric(2),
  decimal_number_with_default numeric(3,2) DEFAULT 2.78
)

CREATE TABLE mixed_case_monkeys (
  monkeyID integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY,
  fleaCount integer
);

CREATE TABLE minimalistics (
  id integer DEFAULT AUTOINCREMENT NOT NULL PRIMARY KEY
);

go
