=head1 NAME

Linux::AIO - linux-specific aio implemented using clone

=head1 SYNOPSIS

 use Linux::AIO;

=head1 DESCRIPTION

This module implements asynchroneous i/o using the means available to
linux - clone. It does not hook into the POSIX aio_* functions because
linux does not yet support these in the kernel. Instead, a number of
threads are started that execute your read/writes and signal their
completion.

=over 4

=cut

package Linux::AIO;

use base 'Exporter';

BEGIN {
   $VERSION = 0.111;

   @EXPORT = qw(aio_read aio_write aio_open aio_close aio_stat aio_lstat);
   @EXPORT_OK = qw(poll_fileno poll_cb min_parallel max_parallel nreqs);

   require XSLoader;
   XSLoader::load Linux::AIO, $VERSION;
}

=item Linux::AIO::min_parallel($nthreads)

Set the minimum number of AIO threads to $nthreads. You I<have> to call
this function with a positive number at leats once, otherwise no threads
will be started and you aio-operations will seem to hang.

=item $fileno = Linux::AIO::poll_fileno

Return the request result pipe filehandle. This filehandle must be polled
for reading. If the pipe becomes readable you have to call C<poll_cb>.

=item Linux::AIO::poll_cb

Process all outstanding events on the result pipe. You have to call this
regularly. Returns the number of events processed.

You can use Event to multiplex, e.g.:

   Event->io(fd => Linux::AIO::poll_fileno,
             poll => 'r', async => 1,
             cb => \&Linux::AIO::poll_cb );


=item Linux::AIO::nreqs

Returns the number of requests currently outstanding.

=item aio_open($pathname, $flags, $mode, $callback)

Asynchronously open or create a file and call the callback with the
filedescriptor.

=item aio_close($fh, $callback)

Asynchronously close a file and call the callback with the result code.

=item aio_read($fh,$offset,$length, $data,$dataoffset,$callback)

=item aio_write($fh,$offset,$length, $data,$dataoffset,$callback)

Reads or writes C<length> bytes from the specified C<fh> and C<offset>
into the scalar given by C<data> and offset C<dataoffset> and calls the
callback without the actual number of bytes read (or undef on error).

=item aio_stat($fh_or_path,$callback)

=item aio_lstat($fh,$callback)

Works like perl's C<stat> or C<lstat> in void context, i.e. the callback
will be called after the stat and the results will be available using
C<stat _> or C<-s _> etc...

Currently, the stats are always 64-bit-stats, i.e. instead of returning an
error when stat'ing a large file, the results will be silently truncated
unless perl itself is compiled with large file support.

=cut

END {
   max_parallel 0;
}

1;

=back

=head1 BUGS

This module has not yet been extensively tested. Watch out!

   - perl-threads/fork interaction poorly tested.
   - aio_open gives a fd, but all other functions expect a filehandle.

=head1 SEE ALSO

L<Coro>.

=head1 AUTHOR

 Marc Lehmann <pcg@goof.com>
 http://www.goof.com/pcg/marc/

=cut

