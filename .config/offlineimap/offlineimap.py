"""A function for looking up a generic password in the login keychain."""

import subprocess


def get_macos_keychain_password(user, host):
    """Get the password for *user* at *host*."""
    params = {
        'bin': '/usr/bin/security',
        'command': 'find-generic-password',
        'account': user,
        'server': host,
        'keychain': '~/Library/Keychains/login.keychain',
    }
    command = '{bin} {command} -gw -a {account} -s {server} {keychain}'.format(
        **params)
    return subprocess.check_output(
        command, shell=True, stderr=subprocess.STDOUT).decode().strip('\n')
