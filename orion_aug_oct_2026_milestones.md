# Orion -- August–October 2026 Milestone Roadmap

## August 2026 -- CPU Foundation

**Primary objective:** Finish establishing Orion's x86-64 CPU execution environment.

### TSS

- [x] Finish TSS implementation
- [x] Install/load the TSS with `ltr`
- [x] Verify the TSS descriptor and contents in GDB
- [x] Verify the CPU accepts the TSS
- [x] Verify the kernel stack mechanism associated with the TSS
- [x] Commit a clean, verified implementation

**Milestone:** Orion has a verified x86-64 TSS implementation.

### GDT

- [x] Finalize kernel code segment
- [x] Finalize kernel data segment
- [x] Add/prepare user code segment
- [x] Add/prepare user data segment
- [x] Add TSS descriptor
- [x] Properly load the GDT
- [ ] Configure segment registers
- [ ] Document Orion's GDT layout

### IDT

- [x] Finalize IDT structure
- [x] Configure IDTR
- [x] Implement interrupt gate representation
- [ ] Implement generic IDT entry installation
- [ ] Implement assembly interrupt entry mechanism
- [ ] Design register-save frame
- [x] Implement `iretq` return path

### CPU Exceptions

- [ ] Divide-by-zero
- [ ] Debug exception
- [ ] Breakpoint
- [ ] Invalid opcode
- [ ] General protection fault
- [ ] Page fault
- [ ] Double fault
- [ ] Basic exception reporting
- [ ] Kernel panic/halt path

### August Finish Line

- [ ] Bootloader → 64-bit entry
- [ ] Stack established
- [ ] GDT initialized
- [ ] TSS initialized
- [ ] IDT initialized
- [ ] CPU exceptions handled
- [ ] Reliable kernel panic/diagnostic path

> **August milestone:** Orion owns its CPU execution environment.

---

## September 2026 -- Memory Foundation

**Primary objective:** Make Orion take ownership of physical and virtual memory.

### Bootloader Memory Map

- [ ] Understand the memory-map structure supplied by the boot protocol
- [ ] Enumerate memory regions
- [ ] Identify usable RAM
- [ ] Identify reserved regions
- [ ] Protect bootloader structures
- [ ] Protect framebuffer memory
- [ ] Implement memory-map diagnostic output

Example target:

```text
ORION MEMORY MAP
----------------
00000000 - 0009FFFF  usable
000A0000 - 000FFFFF  reserved
00100000 - ........  usable
...
```

### Physical Page-Frame Allocator

- [ ] Define physical-page representation
- [ ] Implement page-frame bitmap
- [ ] Initialize allocator from memory map
- [ ] Implement `alloc_page()`
- [ ] Implement `free_page()`
- [ ] Implement page reservation
- [ ] Test allocation/release behaviour
- [ ] Test allocator against fragmented regions

### Paging

- [ ] Understand the page tables supplied by the bootloader
- [ ] Understand PML4
- [ ] Understand PDPT
- [ ] Understand PD
- [ ] Understand PT
- [ ] Define Orion's initial virtual-address layout
- [ ] Build Orion page tables
- [ ] Load Orion's page tables into `CR3`
- [ ] Verify virtual → physical mappings
- [ ] Implement page-fault handling
- [ ] Test intentional page faults

### Kernel Heap

- [ ] Define kernel virtual heap region
- [ ] Implement basic heap allocator
- [ ] Implement `kmalloc()`
- [ ] Implement `kfree()`
- [ ] Handle alignment
- [ ] Test fragmentation
- [ ] Replace appropriate static allocations with heap allocations

### September Finish Line

- [ ] Bootloader memory map consumed
- [ ] Physical page allocator working
- [ ] Physical memory reservation working
- [ ] Orion page tables established
- [ ] Virtual memory operational
- [ ] Page faults handled
- [ ] Kernel heap operational
- [ ] `kmalloc()` / `kfree()` verified

> **September milestone:** Orion owns its memory.

---

## October 2026 -- Execution Foundation

**Primary objective:** Give Orion the ability to respond to hardware events and run multiple kernel execution contexts.

### Interrupt Architecture

- [ ] Separate legacy PIC/PIT implementation from generic interrupt infrastructure
- [ ] Define generic interrupt-controller interface
- [ ] Define generic timer interface
- [ ] Keep legacy PIC/PIT support isolated
- [ ] Design architecture/platform-specific interrupt implementations

Target architecture:

```text
Kernel
 │
 ├── Interrupt subsystem
 │
 └── Timer subsystem
        │
        ├── Legacy PIC/PIT
        │
        └── Future APIC/other implementations
```

### Hardware Interrupts

- [ ] Implement IRQ abstraction
- [ ] Implement IRQ registration
- [ ] Implement IRQ dispatch
- [ ] Implement interrupt masking/unmasking
- [ ] Implement interrupt acknowledgement
- [ ] Implement timer interrupt
- [ ] Implement keyboard interrupt

Target:

```text
Hardware
   ↓
IRQ
   ↓
Assembly entry
   ↓
C dispatcher
   ↓
Registered handler
```

### Kernel Timing

- [ ] Initialize timer
- [ ] Implement kernel tick counter
- [ ] Implement basic delay mechanism
- [ ] Implement interrupt-driven time progression

Example:

```c
uint64_t orion_ticks;
```

### Kernel Threads

- [ ] Define thread structure
- [ ] Implement kernel stack per thread
- [ ] Implement thread creation
- [ ] Implement thread termination
- [ ] Define CPU context structure
- [ ] Implement initial thread context construction

Target:

```text
Thread A
   │
   ▼
Thread B
   │
   ▼
Thread C
```

### Context Switching

- [ ] Design context-switch ABI
- [ ] Implement low-level context structure
- [ ] Implement assembly `switch_context()` routine
- [ ] Save required CPU state
- [ ] Switch kernel stack
- [ ] Restore required CPU state
- [ ] Return into new thread

Target:

```text
C
 │
Scheduler
 │
 └── switch_context()
          │
          ▼
        ASM
          │
      save state
          │
      switch RSP
          │
      restore state
          │
          ▼
      New thread
```

### Scheduling

- [ ] Implement basic scheduler
- [ ] Implement cooperative scheduling
- [ ] Test switching between multiple kernel threads
- [ ] Implement timer-driven scheduling
- [ ] Implement preemptive scheduling if the preceding infrastructure is stable

### October Finish Line

- [ ] Generic IRQ infrastructure operational
- [ ] Timer interrupt operational
- [ ] Keyboard interrupt operational
- [ ] Kernel time/ticks operational
- [ ] Kernel threads operational
- [ ] Context switching operational
- [ ] Cooperative scheduler operational
- [ ] Preemptive scheduler operational, if feasible

> **October milestone:** Orion can respond to hardware events and run multiple kernel execution contexts.

---

## Three-Month Overall Target

By the end of October 2026, aim to have:

```text
                    ORION
                      │
          ┌───────────┴───────────┐
          │                       │
         CPU                    Memory
          │                       │
     GDT / TSS / IDT        Physical pages
     Exceptions                  │
     Interrupts               Paging
          │                       │
          └───────────┬───────────┘
                      │
                  Execution
                      │
              Kernel threads
                      │
              Context switching
                      │
                  Scheduler
```

> **Overall milestone:** Orion has moved from a bootstrapped kernel into a functioning x86-64 kernel core with its own CPU, memory, interrupt, and execution foundations.

## Deliberately Out of Scope for These Three Months

Do not make these prerequisites for the August–October goal:

- [ ] ACPI
- [ ] PCI/PCIe
- [ ] SMP
- [ ] NVMe
- [ ] USB
- [ ] Networking
- [ ] Filesystems
- [ ] User mode
- [ ] Full device-driver ecosystem

These should be tackled after the CPU, memory, and execution foundations are stable.
