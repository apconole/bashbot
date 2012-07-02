#!/bin/bash

write_ccfile_preamble() {
  COUTFILE="$1"

  $CAT_BIN > ${COUTFILE}.cc <<EOF
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>
#include <string.h>
#include <pthread.h>
#include <iostream>
#include <vector>
#include <map>
#include <valarray>
#include <string>
#include <iomanip>
#include <algorithm>
#include <list>
#include <set>
#include <sstream>
#include <stack>

using namespace std;

EOF

}

write_ptrace_watcher() {
  COUTFILE="$1"

  $CAT_BIN >${COUTFILE}.cc <<EOF
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>
#include <string.h>
#include <sys/ptrace.h>
#include <sys/wait.h>
#include <assert.h>
#include <pthread.h>
#include <iostream>
#include <vector>
#include <map>
#include <valarray>
#include <string>
#include <iomanip>
#include <algorithm>
#include <list>
#include <set>
#include <sstream>
#include <fstream>
#include <stack>

#include <assert.h>
#include <sys/ptrace.h>
#include <linux/ptrace.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
//#include <linux/user.h>
#include <sys/syscall.h>
#include <sys/reg.h>
#include <stdio.h>
#include <stdlib.h>

#include <sys/time.h>
#include <sys/resource.h>

#include <sys/user.h>

#ifdef __x86_64__
#define SYSCALL_OFF (ORIG_RAX * 8)
#define REGISTER(a,b) b
#else
#define SYSCALL_OFF (ORIG_EAX * 4)
#define REGISTER(a,b) a
#endif

using namespace std;

extern int APP_TMP_MAIN_main();

struct syscalls_blocked 
{
  int syscall;
  char *errorcall;
} blocked[300], spied[300];

#define STRINGIFY(a) STRING(#a)
#define STRING(a) #a

#define BLOCK_SYSCALL(a) { blocked[a].errorcall = #a ; blocked[a].syscall=a; }
#define SPY_SYSCALL(a) { spied[a].errorcall = #a ; spied[a].syscall=a; }

#define LIMIT(a, b, c) { rlimit kLimit; kLimit.rlim_cur = b; kLimit.rlim_max = c; if ( setrlimit( a, &kLimit ) < 0 ) { perror("setrlimit"); abort(); } }

int main(int argc, char *argv[])
{
    memset( &blocked, 0, sizeof(blocked));

    int i = 0;
    BLOCK_SYSCALL(__NR_clone);
    BLOCK_SYSCALL(__NR_fork);
    BLOCK_SYSCALL(__NR_vfork);
    BLOCK_SYSCALL(__NR_execve);
    BLOCK_SYSCALL(__NR_kill);
    BLOCK_SYSCALL(__NR_rt_sigaction);
    BLOCK_SYSCALL(__NR_rt_sigprocmask);
    BLOCK_SYSCALL(__NR_rt_sigreturn);
    BLOCK_SYSCALL(__NR_ioctl);
    BLOCK_SYSCALL(__NR_shmget);
    BLOCK_SYSCALL(__NR_shmat);
    BLOCK_SYSCALL(__NR_shmctl);
    BLOCK_SYSCALL(__NR_setitimer);
    BLOCK_SYSCALL(__NR_socket);
    BLOCK_SYSCALL(__NR_sendfile);
    BLOCK_SYSCALL(__NR_semget);
    BLOCK_SYSCALL(__NR_creat);
    BLOCK_SYSCALL(__NR_rmdir);
    BLOCK_SYSCALL(__NR_link);
    BLOCK_SYSCALL(__NR_unlink);
    BLOCK_SYSCALL(__NR_ptrace);
    BLOCK_SYSCALL(__NR_syslog);
    BLOCK_SYSCALL(__NR_setuid);
    BLOCK_SYSCALL(__NR_setgid);
    BLOCK_SYSCALL(__NR_setpgid);
    BLOCK_SYSCALL(__NR_setsid);
    BLOCK_SYSCALL(__NR_setresuid);
    BLOCK_SYSCALL(__NR_setresgid);
    BLOCK_SYSCALL(__NR_setfsuid);
    BLOCK_SYSCALL(__NR_setfsgid);
    BLOCK_SYSCALL(__NR_capset);
    BLOCK_SYSCALL(__NR_personality);
    BLOCK_SYSCALL(__NR_setpriority);
    BLOCK_SYSCALL(__NR_sched_setparam);
    BLOCK_SYSCALL(__NR_sched_setscheduler);
    BLOCK_SYSCALL(__NR_mknod);
    BLOCK_SYSCALL(__NR_chroot);
    BLOCK_SYSCALL(__NR__sysctl);
    BLOCK_SYSCALL(__NR_settimeofday);
    BLOCK_SYSCALL(__NR_mount);
    BLOCK_SYSCALL(__NR_setrlimit);
    BLOCK_SYSCALL(__NR_umount2);
    BLOCK_SYSCALL(__NR_reboot);

    //SPY_SYSCALL(__NR_open);

    if ( argc > 1 )
      return APP_TMP_MAIN_main();

    setsid();

    pid_t childID = fork();

    if( ! childID )
    {
        LIMIT( RLIMIT_CPU, 2, 2 ); 
        LIMIT( RLIMIT_FSIZE, 65535, 65535 );
        LIMIT( RLIMIT_NOFILE, 24, 25 );
        LIMIT( RLIMIT_NPROC, 4, 4 );
        LIMIT( RLIMIT_MSGQUEUE, 0, 0 );
        LIMIT( RLIMIT_LOCKS, 0, 0 );
        LIMIT( RLIMIT_AS, 1024 * 1024 * 32, 1024 * 1024 * 64 );

        ptrace(PTRACE_TRACEME, 0, NULL, NULL); /* trace me */
        execlp(argv[0], argv[0], "RUN", NULL);
        return 0;
    }

    if( childID < 0 )
    {
        cout << "FAILED: ptrace/fork error" << endl;
        return 0;
    }

    int status;
    wait (&status);

    if ( WIFEXITED(status) )
       return 0;

    assert( WIFSTOPPED(status) && WSTOPSIG(status) == SIGTRAP );

    assert( ptrace(PTRACE_SETOPTIONS, childID, NULL, PTRACE_O_TRACESYSGOOD) != -1 );

    do
    {
       assert( ptrace(PTRACE_SYSCALL, childID, NULL, NULL) != -1 );
       assert( wait(&status) != -1 );

       if (WIFEXITED(status)) break;

       if (WSTOPSIG(status) == (SIGTRAP | 0x80))
       {
           long syscallnum = ptrace(PTRACE_PEEKUSER, childID, SYSCALL_OFF, NULL);
           if ( syscallnum && syscallnum < 300 && blocked[syscallnum].syscall==syscallnum )
           {
               cout << "Killed:" 
                    << " [0x" << hex << syscallnum << dec << "] "
                    << blocked[syscallnum].errorcall 
                    << endl;
               kill(childID, SIGKILL);
               exit(0);
               break;
           }
           else if ( syscallnum && syscallnum < 300 && spied[syscallnum].syscall==syscallnum)
           {
               user_regs_struct regs;
               ptrace(PTRACE_GETREGS, childID, NULL, &regs);
               long arg1 = regs. REGISTER(ebx,rbx) ;
               long arg2 = regs. REGISTER(ecx,rcx) ;
               long arg3 = regs. REGISTER(edx,rdx) ;
               long arg4 = regs. REGISTER(eax,rax) ;
               cout << "Spy: " << spied[syscallnum].errorcall << hex
                    << " [ " << arg1 << " ], " << " [ " << arg2 << " ], "
                    << " [ " << arg3 << " ], " << " [ " << arg4 << " ], "
                    << endl;
           }
       }
       else
       {
           assert( WSTOPSIG(status) == SIGTRAP );
           cout << "Non-syscall trap" << endl;
       }
       
    }while(1);

    return 0;
}

EOF

}
