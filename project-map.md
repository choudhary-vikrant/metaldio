graph TB
    subgraph "metaldio Project"
        direction TB

        %% Main Components
        CORE["<b>CORE</b><br/>Low-level I/O<br/>C + Assembly"]
        SERVICES["<b>SERVICES</b><br/>Higher-level APIs<br/>BPAM, ISPF, Utils"]
        SAMPLE["<b>SAMPLE</b><br/>Example Programs<br/>f2m, m2f, mlsx"]
        ASMXMP["<b>ASMXMP</b><br/>Assembly Examples<br/>CCSID, DESERV"]

        %% Core Components
        subgraph CORE_DETAIL["Core Components"]
            CORE_IO["I/O Services<br/>dio, iosvcs"]
            CORE_MEM["Memory Mgmt<br/>mem"]
            CORE_S99["Dynamic Alloc<br/>s99"]
            CORE_DCB["DCB Structures<br/>ihadcb"]
        end

        %% Services Components
        subgraph SERVICES_DETAIL["Services Components"]
            BPAM["BPAM I/O<br/>Read/Write PDS"]
            MEMDIR["Member Directory<br/>List/Search"]
            ISPF["ISPF Stats<br/>Metadata"]
            UTIL["Utilities<br/>Helpers"]
        end

        %% Sample Programs
        subgraph SAMPLE_DETAIL["Sample Programs"]
            F2M["f2m<br/>File → Member"]
            M2F["m2f<br/>Member → File"]
            MLSX["mlsx<br/>List Members"]
            RWREC["readwriterec<br/>Basic I/O"]
        end

        %% Data & Testing
        DATA["<b>DATA</b><br/>Test Files"]
        TESTS["<b>TESTS</b><br/>Unit Tests<br/>core/test"]

        %% Build System
        BUILD["<b>BUILD</b><br/>Makefiles<br/>Scripts"]

        %% Relationships - Core to Services
        CORE --> SERVICES
        CORE_IO --> BPAM
        CORE_MEM --> BPAM
        CORE_S99 --> BPAM
        CORE_DCB --> BPAM

        %% Relationships - Services to Samples
        SERVICES --> SAMPLE
        BPAM --> F2M
        BPAM --> M2F
        BPAM --> MLSX
        BPAM --> RWREC
        MEMDIR --> MLSX
        ISPF --> MLSX

        %% Build relationships
        BUILD --> CORE
        BUILD --> SERVICES
        BUILD --> SAMPLE

        %% Test relationships
        DATA -.-> SAMPLE
        DATA -.-> TESTS
        TESTS -.-> CORE

        %% Assembly examples
        ASMXMP -.-> CORE

        %% Styling
        classDef coreStyle fill:#e1f5ff,stroke:#0066cc,stroke-width:2px
        classDef servicesStyle fill:#fff4e1,stroke:#ff9900,stroke-width:2px
        classDef sampleStyle fill:#e8f5e9,stroke:#4caf50,stroke-width:2px
        classDef supportStyle fill:#f3e5f5,stroke:#9c27b0,stroke-width:2px

        class CORE,CORE_DETAIL,CORE_IO,CORE_MEM,CORE_S99,CORE_DCB coreStyle
        class SERVICES,SERVICES_DETAIL,BPAM,MEMDIR,ISPF,UTIL servicesStyle
        class SAMPLE,SAMPLE_DETAIL,F2M,M2F,MLSX,RWREC sampleStyle
        class ASMXMP,DATA,TESTS,BUILD supportStyle
    end
```

## Legend

**🔵 CORE** - Low-level I/O functions (C + Assembly)
- Direct calls to z/OS macros (OPEN, CLOSE, READ, WRITE, STOW, DESERV)
- 31-bit and 64-bit support
- Builds: `libbpamiocore.a`

**🟠 SERVICES** - Higher-level APIs
- BPAM I/O operations
- Member directory services
- ISPF statistics handling
- Builds: `libbpamiosvcs.a`

**🟢 SAMPLE** - Example programs
- `f2m`: Copy files to PDS members
- `m2f`: Copy PDS members to files
- `mlsx`: List dataset members with attributes
- `readwriterec`: Basic read/write demo

**🟣 SUPPORT** - Supporting components
- Assembly examples (ASMXMP)
- Test data (DATA)
- Unit tests (TESTS)
- Build system (Makefiles)

## Key Relationships

- **Solid arrows** (→): Direct dependencies
- **Dotted arrows** (-.->): Test/example usage
- **Services** depend on **Core**
- **Samples** depend on **Services**
- **Build system** orchestrates all components