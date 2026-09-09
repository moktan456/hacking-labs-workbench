USE corpdb;

CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50),
  email VARCHAR(100),
  role VARCHAR(50)
);

INSERT INTO users (username, email, role) VALUES
  ('jsmith', 'jsmith@cybercorp.local', 'network_admin'),
  ('mrodriguez', 'mrodriguez@cybercorp.local', 'db_admin'),
  ('svc_backup', 'svc_backup@cybercorp.local', 'service_account');

CREATE TABLE notes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  note VARCHAR(255)
);

INSERT INTO notes (note) VALUES
  ('flag{lab5_mysql_app_credentials_enumerated}'),
  ('reminder: rotate dbuser password after the Q1 audit');
