USE internaldb;

CREATE TABLE notes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  note VARCHAR(255)
);

INSERT INTO notes (note) VALUES
  ('flag{lab9_port_forward_reached_internal_db}'),
  ('reminder: this database should never be reachable from outside the internal subnet');
