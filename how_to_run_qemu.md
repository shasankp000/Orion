To run qemu with gdb attached:

```sh
qemu-system-x86_64 -cdrom orion_v0.1.iso -s -S
```

and then in another shell:

```sh
gdb kernel_name.elf
```

Inside gdb:

```sh
gdb> target remote localhost:1234
gdb> break _start:
gdb> continue
```

---

And to just run the iso plain in qemu

```sh
qemu-system-x86_64 -cdrom orion_v0.1.iso
```
