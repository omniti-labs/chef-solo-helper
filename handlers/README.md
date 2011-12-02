# Handlers

This directory contains code for any report/exception handlers you require.
For more information, see:
http://wiki.opscode.com/display/chef/Exception+and+Report+Handlers

By default, there is an updated resources handler that prints out a list of
resources that have changed (e.g. when a package was actually installed, or a
file was actually updated) at the end of the chef run, making it much easier
to see what chef actually did during a given run.
