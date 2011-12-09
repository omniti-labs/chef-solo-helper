# Handlers

This directory contains code for any report/exception handlers you require.
For more information, see:
http://wiki.opscode.com/display/chef/Exception+and+Report+Handlers

By default, there is an updated resources handler that prints out a list of
resources that have changed (e.g. when a package was actually installed, or a
file was actually updated) at the end of the chef run, making it much easier
to see what chef actually did during a given run.

## Adding new handlers

Just drop the handler code in here. The solo.rb file will include any .rb
files it finds.

Site specific handlers should go in the site/ directory.

However, handlers aren't enabled by default, you will need to add code to your
handler to do so. For example:

    # Automatically enable the handler
    Chef::Config.send("report_handlers") << MyHandler::Handler.new
    Chef::Config.send("exception_handlers") << MyHandler::Handler.new
