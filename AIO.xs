#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <sys/types.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <sched.h>

#define STACKSIZE 1024 /* yeah */

enum { REQ_QUIT, REQ_READ, REQ_WRITE, REQ_OPEN, REQ_CLOSE };

typedef struct {
  char stack[STACKSIZE];
} aio_thread;

typedef struct {
  int type;
  aio_thread *thread;

/* read/write */
  int fd;
  off_t offset;
  size_t length;
  ssize_t result;
  mode_t mode; /* open */
  int errorno;
  SV *data, *callback;
  void *dataptr;
  STRLEN dataoffset;
} aio_cb;

typedef aio_cb *aio_req;

static int started;
static int nreqs;
static int reqpipe[2], respipe[2];

static int aio_proc(void *arg);

static void
start_thread(void)
{
  aio_thread *thr;

  New (0, thr, 1, aio_thread);

  if (clone (aio_proc,
             &(thr->stack[STACKSIZE]),
             CLONE_VM|CLONE_FS|CLONE_FILES|CLONE_SIGHAND,
             thr) >= 0)
    started++;
  else
    Safefree (thr);
}

static void
end_thread(void)
{
  aio_req req;
  New (0, req, 1, aio_cb);
  req->type = REQ_QUIT;
  write (reqpipe[1], &req, sizeof (aio_req));
}

static void
send_req (aio_req req)
{
  nreqs++;
  write (reqpipe[1], &req, sizeof (aio_req));
}

static void
read_write (pTHX_ int dowrite, int fd, off_t offset, size_t length,
            SV *data, STRLEN dataoffset, SV*callback)
{
  aio_req req;
  STRLEN svlen;
  char *svptr = SvPV (data, svlen);

  if (dataoffset < 0)
    dataoffset += svlen;

  if (dataoffset < 0 || dataoffset > svlen)
    croak ("data offset outside of string");

  if (dowrite)
    {
      /* write: check length and adjust. */
      if (length < 0 || length + dataoffset > svlen)
        length = svlen - dataoffset;
    }
  else
    {
      /* read: grow scalar as necessary */
      svptr = SvGROW (data, length + dataoffset);
    }

  if (length < 0)
    croak ("length must not be negative");

  New (0, req, 1, aio_cb);

  if (!req)
    croak ("out of memory during aio_req allocation");

  req->type = dowrite ? REQ_WRITE : REQ_READ;
  req->fd = fd;
  req->offset = offset;
  req->length = length;
  req->data = SvREFCNT_inc (data);
  req->dataptr = (char *)svptr + dataoffset;
  req->callback = SvREFCNT_inc (callback);

  send_req (req);
}

static int
poll_cb (pTHX)
{
  dSP;
  int count = 0;
  aio_req req;

  while (read (respipe[0], (void *)&req, sizeof (req)) == sizeof (req))
    {
      if (req->type == REQ_QUIT)
        {
          Safefree (req->thread);
          started--;
        }
      else
        {
          int errorno = errno;
          errno = req->errorno;

          if (req->type == REQ_READ)
            SvCUR_set (req->data, req->dataoffset
                                  + req->result > 0 ? req->result : 0);

          PUSHMARK (SP);
          XPUSHs (sv_2mortal (newSViv (req->result)));
          PUTBACK;
          call_sv (req->callback, G_VOID);
          SPAGAIN;
          
          SvREFCNT_dec (req->data);
          SvREFCNT_dec (req->callback);

          errno = errorno;
          nreqs--;
          count++;
        }

      Safefree (req);
    }

  return count;
}

static sigset_t fullsigset;

#undef errno
#include <asm/unistd.h>

static int
aio_proc(void *thr_arg)
{
  aio_thread *thr = thr_arg;
  aio_req req;
  int errno;

  /* we rely on gcc's ability to create closures. */
  _syscall3(int,lseek,int,fd,off_t,offset,int,whence)
  _syscall3(int,read,int,fd,char *,buf,off_t,count)
  _syscall3(int,write,int,fd,char *,buf,off_t,count)
  _syscall3(int,open,char *,pathname,int,flags,mode_t,mode)
  _syscall1(int,close,int,fd)

  sigprocmask (SIG_SETMASK, &fullsigset, 0);

  /* then loop */
  while (read (reqpipe[0], (void *)&req, sizeof (req)) == sizeof (req))
    {
      req->thread = thr;
      errno = 0;

      if (req->type == REQ_READ || req->type == REQ_WRITE)
        {
          if (lseek (req->fd, req->offset, SEEK_SET) == req->offset)
            {
              if (req->type == REQ_READ)
                req->result = read (req->fd, req->dataptr, req->length);
              else
                req->result = write(req->fd, req->dataptr, req->length);
            }
        }
      else if (req->type == REQ_OPEN)
        {
          req->result = open (req->dataptr, req->fd, req->mode);
        }
      else if (req->type == REQ_CLOSE)
        {
          req->result = close (req->fd);
        }
      else
        {
          write (respipe[1], (void *)&req, sizeof (req));
          break;
        }

      req->errorno = errno;
      write (respipe[1], (void *)&req, sizeof (req));
    }

  return 0;
}

MODULE = Linux::AIO                PACKAGE = Linux::AIO

BOOT:
{
        sigfillset (&fullsigset);
        sigdelset (&fullsigset, SIGTERM);
        sigdelset (&fullsigset, SIGQUIT);
        sigdelset (&fullsigset, SIGABRT);
        sigdelset (&fullsigset, SIGINT);

        if (pipe (reqpipe) || pipe (respipe))
          croak ("unable to initialize request or result pipe");

        if (fcntl (respipe[0], F_SETFL, O_NONBLOCK))
          croak ("cannot set result pipe to nonblocking mode");
}

void
min_parallel(nthreads)
	int	nthreads
	PROTOTYPE: $
        CODE:
        while (nthreads > started)
          start_thread ();

void
max_parallel(nthreads)
	int	nthreads
	PROTOTYPE: $
        CODE:
        int cur = started;
        while (cur > nthreads)
          {          
            end_thread ();
            cur--;
          }

        poll_cb ();
        while (started > nthreads)
          {
            sched_yield ();
            poll_cb ();
          }

void
aio_read(fh,offset,length,data,dataoffset,callback)
        PerlIO *	fh
        UV		offset
        STRLEN		length
        SV *		data
        STRLEN		dataoffset
        SV *		callback
	PROTOTYPE: $$$$$$
	ALIAS:
          aio_write = 1
	CODE:
        SvUPGRADE (data, SVt_PV);
        SvPOK_on (data);
        read_write (aTHX_ ix, PerlIO_fileno (fh), offset, length, data, dataoffset, callback);

void
aio_open(pathname,flags,mode,callback)
	char *	pathname
        int	flags
        int	mode
        SV *	callback
	PROTOTYPE: $$$$
	CODE:
        aio_req req;

        New (0, req, 1, aio_cb);

        if (!req)
          croak ("out of memory during aio_req allocation");

        req->type = REQ_OPEN;
        req->dataptr = pathname;
        req->fd = flags;
        req->mode = mode;
        req->callback = SvREFCNT_inc (callback);

        send_req (req);

void
aio_close(fh,callback)
        PerlIO *	fh
        SV *		callback
	PROTOTYPE: $
	CODE:
        aio_req req;

        New (0, req, 1, aio_cb);

        if (!req)
          croak ("out of memory during aio_req allocation");

        req->type = REQ_CLOSE;
        req->fd = PerlIO_fileno (fh);
        req->callback = SvREFCNT_inc (callback);

        send_req (req);

int
poll_fileno()
	PROTOTYPE:
	CODE:
        RETVAL = respipe[0];
	OUTPUT:
	RETVAL

int
poll_cb(...)
	PROTOTYPE:
	CODE:
        RETVAL = poll_cb (aTHX);
	OUTPUT:
	RETVAL

int
nreqs()
	PROTOTYPE:
	CODE:
        RETVAL = nreqs;
	OUTPUT:
	RETVAL

