=head1 NAME

Linux::AIO - linux-specific aio implemented using clone

=head1 SYNOPSIS

 use Linux::AIO;

=head1 DESCRIPTION

This module implements asynchronous i/o using the means available to linux
- clone. It does not hook into the POSIX aio_* functions because linux
does not yet support these in the kernel (and even if, it would only allow
aio_read and write, not open and stat).

Instead, in this module a number of (non-posix) threads are started that
execute your read/writes and signal their completion. You don't need
thread support in your libc or perl, and the threads created by this
module will not be visible to the pthreads library.

NOTICE: the threads created by this module will automatically be killed
when the thread calling min_parallel exits. Make sure you only ever call
min_parallel from the same thread that loaded this module.

Although the module will work with threads, it is not reentrant, so use
appropriate locking yourself.

=over 4

=cut

package Linux::AIO;

use base 'Exporter';

BEGIN {
   $VERSION = 1.4;

   @EXPORT = qw(aio_read aio_write aio_open aio_close aio_stat aio_lstat aio_unlink);
   @EXPORT_OK = qw(poll_fileno poll_cb min_parallel max_parallel nreqs);

   require XSLoader;
   XSLoader::load Linux::AIO, $VERSION;
}

=item Linux::AIO::min_parallel $nthreads

Set the minimum number of AIO threads to C<$nthreads>. The default is
C<1>, which means a single asynchronous operation can be done at one time
(the number of outstanding operations, however, is unlimited).

It is recommended to keep the number of threads low, as many linux
kernel versions will scale negatively with the number of threads (higher
parallelity => MUCH higher latency).

=item $fileno = Linux::AIO::poll_fileno

Return the I<request result pipe filehandle>. This filehandle must be
polled for reading by some mechanism outside this module (e.g. Event
or select, see below). If the pipe becomes readable you have to call
C<poll_cb> to check the results.

=item Linux::AIO::poll_cb

Process all outstanding events on the result pipe. You have to call this
regularly. Returns the number of events processed. Returns immediately
when no events are outstanding.

You can use Event to multiplex, e.g.:

   Event->io (fd => Linux::AIO::poll_fileno,
              poll => 'r', async => 1,
              cb => \&Linux::AIO::poll_cb );


=item Linux::AIO::nreqs

Returns the number of requests currently outstanding.

=item aio_open  $pathname, $flags, $mode, $callback

Asynchronously open or create a file and call the callback with the
filedescriptor (NOT a perl filehandle, sorry for that, but watch out, this
might change in the future).

=item aio_close $fh, $callback

Asynchronously close a file and call the callback with the result code.

=item aio_read  $fh,$offset,$length, $data,$dataoffset,$callback

=item aio_write $fh,$offset,$length, $data,$dataoffset,$callback

Reads or writes C<length> bytes from the specified C<fh> and C<offset>
into the scalar given by C<data> and offset C<dataoffset> and calls the
callback without the actual number of bytes read (or C<undef> on error).

=item aio_stat  $fh_or_path, $callback

=item aio_lstat $fh, $callback

Works like perl's C<stat> or C<lstat> in void context. The callback will
be called after the stat and the results will be available using C<stat _>
or C<-s _> etc...

Currently, the stats are always 64-bit-stats, i.e. instead of returning an
error when stat'ing a large file, the results will be silently truncated
unless perl itself is compiled with large file support.

=item aio_unlink  $pathname, $callback

Asynchronously unlink a file.

=cut

min_parallel 1;

END {
   max_parallel 0;
}

1;

=back

=head1 BUGS

This module has been extensively tested in a large and very busy webserver
for many years now.

   - aio_open gives a fd, but all other functions expect a perl filehandle.

=head1 SEE ALSO

L<Coro>.

=head1 AUTHOR

 Marc Lehmann <pcg@goof.com>
 http://home.schmorp.de/

=cut

