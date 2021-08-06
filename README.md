# act

## Overview

**act** [ **-hv** ] [ **-C** _directory_ ] [ **-H** _file_ ]
    [ **-M** _directory_ ] [ **-l** _file_ ] [ **-p** _method_ ]
    [ **-u** _user_ ] [ [_user_**@**]_host_ ]...

**act** is a tool for automated configuration of remote hosts. It's pretty dumb.
It attempts to only depend on
[**rsync**(1)](https://download.samba.org/pub/rsync/rsync.1),
[**sh**(1)](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/sh.html),
[**ssh**(1)](https://man.openbsd.org/ssh.1),
and utilities specified by [POSIX.1-2017](https://pubs.opengroup.org/onlinepubs/9699919799/).
Additionally, [**nc**(1)](https://man.openbsd.org/nc.1) is used to allow
logging from the remote side if it is available.

Execution of act involves two main phases:

1. Copying a set of files to a temporary directory on the remote, specified in
   the file _hostname_**.files.conf**.
2. Copying a set of executable scripts, referred to as "modules", to the remote
   and executing them within the temporary directory. These modules and their
   arguments are specified in the file _hostname_**.modules.conf**.

Hosts may be specified on the command line. Otherwise, they are read from a
**hosts** file, one per line.
