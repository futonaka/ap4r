CREATE TABLE reliable_msg_queues (
  id character varying(255) NOT NULL default '',
  queue character varying(255) NOT NULL default '',
  headers text NOT NULL,
  object text NOT NULL,
  PRIMARY KEY  (id)
);
CREATE TABLE reliable_msg_topics (
  topic character varying(255) NOT NULL default '',
  headers text NOT NULL,
  object text NOT NULL,
  PRIMARY KEY  (topic)
);
