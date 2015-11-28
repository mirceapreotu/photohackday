# -*- mode: ruby -*-
# vi: set ft=ruby :

# The directory to operate out of.
#
# The default is the current directory.
#
directory '/srv/www/relevantmail'


# Load “path” as a rackup file.
#
# The default is “config.ru”.
#
rackup '/srv/www/relevantmail/config.ru'


# Set the environment in which the rack's app will run. The value must be a string.
#
# The default is “development”.
#
environment 'production'


# Daemonize the server into the background. Highly suggest that
# this be combined with “pidfile” and “stdout_redirect”.
#
# The default is “false”.
#
daemonize true


# Store the pid of the server in the file at "path".
#
pidfile '/srv/www/relevantmail/pids/relevantmail.pid'


# Use “path” as the file to store the server info state. This is
# used by “pumactl” to query and control the server.
#
state_path '/srv/www/relevantmail/sockets/relevantmail.state'


# Redirect STDOUT and STDERR to files specified. The 3rd parameter
# (“append”) specifies whether the output is appended, the default is
# “false”.
#
stdout_redirect '/srv/www/relevantmail/log/stdout.log', '/srv/www/relevantmail/log/stderr.log', true

# Disable request logging.
#
# The default is “false”.
#
# quiet false


# Configure “min” to be the minimum number of threads to use to answer
# requests and “max” the maximum.
#
# The default is “0, 16”.
#
threads 8, 16


# How many worker processes to run.
#
# The default is “0”.
#
workers 8

preload_app!

# Bind the server to “url”. “tcp://”, “unix://” and “ssl://” are the only
# accepted protocols.
#
# The default is “tcp://0.0.0.0:9292”.
#
bind 'unix:///srv/www/relevantmail/sockets/relevantmail.sock'


# Code to run before doing a restart. This code should
# close log files, database connections, etc.
#
# This can be called multiple times to add code each time.
#
on_restart do
  puts 'On restart...'

end


# Code to run when a worker boots to setup the process before booting
# the app.
#
# This can be called multiple times to add hooks.
#
on_worker_boot do
  puts 'On worker boot...'

end

# === Puma control rack application ===

# Start the puma control rack application on “url”. This application can
# be communicated with to control the main server. Additionally, you can
# provide an authentication token, so all requests to the control server
# will need to include that token as a query parameter. This allows for
# simple authentication.
#
# Check out https://github.com/puma/puma/blob/master/lib/puma/app/status.rb
# to see what the app has available.
#
# activate_control_app 'unix:///var/run/pumactl.sock'
# activate_control_app 'unix:///var/run/pumactl.sock', { auth_token: '12345' }
# activate_control_app 'unix:///var/run/pumactl.sock', { no_token: true }