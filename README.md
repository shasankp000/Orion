# Orion
An x86-64 kernel, built for the Limine bootloader.

The motivation behind this project is because I am simply tired of both Windows AND Linux

# Project Status

I just started building this after learning some basic x86-64 assembly lol.

# Calling conventions

```
RAX = syscall number
RBX = arg 1
RCX = arg 2
RDX = arg 3
RSI = arg 4
RDI = arg 5
RSP = stack // Provided by Limine, stays as is.

// remaining registers are free, safe, un-clobbered
```

The kernel has currently 4 syscalls. As of the moment a syscall table has been built into `.rodata` and a first test pass works
for calling `syscall #0`
