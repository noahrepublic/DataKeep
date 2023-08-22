---
sidebar_position: 4
---

# DataKeep vs ProfileService

ProfileService by loleris is a great module. However, there are some minor opinionated flaws:

- Profile does not automatically clean up internal connections, making the developer have to perform inconvenient clean ups
- ProfileService async calls make it difficult to wait for Profiles to be loaded. Causing weird patterns when waiting for Profiles, DataKeep is promise based
- Shorter, cleaner, scripts for faster future development, and contributors (vs ProfileService fitting classes inside one script for micro-performance)
- Type checking. There is one caveat due to Luau limitations, can not type check what Promises return (but shows on documentation)