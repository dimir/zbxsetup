.zbx

General file to handle script parameters. Allows to choose database
(PostgreSQL or MySQL), version (1.8 or 2.0) and sets some variables
accordingly (e. g. DBUser="root" in case of MySQL).

cnf-setup.sh

Set up Zabbix configuration files in /etc/zabbix/* (DB* parameters +
additional, if specified).

conf.sh

Run ./configure with basic options.

db-exec.sh

Execute db query.

db-setup.sh

Set up database. Deletes all data and recreates everything from schema.

restart_zabbix_server.sh

Restart all Zabbix processes. Restarts also proxy if '-p' options specified.
