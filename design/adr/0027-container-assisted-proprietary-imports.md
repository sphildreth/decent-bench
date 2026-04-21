## Container-Assisted Proprietary Format Imports (MS SQL .bak)
**Date:** 2026-04-21
**Status:** Proposed

### Context

There is an ongoing user requirement to support importing MS SQL Server backup files (`.bak`). These files are proprietary Microsoft Tape Format archives encapsulating internal raw page structures (MDF/LDF) that have version-specific binary layouts. There are no robust FOSS libraries available in the Dart, Rust, or C++ ecosystems capable of directly parsing these structures correctly without the official engine. 

Attempting to build or maintain a custom parser for such complex and shifting proprietary binary structures represents an enormous engineering burden and is fundamentally unscalable.

### Decision

We will implement a **"Container-Assisted Import"** strategy to support proprietary database backups like MS SQL `.bak` files. 

When a user attempts to import a `.bak` file, Decent-Bench will:
1. Verify if the local environment has Docker (or a compatible container runtime) available.
2. Spin up a temporary, isolated Docker container running the official database engine (e.g., `mcr.microsoft.com/mssql/server:2022-latest`).
3. Mount the target `.bak` file into the container.
4. Execute engine-native commands (e.g., `RESTORE DATABASE`) to instantiate the data inside the container.
5. Connect to the containerized engine using standard FOSS drivers (e.g., FreeTDS / JDBC) to query the system catalogs, extract the schema, and stream the data over standard protocols into the target DecentDB instance.
6. Gracefully tear down the container and clean up temporary volumes once the import succeeds or fails.

### Rationale

*   **Accuracy & Reliability**: Relying on the official engine guarantees 100% accurate reads of the backup files, regardless of complex internal structures or SQL Server versioning nuances.
*   **Maintainability**: Offloads the burden of keeping up with proprietary binary changes to the vendor's official Docker images.
*   **Reusability**: This pattern can be extended to other historically difficult formats such as Oracle `.dmp` files or PostgreSQL custom dumps (`pg_dump -Fc`), expanding Decent-Bench's import capabilities significantly.
*   **Ecosystem Alignment**: Modern developer environments typically already have a container runtime installed, making this a reasonable prerequisite for advanced/proprietary imports.

### Alternatives Considered

*   **Custom Binary Parsing (e.g., reviving OrcaMDF logic)**: Rejected. High complexity, high risk of data corruption, and significant maintenance overhead trying to reverse-engineer undocumented structures.
*   **Requiring Users to Run Local SQL Server**: Rejected. Defeats the purpose of Decent-Bench being a seamless cross-platform desktop application; forces the user into complex manual setup.
*   **Cloud-based Conversion Service**: Rejected. Introduces privacy concerns, bandwidth costs, and breaks the "local-first" ethos of Decent-Bench.

### Trade-offs

*   **Prerequisites**: The user *must* have Docker Desktop or a local container daemon installed and running for this specific feature to work.
*   **Resource Overhead**: Spinning up a full SQL Server container requires significant memory (often 2GB+) and temporary disk space.
*   **UX Complexity**: We must clearly communicate to the user when Docker is required, handle missing Docker daemon scenarios gracefully with clear error messages, and ensure containers are reliably torn down even if the application crashes.

### References
*   [Decent-Bench PRD: Import Requirements](../PRD.md)