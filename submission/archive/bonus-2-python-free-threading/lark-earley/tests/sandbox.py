"""Public execution boundary. Expected answers and clocks live in the parent."""

import ctypes
import errno
from typing import ClassVar


def restrict() -> None:
    """Block subprocesses, network, tracing, and affinity changes; retain threads."""
    library = ctypes.CDLL("libseccomp.so.2", use_errno=True)
    library.seccomp_init.argtypes = [ctypes.c_uint32]
    library.seccomp_init.restype = ctypes.c_void_p
    library.seccomp_syscall_resolve_name.argtypes = [ctypes.c_char_p]
    library.seccomp_syscall_resolve_name.restype = ctypes.c_int
    library.seccomp_rule_add.argtypes = [
        ctypes.c_void_p,
        ctypes.c_uint32,
        ctypes.c_int,
        ctypes.c_uint,
    ]
    library.seccomp_load.argtypes = [ctypes.c_void_p]
    library.seccomp_release.argtypes = [ctypes.c_void_p]
    context = library.seccomp_init(0x7FFF0000)  # SCMP_ACT_ALLOW
    if not context:
        raise RuntimeError("seccomp_init failed")
    for name in (
        "fork",
        "vfork",
        "execve",
        "execveat",
        "socket",
        "connect",
        "ptrace",
        "process_vm_readv",
        "process_vm_writev",
        "sched_setaffinity",
        "setns",
        "unshare",
    ):
        syscall = library.seccomp_syscall_resolve_name(name.encode())
        if syscall >= 0 and library.seccomp_rule_add(context, 0x50000 | errno.EPERM, syscall, 0) != 0:
            raise RuntimeError(f"Cannot block {name}")
    # glibc falls back to clone when clone3 returns ENOSYS.
    syscall = library.seccomp_syscall_resolve_name(b"clone3")
    if syscall >= 0 and library.seccomp_rule_add(context, 0x50000 | errno.ENOSYS, syscall, 0) != 0:
        raise RuntimeError("Cannot block clone3")

    class Comparison(ctypes.Structure):
        _fields_: ClassVar = [
            ("arg", ctypes.c_uint),
            ("op", ctypes.c_int),
            ("datum_a", ctypes.c_uint64),
            ("datum_b", ctypes.c_uint64),
        ]

    library.seccomp_rule_add_array.argtypes = [
        ctypes.c_void_p,
        ctypes.c_uint32,
        ctypes.c_int,
        ctypes.c_uint,
        ctypes.POINTER(Comparison),
    ]
    # Reject clone unless CLONE_THREAD is set (masked equality to zero).
    comparison = Comparison(0, 7, 0x10000, 0)
    syscall = library.seccomp_syscall_resolve_name(b"clone")
    if library.seccomp_rule_add_array(context, 0x50000 | errno.EPERM, syscall, 1, ctypes.byref(comparison)) != 0:
        raise RuntimeError("Cannot restrict clone")
    if library.seccomp_load(context) != 0:
        raise RuntimeError("seccomp_load failed")
    library.seccomp_release(context)
