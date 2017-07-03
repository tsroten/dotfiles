"""Customize the interactive Python interpreter on startup."""
import os
import atexit
import readline

# Use XDG data directory for history file.
readline_history_file = os.path.expanduser(os.path.join(
    os.environ['XDG_DATA_HOME'], 'python', 'history'))
try:
    readline.read_history_file(readline_history_file)
except IOError:
    pass
atexit.register(readline.write_history_file, readline_history_file)
